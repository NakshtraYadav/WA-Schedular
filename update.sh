#!/bin/bash
# ============================================================================
#  WA Scheduler - FAST Update Script v3.0
#  Uses git pull for speed, only restarts what changed
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/.version"
UPDATE_LOG="$SCRIPT_DIR/logs/system/update.log"
LOCK_FILE="$SCRIPT_DIR/.update.lock"

mkdir -p "$SCRIPT_DIR/logs/system"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$UPDATE_LOG"
    echo -e "$1"
}

# Check if git is available and repo is a git repo
is_git_repo() {
    [ -d "$SCRIPT_DIR/.git" ] && command -v git &> /dev/null
}

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$LOCK_PID" ] && ps -p "$LOCK_PID" > /dev/null 2>&1; then
            log "${RED}[!] Update already in progress${NC}"
            return 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

cleanup() {
    release_lock
}
trap cleanup EXIT

# Fast check using git
check_update_git() {
    cd "$SCRIPT_DIR"
    git fetch origin main --quiet 2>/dev/null
    
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        return 1  # No update
    else
        return 0  # Update available
    fi
}

# Get list of changed files
get_changed_files() {
    cd "$SCRIPT_DIR"
    git diff --name-only HEAD origin/main 2>/dev/null
}

# Fast update using git pull
fast_update() {
    log "${BLUE}=== Fast Update (git pull) ===${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Save current HEAD
    OLD_HEAD=$(git rev-parse HEAD 2>/dev/null)
    
    # Get changed files BEFORE pull
    CHANGED_FILES=$(get_changed_files)
    
    log "Changed files:"
    echo "$CHANGED_FILES" | head -10
    
    # Stash any local changes
    git stash --quiet 2>/dev/null
    
    # Pull latest
    log "${BLUE}Pulling latest changes...${NC}"
    if ! git pull origin main --quiet 2>/dev/null; then
        log "${RED}[!] Git pull failed${NC}"
        git stash pop --quiet 2>/dev/null
        return 1
    fi
    
    # Save new version
    git rev-parse HEAD > "$VERSION_FILE"
    
    log "${GREEN}[OK] Code updated${NC}"
    
    # Determine what needs restart
    RESTART_BACKEND=false
    RESTART_FRONTEND=false
    RUN_NPM_INSTALL=false
    RUN_PIP_INSTALL=false
    
    if echo "$CHANGED_FILES" | grep -q "backend/"; then
        RESTART_BACKEND=true
        log "  → Backend changed"
    fi
    
    if echo "$CHANGED_FILES" | grep -q "frontend/src/\|frontend/public/"; then
        RESTART_FRONTEND=true
        log "  → Frontend changed"
    fi
    
    if echo "$CHANGED_FILES" | grep -q "frontend/package.json"; then
        RUN_NPM_INSTALL=true
        log "  → package.json changed - need npm install"
    fi
    
    if echo "$CHANGED_FILES" | grep -q "backend/requirements.txt"; then
        RUN_PIP_INSTALL=true
        log "  → requirements.txt changed - need pip install"
    fi
    
    if echo "$CHANGED_FILES" | grep -q "whatsapp-service/"; then
        log "  → WhatsApp service changed - restart required"
    fi
    
    # Install dependencies only if needed
    if [ "$RUN_NPM_INSTALL" = true ]; then
        log "${BLUE}Installing npm dependencies...${NC}"
        cd "$SCRIPT_DIR/frontend"
        npm install --legacy-peer-deps --silent 2>/dev/null || yarn install --silent 2>/dev/null
    fi
    
    if [ "$RUN_PIP_INSTALL" = true ]; then
        log "${BLUE}Installing pip dependencies...${NC}"
        cd "$SCRIPT_DIR/backend"
        pip install -q -r requirements.txt 2>/dev/null
    fi
    
    # Smart restart
    cd "$SCRIPT_DIR"
    
    if [ "$RESTART_BACKEND" = true ] || [ "$RUN_PIP_INSTALL" = true ]; then
        log "${BLUE}Restarting backend...${NC}"
        if command -v supervisorctl &> /dev/null; then
            supervisorctl restart backend 2>/dev/null
        else
            # Find and kill backend process
            pkill -f "uvicorn.*server:app" 2>/dev/null || true
            pkill -f "python.*server.py" 2>/dev/null || true
            sleep 1
            cd "$SCRIPT_DIR/backend"
            if [ -d "venv" ]; then
                source venv/bin/activate
                python server.py &
                deactivate
            else
                python server.py &
            fi
        fi
        log "${GREEN}[OK] Backend restarted${NC}"
    fi
    
    if [ "$RESTART_FRONTEND" = true ] || [ "$RUN_NPM_INSTALL" = true ]; then
        log "${BLUE}Restarting frontend...${NC}"
        if command -v supervisorctl &> /dev/null; then
            supervisorctl restart frontend 2>/dev/null
        else
            # Kill and restart frontend
            pkill -f "react-scripts start" 2>/dev/null || true
            pkill -f "node.*start" 2>/dev/null || true
            sleep 1
            cd "$SCRIPT_DIR/frontend"
            npm start &
        fi
        log "${YELLOW}Frontend restarting (may take 30-60s to compile)${NC}"
    fi
    
    # If nothing specific changed, assume full restart needed
    if [ "$RESTART_BACKEND" = false ] && [ "$RESTART_FRONTEND" = false ]; then
        log "${BLUE}No specific changes detected, doing full restart...${NC}"
        ./stop.sh 2>/dev/null
        sleep 2
        ./start.sh &
    fi
    
    log "${GREEN}=== Update Complete ===${NC}"
    return 0
}

