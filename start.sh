#!/bin/bash
# ============================================================================
#  WA Scheduler - Start & Update (WSL Robust Version)
#  v2.1.2 - Fixed Python virtual environment support
# ============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/backend/venv"
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/.pids"

# ============================================================================
#  PYTHON VIRTUAL ENVIRONMENT SETUP
# ============================================================================
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "  ${CYAN}→${NC} Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
        
        if [ ! -f "$VENV_DIR/bin/python" ]; then
            echo -e "  ${RED}✗${NC} Failed to create virtual environment!"
            echo -e "    Try: ${YELLOW}sudo apt install python3-venv python3-full${NC}"
            return 1
        fi
    fi
    return 0
}

# Get the correct Python/pip commands (uses venv if exists)
get_python() {
    if [ -f "$VENV_DIR/bin/python" ]; then
        echo "$VENV_DIR/bin/python"
    else
        echo "python3"
    fi
}

get_pip() {
    if [ -f "$VENV_DIR/bin/pip" ]; then
        echo "$VENV_DIR/bin/pip"
    else
        echo "pip3"
    fi
}

PYTHON_CMD=$(get_python)
PIP_CMD=$(get_pip)

# ============================================================================
#  HELPER: Kill process safely (WSL compatible)
# ============================================================================
kill_process() {
    local name="$1"
    local pattern="$2"
    local port="$3"
    
    # Method 1: Kill by pattern
    pkill -9 -f "$pattern" 2>/dev/null
    
    # Method 2: Kill by port (multiple methods for WSL compatibility)
    if [ -n "$port" ]; then
        # Try lsof (if available)
        if command -v lsof &> /dev/null; then
            local pid=$(lsof -ti:$port 2>/dev/null)
            [ -n "$pid" ] && kill -9 $pid 2>/dev/null
        fi
        
        # Try fuser (if available)
        if command -v fuser &> /dev/null; then
            fuser -k $port/tcp 2>/dev/null
        fi
        
        # Try netstat + grep (fallback)
        local pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1)
        [ -n "$pid" ] && [ "$pid" != "-" ] && kill -9 $pid 2>/dev/null
    fi
    
    sleep 1
}

# ============================================================================
#  HELPER: Check if port is free
# ============================================================================
is_port_free() {
    local port="$1"
    
    # Try multiple methods
    if command -v lsof &> /dev/null; then
        ! lsof -ti:$port > /dev/null 2>&1
        return $?
    elif command -v netstat &> /dev/null; then
        ! netstat -tlnp 2>/dev/null | grep -q ":$port "
        return $?
    elif command -v ss &> /dev/null; then
        ! ss -tlnp 2>/dev/null | grep -q ":$port "
        return $?
    else
        # Fallback: try to connect
        ! (echo > /dev/tcp/localhost/$port) 2>/dev/null
        return $?
    fi
}

