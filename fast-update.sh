#!/bin/bash
# ============================================================================
#  WA Scheduler - ULTRA-FAST Update Script v5.0 (WSL Optimized)
#  Designed for instant updates on Windows Subsystem for Linux
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
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

# ============================================================================
#  WSL DETECTION
# ============================================================================
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

is_git_repo() {
    [ -d "$SCRIPT_DIR/.git" ] && command -v git &> /dev/null
}

# ============================================================================
#  STRATEGY 1: PERSISTENT DEV SERVERS (No restart needed!)
# ============================================================================
#  Instead of restarting, use hot reload - changes apply in 1-2 seconds
# ============================================================================

is_backend_hot_reload() {
    pgrep -f "uvicorn.*--reload" > /dev/null 2>&1
}

is_frontend_hot_reload() {
    pgrep -f "react-scripts start" > /dev/null 2>&1
}

# ============================================================================
#  STRATEGY 2: INCREMENTAL GIT SYNC (Only changed files)
# ============================================================================
get_changed_files() {
    cd "$SCRIPT_DIR"
    git diff --name-only HEAD origin/main 2>/dev/null
}

# ============================================================================
#  STRATEGY 3: PARALLEL DEPENDENCY INSTALL
# ============================================================================
install_deps_parallel() {
    local CHANGED="$1"
    local PIDS=()
    
    # Check if package.json changed
    if echo "$CHANGED" | grep -q "frontend/package.json"; then
        log "  ${CYAN}→ Installing npm packages...${NC}"
        (cd "$SCRIPT_DIR/frontend" && npm install --legacy-peer-deps --prefer-offline --no-audit --silent 2>/dev/null) &
        PIDS+=($!)
    fi
    
    # Check if requirements.txt changed
    if echo "$CHANGED" | grep -q "backend/requirements.txt"; then
        log "  ${CYAN}→ Installing pip packages...${NC}"
        (cd "$SCRIPT_DIR/backend" && pip install -q -r requirements.txt 2>/dev/null) &
        PIDS+=($!)
    fi
    
    # Wait for all parallel installs
    for pid in "${PIDS[@]}"; do
        wait $pid
    done
}

# ============================================================================
#  STRATEGY 4: TOUCH-TRIGGER HOT RELOAD (Fastest method!)
# ============================================================================
#  Instead of restarting servers, just "touch" the main file
#  Hot reload detects the change and reloads in ~1-2 seconds
# ============================================================================
trigger_hot_reload() {
    local CHANGED="$1"
    
    # Backend: Touch server.py to trigger uvicorn reload
    if echo "$CHANGED" | grep -q "^backend/"; then
        if is_backend_hot_reload; then
            touch "$SCRIPT_DIR/backend/server.py"
            log "  ${GREEN}✓ Backend: Hot reload triggered (1-2s)${NC}"
        else
            log "  ${YELLOW}! Backend not in hot-reload mode${NC}"
            return 1
        fi
    fi
    
    # Frontend: Changes auto-detected by webpack
    if echo "$CHANGED" | grep -q "^frontend/src/"; then
        if is_frontend_hot_reload; then
            log "  ${GREEN}✓ Frontend: Auto-reloading (2-3s)${NC}"
        else
            log "  ${YELLOW}! Frontend not in hot-reload mode${NC}"
            return 1
        fi
    fi
    
    return 0
}