# Fallback: download zip (slower)
full_update() {
    log "${YELLOW}=== Full Update (ZIP download) ===${NC}"
    log "This is slower. Consider using git clone for faster updates."
    
    # Use existing update logic
    ./update.sh force
}

check_update() {
    if is_git_repo; then
        log "${BLUE}Checking for updates (git)...${NC}"
        if check_update_git; then
            CHANGED=$(get_changed_files | wc -l)
            log "${GREEN}Update available! ($CHANGED files changed)${NC}"
            return 0
        else
            log "${GREEN}Already up to date${NC}"
            return 1
        fi
    else
        log "${BLUE}Checking for updates (API)...${NC}"
        # Fallback to version.json comparison
        LOCAL_VER=$(grep '"version"' "$SCRIPT_DIR/version.json" 2>/dev/null | head -1 | cut -d'"' -f4)
        REMOTE_VER=$(curl -s "https://raw.githubusercontent.com/NakshtraYadav/WA-Schedular/main/version.json" | grep '"version"' | head -1 | cut -d'"' -f4)
        
        if [ "$LOCAL_VER" != "$REMOTE_VER" ]; then
            log "${GREEN}Update available: $LOCAL_VER -> $REMOTE_VER${NC}"
            return 0
        else
            log "${GREEN}Already up to date ($LOCAL_VER)${NC}"
            return 1
        fi
    fi
}

# ============================================================================
#  Main
# ============================================================================

case "${1:-check}" in
    check)
        echo ""
        check_update
        echo ""
        ;;
        
    fast|pull)
        echo ""
        acquire_lock || exit 1
        
        if ! is_git_repo; then
            log "${RED}[!] Not a git repository. Run: git clone https://github.com/NakshtraYadav/WA-Schedular.git${NC}"
            log "Falling back to full update..."
            full_update
            exit $?
        fi
        
        fast_update
        echo ""
        ;;
        
    install|update)
        echo ""
        acquire_lock || exit 1
        
        if is_git_repo; then
            fast_update
        else
            full_update
        fi
        echo ""
        ;;
        
    force)
        echo ""
        acquire_lock || exit 1
        
        if is_git_repo; then
            fast_update
        else
            full_update
        fi
        echo ""
        ;;
        
    *)
        echo ""
        echo "Usage: ./update.sh [command]"
        echo ""
        echo "Commands:"
        echo "  check   - Check for updates"
        echo "  fast    - Fast update using git pull (recommended)"
        echo "  install - Smart update (git if available, zip fallback)"
        echo "  force   - Force update"
        echo ""
        echo "Tips for faster updates:"
        echo "  1. Use 'git clone' to set up the repo"
        echo "  2. Use './update.sh fast' for incremental updates"
        echo "  3. Only changed services will restart"
        echo ""
        ;;
esac