# ============================================================================
#  HELPER: Wait for port to be free
# ============================================================================
wait_for_port_free() {
    local port="$1"
    local max_wait="${2:-10}"
    
    for i in $(seq 1 $max_wait); do
        if is_port_free $port; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ============================================================================
#  HELPER: Wait for service to respond
# ============================================================================
wait_for_service() {
    local name="$1"
    local url="$2"
    local max_wait="${3:-30}"
    
    for i in $(seq 1 $max_wait); do
        if curl -s --max-time 2 "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ============================================================================
#  HELPER: Check prerequisites
# ============================================================================
check_prerequisites() {
    local errors=0
    
    echo -e "  ${CYAN}→${NC} Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "  ${RED}✗${NC} Python3 not found"
        errors=$((errors + 1))
    fi
    
    # Check Node
    if ! command -v node &> /dev/null; then
        echo -e "  ${RED}✗${NC} Node.js not found"
        errors=$((errors + 1))
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo -e "  ${RED}✗${NC} npm not found"
        errors=$((errors + 1))
    fi
    
    # Check MongoDB (optional but warn)
    if ! command -v mongod &> /dev/null; then
        if ! pgrep -x mongod > /dev/null 2>&1; then
            echo -e "  ${YELLOW}!${NC} MongoDB not detected (may be running externally)"
        fi
    fi
    
    # Check if backend dependencies exist
    if [ ! -d "$SCRIPT_DIR/backend" ]; then
        echo -e "  ${RED}✗${NC} Backend folder not found"
        errors=$((errors + 1))
    fi
    
    # Check if frontend dependencies exist
    if [ ! -d "$SCRIPT_DIR/frontend/node_modules" ]; then
        echo -e "  ${YELLOW}!${NC} Frontend node_modules not found - will install"
    fi
    
    return $errors
}

# ============================================================================
#  START BACKEND
# ============================================================================
start_backend() {
    echo -e "  ${CYAN}→${NC} Starting Backend (port 8001)..."
    
    # Kill existing
    kill_process "backend" "uvicorn.*server:app" 8001
    
    # Wait for port
    if ! wait_for_port_free 8001 5; then
        echo -e "  ${RED}✗${NC} Port 8001 still in use!"
        echo -e "    Run: ${YELLOW}sudo kill -9 \$(lsof -ti:8001)${NC}"
        return 1
    fi
    
    cd "$SCRIPT_DIR/backend"
    
    # Update Python commands (in case venv was just created)
    PYTHON_CMD=$(get_python)
    PIP_CMD=$(get_pip)
    
    # Check if venv exists, create if not
    if [ ! -f "$VENV_DIR/bin/python" ]; then
        echo -e "  ${YELLOW}!${NC} Virtual environment not found, creating..."
        if ! setup_venv; then
            echo -e "  ${RED}✗${NC} Failed to create virtual environment"
            return 1
        fi
        PYTHON_CMD=$(get_python)
        PIP_CMD=$(get_pip)
    fi
    
    # Check if uvicorn is installed
    if ! $PYTHON_CMD -c "import uvicorn" 2>/dev/null; then
        echo -e "  ${YELLOW}!${NC} Installing Python dependencies..."
        $PIP_CMD install -r requirements.txt
        
        if ! $PYTHON_CMD -c "import uvicorn" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} Failed to install dependencies!"
            echo -e "    Try: ${YELLOW}./start.sh setup${NC}"
            return 1
        fi
    fi
    
    # WSL environment variables
    export WATCHFILES_FORCE_POLLING=true
    
    # Start with detailed logging on error (using venv python)
    nohup $PYTHON_CMD -m uvicorn server:app \
        --host 0.0.0.0 \
        --port 8001 \
        --reload \
        --reload-dir "$SCRIPT_DIR/backend" \
        > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
    
    local pid=$!
    echo $pid > "$SCRIPT_DIR/.pids/backend.pid"
    
    # Wait and verify
    sleep 2
    
    # Check if process is still running
    if ! kill -0 $pid 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Backend crashed on startup!"
        echo -e "    Check log: ${YELLOW}cat $SCRIPT_DIR/logs/backend.log${NC}"
        echo ""
        echo "=== Last 20 lines of backend.log ==="
        tail -20 "$SCRIPT_DIR/logs/backend.log"
        return 1
    fi
    
    # Wait for HTTP response
    if wait_for_service "Backend" "http://localhost:8001/api/" 15; then
        echo -e "  ${GREEN}✓${NC} Backend running (PID: $pid)"
        return 0
    else
        echo -e "  ${RED}✗${NC} Backend not responding!"
        echo -e "    Check log: ${YELLOW}tail -50 $SCRIPT_DIR/logs/backend.log${NC}"
        return 1
    fi
}

# ============================================================================
#  START FRONTEND
# ============================================================================
start_frontend() {
    echo -e "  ${CYAN}→${NC} Starting Frontend (port 3000)..."
    
    # Kill existing
    kill_process "frontend" "react-scripts" 3000
    kill_process "frontend" "node.*3000" 3000
    
    # Wait for port
    if ! wait_for_port_free 3000 5; then
        echo -e "  ${RED}✗${NC} Port 3000 still in use!"
        echo -e "    Run: ${YELLOW}sudo kill -9 \$(lsof -ti:3000)${NC}"
        return 1
    fi
    
    cd "$SCRIPT_DIR/frontend"
    
    # Check node_modules
    if [ ! -d "node_modules" ]; then
        echo -e "  ${CYAN}→${NC} Installing npm packages (first run)..."
        npm install --legacy-peer-deps 2>/dev/null
    fi
    
    # WSL environment variables for React
    export BROWSER=none
    export CHOKIDAR_USEPOLLING=true
    export WATCHPACK_POLLING=true
    export FAST_REFRESH=true
    export CI=false
    export PORT=3000
    
    nohup npm start > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
    
    local pid=$!
    echo $pid > "$SCRIPT_DIR/.pids/frontend.pid"
    
    # Frontend takes longer to start
    if wait_for_service "Frontend" "http://localhost:3000" 60; then
        echo -e "  ${GREEN}✓${NC} Frontend running (PID: $pid)"
        return 0
    else
        echo -e "  ${RED}✗${NC} Frontend not responding!"
        echo -e "    Check log: ${YELLOW}tail -50 $SCRIPT_DIR/logs/frontend.log${NC}"
        return 1
    fi
}

# ============================================================================
#  START WHATSAPP SERVICE
# ============================================================================
start_whatsapp() {
    echo -e "  ${CYAN}→${NC} Starting WhatsApp Service (port 3001)..."
    
    kill_process "whatsapp" "node.*whatsapp" 3001
    
    if ! wait_for_port_free 3001 5; then
        echo -e "  ${YELLOW}!${NC} Port 3001 in use (may be already running)"
    fi
    
    cd "$SCRIPT_DIR/whatsapp-service"
    
    if [ ! -d "node_modules" ]; then
        echo -e "  ${CYAN}→${NC} Installing WhatsApp service packages..."
        npm install 2>/dev/null
    fi
    
    nohup node index.js > "$SCRIPT_DIR/logs/whatsapp.log" 2>&1 &
    echo $! > "$SCRIPT_DIR/.pids/whatsapp.pid"
    
    sleep 2
    
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} WhatsApp Service running"
    else
        echo -e "  ${YELLOW}!${NC} WhatsApp Service may still be starting..."
    fi
}

