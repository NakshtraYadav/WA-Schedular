#!/bin/bash
# ============================================================================
#  WA Scheduler - FAST Update Script v4.0
#  Zero-downtime updates with hot reload support
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
}

release_lock() { rm -f "$LOCK_FILE"; }
cleanup() { release_lock; }
trap cleanup EXIT

# ============================================================================
#  SPEED OPTIMIZATION 1: Check if hot reload is running
# ============================================================================
is_dev_mode() {
    # Check if uvicorn is running with --reload
    pgrep -f "uvicorn.*--reload" > /dev/null 2>&1
}

is_frontend_dev() {
    # Check if react dev server is running (has hot reload built-in)
    pgrep -f "react-scripts start" > /dev/null 2>&1
}

# ============================================================================
#  SPEED OPTIMIZATION 2: Git pull only changed files
# ============================================================================
fast_git_update() {
    cd "$SCRIPT_DIR"
    
    log "${BLUE}[1/4] Fetching changes...${NC}"
    git fetch origin main --quiet 2>/dev/null
    
    # Get changed files
    CHANGED=$(git diff --name-only HEAD origin/main 2>/dev/null)
    CHANGE_COUNT=$(echo "$CHANGED" | grep -c . || echo 0)
    
    if [ "$CHANGE_COUNT" -eq 0 ]; then
        log "${GREEN}Already up to date!${NC}"
        return 0
    fi
    
    log "  $CHANGE_COUNT file(s) changed"
    
    log "${BLUE}[2/4] Pulling changes...${NC}"
    git stash --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null
    git rev-parse HEAD > "$VERSION_FILE"
    
    # Analyze what changed
    BACKEND_CHANGED=$(echo "$CHANGED" | grep -c "^backend/" || echo 0)
    FRONTEND_CHANGED=$(echo "$CHANGED" | grep -c "^frontend/src/" || echo 0)
    PKG_CHANGED=$(echo "$CHANGED" | grep -c "package.json" || echo 0)
    REQ_CHANGED=$(echo "$CHANGED" | grep -c "requirements.txt" || echo 0)
    
    log "${BLUE}[3/4] Installing dependencies (if needed)...${NC}"
    
    if [ "$PKG_CHANGED" -gt 0 ]; then
        log "  npm install..."
        cd "$SCRIPT_DIR/frontend" && npm install --legacy-peer-deps --silent 2>/dev/null &
        NPM_PID=$!
    fi
    
    if [ "$REQ_CHANGED" -gt 0 ]; then
        log "  pip install..."
        cd "$SCRIPT_DIR/backend"
        if [ -d "venv" ]; then
            source venv/bin/activate
            pip install -q -r requirements.txt 2>/dev/null &
            PIP_PID=$!
            deactivate
        fi
    fi
    
    # Wait for installs
    [ -n "$NPM_PID" ] && wait $NPM_PID
    [ -n "$PIP_PID" ] && wait $PIP_PID
    
    log "${BLUE}[4/4] Restarting services...${NC}"
    
    # SPEED OPTIMIZATION 3: Hot reload detection
    if is_dev_mode && [ "$BACKEND_CHANGED" -gt 0 ]; then
        log "  ${GREEN}Backend: Hot reload will pick up changes automatically!${NC}"
    elif [ "$BACKEND_CHANGED" -gt 0 ]; then
        log "  Restarting backend..."
        restart_backend_fast
    fi
    
    if is_frontend_dev && [ "$FRONTEND_CHANGED" -gt 0 ]; then
        log "  ${GREEN}Frontend: Hot reload will pick up changes automatically!${NC}"
    elif [ "$FRONTEND_CHANGED" -gt 0 ]; then
        log "  Restarting frontend..."
        restart_frontend_fast
    fi
    
    log "${GREEN}✓ Update complete!${NC}"
}

# ============================================================================
#  SPEED OPTIMIZATION 4: Graceful restart (don't kill, signal reload)
# ============================================================================
restart_backend_fast() {
    # Try graceful reload first (SIGHUP)
    BACKEND_PID=$(cat "$SCRIPT_DIR/.backend.pid" 2>/dev/null)
    
    if [ -n "$BACKEND_PID" ] && ps -p "$BACKEND_PID" > /dev/null 2>&1; then
        # Try to send reload signal
        kill -HUP "$BACKEND_PID" 2>/dev/null
        sleep 1
        if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
            log "  ${GREEN}Backend reloaded gracefully${NC}"
            return 0
        fi
    fi
    
    # Fallback: fast restart
    pkill -f "uvicorn.*server:app" 2>/dev/null
    sleep 1
    
    cd "$SCRIPT_DIR/backend"
    if [ -d "venv" ]; then
        source venv/bin/activate
        nohup python3 -m uvicorn server:app --host 0.0.0.0 --port 8001 > /dev/null 2>&1 &
        echo $! > "$SCRIPT_DIR/.backend.pid"
        deactivate
    else
        nohup python3 -m uvicorn server:app --host 0.0.0.0 --port 8001 > /dev/null 2>&1 &
        echo $! > "$SCRIPT_DIR/.backend.pid"
    fi
    log "  ${GREEN}Backend restarted${NC}"
}