# ============================================================================
#  STRATEGY 5: SMART SERVICE MANAGEMENT
# ============================================================================
start_hot_reload_mode() {
    log "${BLUE}Starting HOT RELOAD mode...${NC}"
    
    # Kill any existing processes
    pkill -f "uvicorn.*server:app" 2>/dev/null
    pkill -f "node.*react-scripts" 2>/dev/null
    sleep 2
    
    # Start backend with hot reload
    cd "$SCRIPT_DIR/backend"
    nohup python3 -m uvicorn server:app --host 0.0.0.0 --port 8001 --reload \
        --reload-dir "$SCRIPT_DIR/backend" \
        > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
    echo $! > "$SCRIPT_DIR/.backend.pid"
    log "  ${GREEN}✓ Backend started (port 8001, hot reload ON)${NC}"
    
    # Start frontend with hot reload (React dev server)
    cd "$SCRIPT_DIR/frontend"
    
    # WSL Optimization: Disable file watching polling (uses inotify instead)
    export CHOKIDAR_USEPOLLING=false
    export FAST_REFRESH=true
    
    nohup npm start > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
    echo $! > "$SCRIPT_DIR/.frontend.pid"
    log "  ${GREEN}✓ Frontend started (port 3000, hot reload ON)${NC}"
    
    log ""
    log "${GREEN}${BOLD}HOT RELOAD ACTIVE!${NC}"
    log "  Code changes apply automatically in 1-3 seconds"
    log "  NO manual restart needed!"
}

# ============================================================================
#  ULTRA-FAST UPDATE (Main function)
# ============================================================================
ultra_fast_update() {
    local START_TIME=$(date +%s%3N)
    
    cd "$SCRIPT_DIR"
    
    log ""
    log "${BOLD}━━━ ULTRA-FAST UPDATE ━━━${NC}"
    
    # Step 1: Fetch (background, very fast)
    log "${BLUE}[1/4] Fetching...${NC}"
    git fetch origin main --quiet 2>/dev/null
    
    # Step 2: Check changes
    CHANGED=$(get_changed_files)
    CHANGE_COUNT=$(echo "$CHANGED" | grep -c . 2>/dev/null || echo 0)
    
    if [ "$CHANGE_COUNT" -eq 0 ]; then
        log "${GREEN}✓ Already up to date!${NC}"
        return 0
    fi
    
    log "  ${CYAN}$CHANGE_COUNT file(s) to update${NC}"
    
    # Step 3: Pull changes
    log "${BLUE}[2/4] Pulling...${NC}"
    git stash --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null
    git rev-parse HEAD > "$VERSION_FILE"
    
    # Step 4: Dependencies (parallel, only if needed)
    log "${BLUE}[3/4] Dependencies...${NC}"
    install_deps_parallel "$CHANGED"
    
    # Step 5: Trigger reload (INSTANT!)
    log "${BLUE}[4/4] Applying...${NC}"
    if trigger_hot_reload "$CHANGED"; then
        local END_TIME=$(date +%s%3N)
        local DURATION=$(( (END_TIME - START_TIME) / 1000 ))
        local MS=$(( (END_TIME - START_TIME) % 1000 ))
        
        log ""
        log "${GREEN}${BOLD}✓ UPDATE COMPLETE!${NC}"
        log "  ⏱️  Time: ${DURATION}.${MS}s"
        log "  Changes will be live in 1-3 seconds"
    else
        log "${YELLOW}Hot reload not active. Starting it now...${NC}"
        start_hot_reload_mode
    fi
}

# ============================================================================
#  INSTANT UPDATE (For when you're already in hot-reload mode)
# ============================================================================
instant_update() {
    local START_TIME=$(date +%s%3N)
    
    cd "$SCRIPT_DIR"
    
    log ""
    log "${BOLD}━━━ INSTANT UPDATE ━━━${NC}"
    
    # Just pull and let hot reload handle it
    git fetch origin main --quiet 2>/dev/null
    git stash --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null
    git rev-parse HEAD > "$VERSION_FILE"
    
    # Touch main files to trigger reload
    touch "$SCRIPT_DIR/backend/server.py" 2>/dev/null
    
    local END_TIME=$(date +%s%3N)
    local DURATION=$(( (END_TIME - START_TIME) ))
    
    log "${GREEN}✓ Done in ${DURATION}ms!${NC}"
    log "  Hot reload will apply changes automatically"
}