# ============================================================================
#  START ALL
# ============================================================================
start_all() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}              WA Scheduler - Starting Services                ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        echo ""
        echo -e "${RED}Please fix the errors above and try again.${NC}"
        return 1
    fi
    
    echo ""
    
    # Start services
    start_whatsapp
    echo ""
    
    if ! start_backend; then
        echo ""
        echo -e "${RED}Backend failed to start. See errors above.${NC}"
        return 1
    fi
    echo ""
    
    if ! start_frontend; then
        echo ""
        echo -e "${YELLOW}Frontend failed but backend is running.${NC}"
        echo -e "Try: ${CYAN}./start.sh restart-frontend${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Frontend:${NC}  http://localhost:3000"
    echo -e "  ${GREEN}Backend:${NC}   http://localhost:8001"
    echo -e "  ${GREEN}WhatsApp:${NC}  http://localhost:3001"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ============================================================================
#  SETUP - First time installation of all dependencies
# ============================================================================
setup() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}              WA Scheduler - First Time Setup                  ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Create virtual environment
    echo -e "  ${CYAN}→${NC} Setting up Python virtual environment..."
    if ! setup_venv; then
        return 1
    fi
    echo -e "  ${GREEN}✓${NC} Virtual environment ready"
    
    # Update Python/pip commands after venv creation
    PYTHON_CMD=$(get_python)
    PIP_CMD=$(get_pip)
    
    # Backend dependencies
    echo ""
    echo -e "  ${CYAN}→${NC} Installing Python dependencies..."
    cd "$SCRIPT_DIR/backend"
    $PIP_CMD install --upgrade pip 2>/dev/null
    $PIP_CMD install -r requirements.txt
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Python dependencies installed"
    else
        echo -e "  ${RED}✗${NC} Failed to install Python dependencies"
        return 1
    fi
    
    # Frontend dependencies
    echo ""
    echo -e "  ${CYAN}→${NC} Installing Node.js dependencies..."
    cd "$SCRIPT_DIR/frontend"
    npm install --legacy-peer-deps
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Node.js dependencies installed"
    else
        echo -e "  ${RED}✗${NC} Failed to install Node.js dependencies"
        return 1
    fi
    
    # WhatsApp service dependencies
    echo ""
    echo -e "  ${CYAN}→${NC} Installing WhatsApp service dependencies..."
    cd "$SCRIPT_DIR/whatsapp-service"
    npm install
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} WhatsApp service dependencies installed"
    else
        echo -e "  ${YELLOW}!${NC} WhatsApp service dependencies may have issues"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Setup complete!${NC}"
    echo ""
    echo -e "Now run: ${CYAN}./start.sh${NC}"
    echo ""
}