restart_frontend_fast() {
    # For dev server, just let hot reload handle it
    if is_frontend_dev; then
        log "  ${GREEN}Frontend dev server will hot reload${NC}"
        return 0
    fi
    
    # Production: rebuild needed
    pkill -f "serve -s build" 2>/dev/null
    cd "$SCRIPT_DIR/frontend"
    npm run build --silent 2>/dev/null
    nohup npx serve -s build -l 3000 > /dev/null 2>&1 &
    log "  ${GREEN}Frontend rebuilt and restarted${NC}"
}

# ============================================================================
#  SPEED OPTIMIZATION 5: Background pre-fetch
# ============================================================================
prefetch_update() {
    log "${BLUE}Pre-fetching update in background...${NC}"
    cd "$SCRIPT_DIR"
    git fetch origin main --quiet 2>/dev/null &
    log "${GREEN}Pre-fetch started. Run './update.sh apply' when ready.${NC}"
}

apply_prefetched() {
    log "${BLUE}Applying pre-fetched update...${NC}"
    cd "$SCRIPT_DIR"
    
    git stash --quiet 2>/dev/null
    git merge origin/main --quiet 2>/dev/null
    git rev-parse HEAD > "$VERSION_FILE"
    
    # Quick restart
    restart_backend_fast
    
    log "${GREEN}✓ Applied!${NC}"
}

# ============================================================================
#  Main
# ============================================================================
case "${1:-check}" in
    check)
        echo ""
        if is_git_repo; then
            cd "$SCRIPT_DIR"
            git fetch origin main --quiet 2>/dev/null
            LOCAL=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
            REMOTE=$(git rev-parse origin/main 2>/dev/null | cut -c1-7)
            CHANGES=$(git diff --name-only HEAD origin/main 2>/dev/null | wc -l)
            
            if [ "$LOCAL" = "$REMOTE" ]; then
                echo -e "${GREEN}✓ Up to date ($LOCAL)${NC}"
            else
                echo -e "${YELLOW}Update available: $LOCAL → $REMOTE ($CHANGES files)${NC}"
                echo -e "Run: ${CYAN}./update.sh fast${NC}"
            fi
        else
            echo "Not a git repo - use API to check"
        fi
        echo ""
        ;;
        
    fast|pull|install|update|force)
        echo ""
        acquire_lock || exit 1
        
        START_TIME=$(date +%s)
        
        if is_git_repo; then
            fast_git_update
        else
            log "${YELLOW}Not a git repo. Converting...${NC}"
            git init
            git remote add origin https://github.com/NakshtraYadav/WA-Schedular.git
            git fetch origin main
            git reset --hard origin/main
            fast_git_update
        fi
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        log "⏱️  Total time: ${DURATION}s"
        echo ""
        ;;
        
    prefetch)
        prefetch_update
        ;;
        
    apply)
        acquire_lock || exit 1
        apply_prefetched
        ;;
        
    dev)
        echo ""
        echo -e "${BLUE}Starting in DEVELOPMENT mode (hot reload enabled)...${NC}"
        echo ""
        
        # Kill existing
        pkill -f "uvicorn.*server:app" 2>/dev/null
        pkill -f "react-scripts start" 2>/dev/null
        sleep 2
        
        # Start backend with hot reload
        cd "$SCRIPT_DIR/backend"
        if [ -d "venv" ]; then
            source venv/bin/activate
            nohup python3 -m uvicorn server:app --host 0.0.0.0 --port 8001 --reload > "$SCRIPT_DIR/logs/backend-dev.log" 2>&1 &
            deactivate
        else
            nohup python3 -m uvicorn server:app --host 0.0.0.0 --port 8001 --reload > "$SCRIPT_DIR/logs/backend-dev.log" 2>&1 &
        fi
        echo -e "${GREEN}✓ Backend started with hot reload${NC}"
        
        # Start frontend (already has hot reload)
        cd "$SCRIPT_DIR/frontend"
        nohup npm start > "$SCRIPT_DIR/logs/frontend-dev.log" 2>&1 &
        echo -e "${GREEN}✓ Frontend started with hot reload${NC}"
        
        echo ""
        echo -e "${GREEN}Development mode active!${NC}"
        echo "  - Backend changes: Auto-reload in ~1-2s"
        echo "  - Frontend changes: Auto-reload in ~2-5s"
        echo "  - No manual restart needed for code changes"
        echo ""
        ;;
        
    *)
        echo ""
        echo "Usage: ./update.sh [command]"
        echo ""
        echo "Update Commands:"
        echo "  check    - Check for updates"
        echo "  fast     - Fast update with git pull (~10-30s)"
        echo "  prefetch - Download update in background"
        echo "  apply    - Apply pre-fetched update (~5s)"
        echo ""
        echo "Development:"
        echo "  dev      - Start with HOT RELOAD (instant updates)"
        echo ""
        echo -e "${CYAN}Speed Tips:${NC}"
        echo "  1. Use './update.sh dev' for development (instant reload)"
        echo "  2. Use './update.sh prefetch' then 'apply' for zero-downtime"
        echo "  3. Git repo = fast updates, ZIP = slow updates"
        echo ""
        ;;
esac
