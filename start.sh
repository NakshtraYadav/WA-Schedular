#!/bin/bash
# ============================================================================
#  WA Scheduler - Simple Start & Update
#  Just run: ./start.sh
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/logs"

# ============================================================================
#  START - Runs everything with hot reload
# ============================================================================
start_all() {
    echo ""
    echo -e "${BOLD}Starting WA Scheduler...${NC}"
    echo ""

    # Stop any existing processes
    pkill -f "uvicorn.*server:app" 2>/dev/null
    pkill -f "node.*react-scripts" 2>/dev/null
    pkill -f "node.*whatsapp-service" 2>/dev/null
    sleep 2

    # Start WhatsApp Service
    echo -e "  ${CYAN}→${NC} WhatsApp Service (port 3001)"
    cd "$SCRIPT_DIR/whatsapp-service"
    nohup node index.js > "$SCRIPT_DIR/logs/whatsapp.log" 2>&1 &

    # Start Backend with hot reload
    echo -e "  ${CYAN}→${NC} Backend (port 8001) - hot reload ON"
    cd "$SCRIPT_DIR/backend"
    nohup python3 -m uvicorn server:app --host 0.0.0.0 --port 8001 --reload \
        --reload-dir "$SCRIPT_DIR/backend" > "$SCRIPT_DIR/logs/backend.log" 2>&1 &

    # Start Frontend with hot reload
    echo -e "  ${CYAN}→${NC} Frontend (port 3000) - hot reload ON"
    cd "$SCRIPT_DIR/frontend"
    BROWSER=none nohup npm start > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &

    sleep 3
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Running!${NC}"
    echo ""
    echo "  Frontend:  http://localhost:3000"
    echo "  Backend:   http://localhost:8001"
    echo "  WhatsApp:  http://localhost:3001"
    echo ""
    echo -e "  ${CYAN}Code changes apply automatically (1-3 sec)${NC}"
    echo -e "  ${CYAN}To update from GitHub: ./start.sh update${NC}"
    echo ""
}

# ============================================================================
#  UPDATE - Fast pull from GitHub (works while running)
# ============================================================================
update() {
    echo ""
    echo -e "${BOLD}Updating...${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Pull latest
    git fetch origin main --quiet 2>/dev/null
    git stash --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null
    
    # Check if dependencies changed
    if git diff HEAD~1 --name-only 2>/dev/null | grep -q "package.json"; then
        echo -e "  ${CYAN}→${NC} Installing npm packages..."
        cd "$SCRIPT_DIR/frontend" && npm install --legacy-peer-deps --silent 2>/dev/null
    fi
    
    if git diff HEAD~1 --name-only 2>/dev/null | grep -q "requirements.txt"; then
        echo -e "  ${CYAN}→${NC} Installing pip packages..."
        cd "$SCRIPT_DIR/backend" && pip install -q -r requirements.txt 2>/dev/null
    fi
    
    # Trigger hot reload (just touch the file)
    touch "$SCRIPT_DIR/backend/server.py" 2>/dev/null
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Updated!${NC} Changes will apply in 1-3 seconds."
    echo ""
}

# ============================================================================
#  STOP - Kill everything
# ============================================================================
stop_all() {
    echo ""
    echo -e "${BOLD}Stopping...${NC}"
    pkill -f "uvicorn.*server:app" 2>/dev/null
    pkill -f "node.*react-scripts" 2>/dev/null
    pkill -f "node.*whatsapp-service" 2>/dev/null
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
    
    if pgrep -f "uvicorn.*server:app" > /dev/null; then
        echo -e "  Backend:   ${GREEN}● Running${NC}"
    else
        echo -e "  Backend:   ${YELLOW}○ Stopped${NC}"
    fi
    
    if pgrep -f "react-scripts start" > /dev/null; then
        echo -e "  Frontend:  ${GREEN}● Running${NC}"
    else
        echo -e "  Frontend:  ${YELLOW}○ Stopped${NC}"
    fi
    
    if pgrep -f "node.*whatsapp" > /dev/null; then
        echo -e "  WhatsApp:  ${GREEN}● Running${NC}"
    else
        echo -e "  WhatsApp:  ${YELLOW}○ Stopped${NC}"
    fi
    echo ""
}

# ============================================================================
#  MAIN
# ============================================================================
case "${1:-start}" in
    start|"")
        start_all
        ;;
    update|pull)
        update
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_all
        ;;
    status)
        status
        ;;
    *)
        echo ""
        echo "Usage: ./start.sh [command]"
        echo ""
        echo "  start    Start everything (default)"
        echo "  update   Pull latest from GitHub"
        echo "  stop     Stop everything"
        echo "  restart  Stop and start"
        echo "  status   Check what's running"
        echo ""
        ;;
esac