# ============================================================================
#  UPDATE
# ============================================================================
update() {
    echo ""
    echo -e "${BOLD}Updating from GitHub...${NC}"
    echo ""
    
    cd "$SCRIPT_DIR"
    
    # Check if git repo
    if [ ! -d ".git" ]; then
        echo -e "${RED}Not a git repository!${NC}"
        return 1
    fi
    
    OLD_COMMIT=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
    
    echo -e "  ${CYAN}→${NC} Pulling latest..."
    git stash --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null
    
    NEW_COMMIT=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
    
    if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
        echo -e "  ${GREEN}✓${NC} Already up to date ($OLD_COMMIT)"
        return 0
    fi
    
    echo -e "  ${GREEN}✓${NC} Updated: $OLD_COMMIT → $NEW_COMMIT"
    
    # Check what changed
    CHANGES=$(git diff $OLD_COMMIT $NEW_COMMIT --name-only 2>/dev/null)
    
    # Dependencies
    if echo "$CHANGES" | grep -q "package.json"; then
        echo -e "  ${CYAN}→${NC} Installing npm packages..."
        cd "$SCRIPT_DIR/frontend" && npm install --legacy-peer-deps --silent 2>/dev/null
        cd "$SCRIPT_DIR"
    fi
    
    if echo "$CHANGES" | grep -q "requirements.txt"; then
        echo -e "  ${CYAN}→${NC} Installing pip packages..."
        pip install -q -r "$SCRIPT_DIR/backend/requirements.txt" 2>/dev/null
    fi
    
    # Hot reload triggers
    if echo "$CHANGES" | grep -q "^backend/"; then
        touch "$SCRIPT_DIR/backend/server.py"
        echo -e "  ${GREEN}✓${NC} Backend reloading..."
    fi
    
    if echo "$CHANGES" | grep -q "^frontend/src/"; then
        touch "$SCRIPT_DIR/frontend/src/index.js"
        echo -e "  ${GREEN}✓${NC} Frontend reloading..."
    fi
    
    echo ""
    echo -e "${GREEN}Update complete!${NC}"
    echo ""
}

# ============================================================================
#  STOP
# ============================================================================
stop_all() {
    echo ""
    echo -e "${BOLD}Stopping all services...${NC}"
    
    kill_process "backend" "uvicorn.*server:app" 8001
    kill_process "frontend" "react-scripts" 3000
    kill_process "frontend" "node.*3000" 3000
    kill_process "whatsapp" "node.*whatsapp" 3001
    
    rm -f "$SCRIPT_DIR/.pids/"*.pid
    
    echo -e "${GREEN}✓ All services stopped${NC}"
    echo ""
}