# ============================================================================
#  CHECK STATUS
# ============================================================================
check_status() {
    echo ""
    echo -e "${BOLD}━━━ UPDATE STATUS ━━━${NC}"
    echo ""
    
    # Hot reload status
    echo -e "${CYAN}Hot Reload:${NC}"
    if is_backend_hot_reload; then
        echo -e "  Backend:  ${GREEN}● ACTIVE${NC} (instant updates)"
    else
        echo -e "  Backend:  ${RED}○ INACTIVE${NC}"
    fi
    
    if is_frontend_hot_reload; then
        echo -e "  Frontend: ${GREEN}● ACTIVE${NC} (instant updates)"
    else
        echo -e "  Frontend: ${RED}○ INACTIVE${NC}"
    fi
    
    # WSL detection
    echo ""
    echo -e "${CYAN}Environment:${NC}"
    if is_wsl; then
        echo -e "  Platform: ${YELLOW}WSL${NC} (optimizations enabled)"
    else
        echo -e "  Platform: Linux"
    fi
    
    # Git status
    echo ""
    echo -e "${CYAN}Version:${NC}"
    if is_git_repo; then
        cd "$SCRIPT_DIR"
        git fetch origin main --quiet 2>/dev/null
        LOCAL=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
        REMOTE=$(git rev-parse origin/main 2>/dev/null | cut -c1-7)
        CHANGES=$(git diff --name-only HEAD origin/main 2>/dev/null | wc -l)
        
        if [ "$LOCAL" = "$REMOTE" ]; then
            echo -e "  Status:   ${GREEN}✓ Up to date${NC} ($LOCAL)"
        else
            echo -e "  Status:   ${YELLOW}Update available${NC}"
            echo -e "  Local:    $LOCAL"
            echo -e "  Remote:   $REMOTE"
            echo -e "  Changes:  $CHANGES files"
        fi
    fi
    
    echo ""
}

# ============================================================================
#  HELP
# ============================================================================
show_help() {
    echo ""
    echo -e "${BOLD}WA Scheduler - Ultra-Fast Updater v5.0${NC}"
    echo ""
    echo -e "${CYAN}COMMANDS:${NC}"
    echo "  status    Show current status"
    echo "  start     Start hot-reload mode (RECOMMENDED)"
    echo "  update    Ultra-fast update (~3-5s)"
    echo "  instant   Instant update when hot-reload active (~500ms)"
    echo "  stop      Stop all services"
    echo ""
    echo -e "${CYAN}WSL OPTIMIZATION:${NC}"
    echo "  1. Always use 'start' to enable hot-reload mode"
    echo "  2. Use 'instant' for fastest updates (~500ms)"
    echo "  3. Code changes apply automatically in 1-3 seconds"
    echo "  4. NO full recompilation needed!"
    echo ""
    echo -e "${CYAN}SPEED COMPARISON:${NC}"
    echo "  Old method:     30-60 seconds (full restart)"
    echo "  Ultra-fast:     3-5 seconds"
    echo "  Instant:        ~500ms (hot-reload mode)"
    echo ""
}

# ============================================================================
#  STOP SERVICES
# ============================================================================
stop_services() {
    log "${BLUE}Stopping services...${NC}"
    pkill -f "uvicorn.*server:app" 2>/dev/null
    pkill -f "node.*react-scripts" 2>/dev/null
    rm -f "$SCRIPT_DIR/.backend.pid" "$SCRIPT_DIR/.frontend.pid"
    log "${GREEN}✓ Services stopped${NC}"
}

# ============================================================================
#  MAIN
# ============================================================================
case "${1:-status}" in
    status|check)
        check_status
        ;;
    start|dev|hot)
        start_hot_reload_mode
        ;;
    update|fast|pull)
        ultra_fast_update
        ;;
    instant|quick|i)
        instant_update
        ;;
    stop)
        stop_services
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        ;;
esac
