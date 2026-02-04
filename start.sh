#!/bin/bash
# ============================================================================
#  WA Scheduler - Start & Update (WSL Fixed)
#  v2.1.0 - Fixed frontend restart issues
# ============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/logs"

# ============================================================================
#  HELPER: Kill process and wait for port to be free
# ============================================================================
kill_and_wait() {
    local name="$1"
    local pattern="$2"
    local port="$3"
    
    # Kill by pattern
    pkill -9 -f "$pattern" 2>/dev/null
    
    # Also kill any process on the port (WSL often leaves zombies)
    if [ -n "$port" ]; then
        local pid=$(lsof -ti:$port 2>/dev/null)
        if [ -n "$pid" ]; then
            kill -9 $pid 2>/dev/null
        fi
    fi
    
    # Wait for port to be free (max 5 seconds)
    if [ -n "$port" ]; then
        for i in {1..10}; do
            if ! lsof -ti:$port > /dev/null 2>&1; then
                return 0
            fi
            sleep 0.5
        done
        echo -e "  ${RED}Warning: Port $port still in use${NC}"
    fi
}

# ============================================================================
#  HELPER: Wait for service to be ready
# ============================================================================
wait_for_service() {
    local name="$1"
    local url="$2"
    local max_wait="${3:-30}"
    
    for i in $(seq 1 $max_wait); do
        if curl -s "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ============================================================================
#  START - Runs everything with hot reload
# ============================================================================
start_all() {
    echo ""
    echo -e "${BOLD}Starting WA Scheduler...${NC}"
    echo ""

    # Stop existing processes PROPERLY
    echo -e "  ${CYAN}→${NC} Stopping existing processes..."
    kill_and_wait "backend" "uvicorn.*server:app" 8001
    kill_and_wait "frontend" "react-scripts" 3000
    kill_and_wait "frontend" "node.*3000" 3000
    kill_and_wait "whatsapp" "node.*whatsapp" 3001
    sleep 1

    # Start WhatsApp Service
    echo -e "  ${CYAN}→${NC} Starting WhatsApp Service (port 3001)..."
    cd "$SCRIPT_DIR/whatsapp-service"
    nohup node index.js > "$SCRIPT_DIR/logs/whatsapp.log" 2>&1 &
    echo $! > "$SCRIPT_DIR/.pids/whatsapp.pid"

    # Start Backend with hot reload
    echo -e "  ${CYAN}→${NC} Starting Backend (port 8001)..."
    cd "$SCRIPT_DIR/backend"
    
    # WSL fix: Use polling for file watching
    export WATCHFILES_FORCE_POLLING=true
    
    nohup python3 -m uvicorn server:app \
        --host 0.0.0.0 \
        --port 8001 \
        --reload \
        --reload-dir "$SCRIPT_DIR/backend" \
        > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
    echo $! > "$SCRIPT_DIR/.pids/backend.pid"

    # Start Frontend with hot reload
    echo -e "  ${CYAN}→${NC} Starting Frontend (port 3000)..."
    cd "$SCRIPT_DIR/frontend"
    
    # WSL fixes for React
    export BROWSER=none
    export CHOKIDAR_USEPOLLING=true    # FIX: Force polling on WSL
    export WATCHPACK_POLLING=true       # FIX: Webpack polling
    export FAST_REFRESH=true
    export CI=false
    
    nohup npm start > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
    echo $! > "$SCRIPT_DIR/.pids/frontend.pid"

    # Wait for services to be ready
    echo ""
    echo -e "  ${CYAN}→${NC} Waiting for services..."
    
    if wait_for_service "Backend" "http://localhost:8001/api/" 15; then
        echo -e "  ${GREEN}✓${NC} Backend ready"
    else
        echo -e "  ${RED}✗${NC} Backend failed to start - check logs/backend.log"
    fi
    
    if wait_for_service "Frontend" "http://localhost:3000" 30; then
        echo -e "  ${GREEN}✓${NC} Frontend ready"
    else
        echo -e "  ${RED}✗${NC} Frontend failed to start - check logs/frontend.log"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Running!${NC}"
    echo ""
    echo "  Frontend:  http://localhost:3000"
    echo "  Backend:   http://localhost:8001"
    echo "  WhatsApp:  http://localhost:3001"
    echo ""
    echo -e "  ${CYAN}Logs: tail -f logs/frontend.log${NC}"
    echo ""
}

# ============================================================================
#  UPDATE - Pull from GitHub and apply changes
# ============================================================================
update() {
    echo ""
    echo -e "${BOLD}Updating from GitHub...${NC}"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    # Save current commit
    OLD_COMMIT=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
    
    # Pull latest
    echo -e "  ${CYAN}→${NC} Fetching..."
    git fetch origin main --quiet 2>/dev/null
    
    # Check if there are changes
    CHANGES=$(git diff HEAD origin/main --name-only 2>/dev/null | wc -l)
    
    if [ "$CHANGES" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Already up to date!"
        echo ""
        return 0
    fi
    
    echo -e "  ${CYAN}→${NC} $CHANGES file(s) changed"
    
    # Stash local changes and pull
    git stash --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null
    
    NEW_COMMIT=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
    echo -e "  ${CYAN}→${NC} Updated: $OLD_COMMIT → $NEW_COMMIT"
    
    # Check what changed
    BACKEND_CHANGED=$(git diff $OLD_COMMIT $NEW_COMMIT --name-only 2>/dev/null | grep -c "^backend/" || echo 0)
    FRONTEND_CHANGED=$(git diff $OLD_COMMIT $NEW_COMMIT --name-only 2>/dev/null | grep -c "^frontend/src/" || echo 0)
    PKG_CHANGED=$(git diff $OLD_COMMIT $NEW_COMMIT --name-only 2>/dev/null | grep -c "package.json" || echo 0)
    REQ_CHANGED=$(git diff $OLD_COMMIT $NEW_COMMIT --name-only 2>/dev/null | grep -c "requirements.txt" || echo 0)
    
    # Install dependencies if needed
    if [ "$PKG_CHANGED" -gt 0 ]; then
        echo -e "  ${CYAN}→${NC} Installing npm packages..."
        cd "$SCRIPT_DIR/frontend" && npm install --legacy-peer-deps --silent 2>/dev/null
        cd "$SCRIPT_DIR"
    fi
    
    if [ "$REQ_CHANGED" -gt 0 ]; then
        echo -e "  ${CYAN}→${NC} Installing pip packages..."
        cd "$SCRIPT_DIR/backend" && pip install -q -r requirements.txt 2>/dev/null
        cd "$SCRIPT_DIR"
    fi
    
    # Apply changes
    echo -e "  ${CYAN}→${NC} Applying changes..."
    
    # Backend: Touch to trigger uvicorn reload
    if [ "$BACKEND_CHANGED" -gt 0 ]; then
        touch "$SCRIPT_DIR/backend/server.py"
        echo -e "  ${GREEN}✓${NC} Backend: Hot reload triggered"
    fi
    
    # Frontend: FIX! Need to handle this properly
    if [ "$FRONTEND_CHANGED" -gt 0 ] || [ "$PKG_CHANGED" -gt 0 ]; then
        # Method 1: Touch a source file to trigger webpack rebuild
        touch "$SCRIPT_DIR/frontend/src/index.js"
        
        # Method 2: If that doesn't work, we need to restart frontend
        # Wait a moment to see if hot reload picks it up
        sleep 2
        
        # Check if frontend is still responding
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Frontend: Hot reload triggered"
        else
            # Frontend died, restart it
            echo -e "  ${YELLOW}!${NC} Frontend needs restart..."
            restart_frontend
        fi
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Update complete!${NC}"
    echo ""
}

# ============================================================================
#  RESTART FRONTEND ONLY (for when it gets stuck)
# ============================================================================
restart_frontend() {
    echo -e "  ${CYAN}→${NC} Restarting frontend..."
    
    # Kill existing
    kill_and_wait "frontend" "react-scripts" 3000
    kill_and_wait "frontend" "node.*3000" 3000
    sleep 1
    
    # Restart
    cd "$SCRIPT_DIR/frontend"
    export BROWSER=none
    export CHOKIDAR_USEPOLLING=true
    export WATCHPACK_POLLING=true
    export FAST_REFRESH=true
    export CI=false
    
    nohup npm start > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
    
    # Wait for it
    if wait_for_service "Frontend" "http://localhost:3000" 30; then
        echo -e "  ${GREEN}✓${NC} Frontend restarted"
    else
        echo -e "  ${RED}✗${NC} Frontend failed - check logs/frontend.log"
    fi
}

# ============================================================================
#  STOP - Kill everything
# ============================================================================
stop_all() {
    echo ""
    echo -e "${BOLD}Stopping...${NC}"
    kill_and_wait "backend" "uvicorn.*server:app" 8001
    kill_and_wait "frontend" "react-scripts" 3000
    kill_and_wait "frontend" "node.*3000" 3000
    kill_and_wait "whatsapp" "node.*whatsapp" 3001
    echo -e "${GREEN}✓ Stopped${NC}"
    echo ""
}

# ============================================================================
#  STATUS - Check what's running
# ============================================================================
status() {
    echo ""
    echo -e "${BOLD}Status:${NC}"
    echo ""
    
    # Backend
    if curl -s http://localhost:8001/api/ > /dev/null 2>&1; then
        echo -e "  Backend:   ${GREEN}● Running${NC} (http://localhost:8001)"
    else
        echo -e "  Backend:   ${RED}○ Stopped${NC}"
    fi
    
    # Frontend
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo -e "  Frontend:  ${GREEN}● Running${NC} (http://localhost:3000)"
    else
        echo -e "  Frontend:  ${RED}○ Stopped${NC}"
    fi
    
    # WhatsApp
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        echo -e "  WhatsApp:  ${GREEN}● Running${NC} (http://localhost:3001)"
    else
        echo -e "  WhatsApp:  ${RED}○ Stopped${NC}"
    fi
    
    echo ""
    
    # Show version
    VERSION=$(curl -s http://localhost:8001/api/version 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null || echo "unknown")
    echo -e "  Version:   ${CYAN}$VERSION${NC}"
    echo ""
}

# ============================================================================
#  LOGS - Show recent logs
# ============================================================================
show_logs() {
    local service="${1:-all}"
    
    case "$service" in
        backend|b)
            tail -50 "$SCRIPT_DIR/logs/backend.log"
            ;;
        frontend|f)
            tail -50 "$SCRIPT_DIR/logs/frontend.log"
            ;;
        whatsapp|w)
            tail -50 "$SCRIPT_DIR/logs/whatsapp.log"
            ;;
        *)
            echo -e "${BOLD}=== Backend ===${NC}"
            tail -10 "$SCRIPT_DIR/logs/backend.log" 2>/dev/null
            echo ""
            echo -e "${BOLD}=== Frontend ===${NC}"
            tail -10 "$SCRIPT_DIR/logs/frontend.log" 2>/dev/null
            echo ""
            ;;
    esac
}

# ============================================================================
#  MAIN
# ============================================================================

# Create pids directory
mkdir -p "$SCRIPT_DIR/.pids"

case "${1:-start}" in
    start|"")
        start_all
        ;;
    update|pull|u)
        update
        ;;
    stop)
        stop_all
        ;;
    restart|r)
        stop_all
        sleep 2
        start_all
        ;;
    restart-frontend|rf)
        restart_frontend
        ;;
    status|s)
        status
        ;;
    logs|log|l)
        show_logs "$2"
        ;;
    *)
        echo ""
        echo -e "${BOLD}WA Scheduler - Start & Update${NC}"
        echo ""
        echo "Usage: ./start.sh [command]"
        echo ""
        echo "  start            Start everything (default)"
        echo "  stop             Stop everything"
        echo "  restart          Full restart"
        echo "  restart-frontend Restart only frontend (if stuck)"
        echo "  update           Pull & apply from GitHub"
        echo "  status           Check what's running"
        echo "  logs [service]   Show logs (backend/frontend/whatsapp)"
        echo ""
        ;;
esac