# ============================================================================
#  STATUS
# ============================================================================
status() {
    echo ""
    echo -e "${BOLD}Service Status:${NC}"
    echo ""
    
    if curl -s --max-time 2 http://localhost:8001/api/ > /dev/null 2>&1; then
        local ver=$(curl -s http://localhost:8001/api/version 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))" 2>/dev/null)
        echo -e "  Backend:   ${GREEN}● Running${NC} (v$ver)"
    else
        echo -e "  Backend:   ${RED}○ Stopped${NC}"
    fi
    
    if curl -s --max-time 2 http://localhost:3000 > /dev/null 2>&1; then
        echo -e "  Frontend:  ${GREEN}● Running${NC}"
    else
        echo -e "  Frontend:  ${RED}○ Stopped${NC}"
    fi
    
    if curl -s --max-time 2 http://localhost:3001/health > /dev/null 2>&1; then
        echo -e "  WhatsApp:  ${GREEN}● Running${NC}"
    else
        echo -e "  WhatsApp:  ${RED}○ Stopped${NC}"
    fi
    
    echo ""
}

# ============================================================================
#  DIAGNOSE - Debug startup issues
# ============================================================================
diagnose() {
    echo ""
    echo -e "${BOLD}━━━ DIAGNOSTIC REPORT ━━━${NC}"
    echo ""
    
    echo -e "${CYAN}System:${NC}"
    echo "  OS: $(uname -a | cut -c1-60)"
    echo "  WSL: $(grep -qi microsoft /proc/version && echo 'Yes' || echo 'No')"
    echo ""
    
    echo -e "${CYAN}Dependencies:${NC}"
    echo "  Python: $(python3 --version 2>/dev/null || echo 'NOT FOUND')"
    echo "  Node:   $(node --version 2>/dev/null || echo 'NOT FOUND')"
    echo "  npm:    $(npm --version 2>/dev/null || echo 'NOT FOUND')"
    echo ""
    
    echo -e "${CYAN}Ports:${NC}"
    for port in 3000 3001 8001 27017; do
        if is_port_free $port; then
            echo "  $port: free"
        else
            echo "  $port: IN USE"
        fi
    done
    echo ""
    
    echo -e "${CYAN}Recent Backend Log:${NC}"
    if [ -f "$SCRIPT_DIR/logs/backend.log" ]; then
        tail -10 "$SCRIPT_DIR/logs/backend.log" | sed 's/^/  /'
    else
        echo "  (no log file)"
    fi
    echo ""
    
    echo -e "${CYAN}Recent Frontend Log:${NC}"
    if [ -f "$SCRIPT_DIR/logs/frontend.log" ]; then
        tail -10 "$SCRIPT_DIR/logs/frontend.log" | sed 's/^/  /'
    else
        echo "  (no log file)"
    fi
    echo ""
}

# ============================================================================
#  RESTART FRONTEND ONLY
# ============================================================================
restart_frontend() {
    echo ""
    echo -e "${BOLD}Restarting frontend...${NC}"
    
    kill_process "frontend" "react-scripts" 3000
    kill_process "frontend" "node.*3000" 3000
    
    wait_for_port_free 3000 5
    
    start_frontend
}

# ============================================================================
#  MAIN
# ============================================================================
case "${1:-start}" in
    start|"")
        start_all
        ;;
    setup|install)
        setup
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
    restart-backend|rb)
        echo "Restarting backend..."
        kill_process "backend" "uvicorn.*server:app" 8001
        sleep 2
        start_backend
        ;;
    update|pull|u)
        update
        ;;
    status|s)
        status
        ;;
    logs|log|l)
        service="${2:-all}"
        case "$service" in
            backend|b) tail -50 "$SCRIPT_DIR/logs/backend.log" ;;
            frontend|f) tail -50 "$SCRIPT_DIR/logs/frontend.log" ;;
            whatsapp|w) tail -50 "$SCRIPT_DIR/logs/whatsapp.log" ;;
            *) 
                echo "=== Backend ===" && tail -15 "$SCRIPT_DIR/logs/backend.log" 2>/dev/null
                echo "" && echo "=== Frontend ===" && tail -15 "$SCRIPT_DIR/logs/frontend.log" 2>/dev/null
                ;;
        esac
        ;;
    diagnose|diag|d)
        diagnose
        ;;
    *)
        echo ""
        echo -e "${BOLD}WA Scheduler v2.1.2${NC}"
        echo ""
        echo "Usage: ./start.sh [command]"
        echo ""
        echo -e "  ${CYAN}setup${NC}             Install all dependencies (first time)"
        echo "  start             Start all services"
        echo "  stop              Stop all services"
        echo "  restart           Full restart"
        echo "  restart-frontend  Restart frontend only"
        echo "  restart-backend   Restart backend only"
        echo "  update            Pull from GitHub"
        echo "  status            Check services"
        echo "  logs [service]    View logs"
        echo "  diagnose          Debug startup issues"
        echo ""
        ;;
esac
