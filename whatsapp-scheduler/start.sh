#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Start All Services (Ubuntu/WSL)
#  Runs services in background with logging
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Ports
FRONTEND_PORT=3000
BACKEND_PORT=8001
WHATSAPP_PORT=3001

# Create log directories
mkdir -p "$LOG_DIR/backend"
mkdir -p "$LOG_DIR/frontend"
mkdir -p "$LOG_DIR/whatsapp"
mkdir -p "$LOG_DIR/system"

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}       WhatsApp Scheduler - Starting Services${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# ============================================================================
# STOP ANY EXISTING SERVICES
# ============================================================================
echo -e "${YELLOW}[1/5]${NC} Stopping any existing services..."

# Kill by port
for port in $FRONTEND_PORT $BACKEND_PORT $WHATSAPP_PORT; do
    pid=$(lsof -t -i:$port 2>/dev/null)
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null || true
        echo "  Killed process on port $port (PID: $pid)"
    fi
done

sleep 2
echo -e "${GREEN}[OK]${NC} Ports cleared"
echo ""

# ============================================================================
# START MONGODB (if installed locally)
# ============================================================================
echo -e "${YELLOW}[2/5]${NC} Checking MongoDB..."

if command -v mongod &> /dev/null; then
    if ! pgrep -x "mongod" > /dev/null; then
        echo "  Starting MongoDB..."
        sudo systemctl start mongod 2>/dev/null || \
        mongod --dbpath /var/lib/mongodb --fork --logpath "$LOG_DIR/system/mongodb.log" 2>/dev/null || \
        echo -e "${YELLOW}[!]${NC} Could not start MongoDB - may need manual start"
    fi
    echo -e "${GREEN}[OK]${NC} MongoDB running"
else
    echo -e "${YELLOW}[!]${NC} MongoDB not installed locally - using Atlas or external"
fi
echo ""

# ============================================================================
# START WHATSAPP SERVICE
# ============================================================================
echo -e "${YELLOW}[3/5]${NC} Starting WhatsApp service..."

WA_LOG="$LOG_DIR/whatsapp/service_$TIMESTAMP.log"
cd "$SCRIPT_DIR/whatsapp-service"

# Start in background
nohup node index.js > "$WA_LOG" 2>&1 &
WA_PID=$!
echo $WA_PID > "$SCRIPT_DIR/.wa.pid"

echo "  PID: $WA_PID"
echo "  Log: $WA_LOG"

# Wait for WhatsApp to be ready
echo -n "  Waiting for WhatsApp service"
for i in {1..30}; do
    if curl -s http://localhost:$WHATSAPP_PORT/health > /dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}[OK]${NC} WhatsApp service ready on port $WHATSAPP_PORT"
        break
    fi
    echo -n "."
    sleep 2
done

if ! curl -s http://localhost:$WHATSAPP_PORT/health > /dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}[!]${NC} WhatsApp service slow to start - check logs"
fi
echo ""

# ============================================================================
# START BACKEND
# ============================================================================
echo -e "${YELLOW}[4/5]${NC} Starting Backend API..."

BE_LOG="$LOG_DIR/backend/api_$TIMESTAMP.log"
cd "$SCRIPT_DIR/backend"

# Activate venv and start
source venv/bin/activate
nohup python3 -m uvicorn server:app --host 0.0.0.0 --port $BACKEND_PORT > "$BE_LOG" 2>&1 &
BE_PID=$!
echo $BE_PID > "$SCRIPT_DIR/.backend.pid"
deactivate

echo "  PID: $BE_PID"
echo "  Log: $BE_LOG"

# Wait for Backend
echo -n "  Waiting for Backend API"
for i in {1..20}; do
    if curl -s http://localhost:$BACKEND_PORT/api/ > /dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}[OK]${NC} Backend API ready on port $BACKEND_PORT"
        break
    fi
    echo -n "."
    sleep 2
done

if ! curl -s http://localhost:$BACKEND_PORT/api/ > /dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}[!]${NC} Backend slow to start - check logs"
fi
echo ""

# ============================================================================
# START FRONTEND
# ============================================================================
echo -e "${YELLOW}[5/5]${NC} Starting Frontend..."
echo "  First start may take 1-2 minutes to compile React..."

FE_LOG="$LOG_DIR/frontend/react_$TIMESTAMP.log"
cd "$SCRIPT_DIR/frontend"

# Start React dev server
BROWSER=none nohup npm start > "$FE_LOG" 2>&1 &
FE_PID=$!
echo $FE_PID > "$SCRIPT_DIR/.frontend.pid"

echo "  PID: $FE_PID"
echo "  Log: $FE_LOG"

# Wait for Frontend (longer timeout for compilation)
echo -n "  Compiling frontend"
for i in {1..60}; do
    if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}[OK]${NC} Frontend ready on port $FRONTEND_PORT"
        break
    fi
    echo -n "."
    sleep 3
done

if ! curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}[!]${NC} Frontend still compiling - check logs or wait"
fi
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}                    ALL SERVICES STARTED${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  Service                Port        Status"
echo "  ---------------------------------------------------------------------------"

# Check each service
if curl -s http://localhost:$WHATSAPP_PORT/health > /dev/null 2>&1; then
    echo -e "  WhatsApp Service       $WHATSAPP_PORT         ${GREEN}[RUNNING]${NC}"
else
    echo -e "  WhatsApp Service       $WHATSAPP_PORT         ${YELLOW}[STARTING]${NC}"
fi

if curl -s http://localhost:$BACKEND_PORT/api/ > /dev/null 2>&1; then
    echo -e "  Backend API            $BACKEND_PORT         ${GREEN}[RUNNING]${NC}"
else
    echo -e "  Backend API            $BACKEND_PORT         ${YELLOW}[STARTING]${NC}"
fi

if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
    echo -e "  Frontend Dashboard     $FRONTEND_PORT         ${GREEN}[RUNNING]${NC}"
else
    echo -e "  Frontend Dashboard     $FRONTEND_PORT         ${YELLOW}[COMPILING]${NC}"
fi

echo "  ---------------------------------------------------------------------------"
echo ""
echo "  URLs:"
echo -e "    Dashboard:    ${CYAN}http://localhost:$FRONTEND_PORT${NC}"
echo -e "    Diagnostics:  ${CYAN}http://localhost:$FRONTEND_PORT/diagnostics${NC}"
echo -e "    Connect WA:   ${CYAN}http://localhost:$FRONTEND_PORT/connect${NC}"
echo -e "    API Health:   ${CYAN}http://localhost:$BACKEND_PORT/api/health${NC}"
echo ""
echo "  Logs: $LOG_DIR/"
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  To stop all services: ./stop.sh"
echo ""

# Try to open browser (works in WSL with Windows browser)
if command -v xdg-open &> /dev/null; then
    xdg-open "http://localhost:$FRONTEND_PORT" 2>/dev/null &
elif command -v wslview &> /dev/null; then
    wslview "http://localhost:$FRONTEND_PORT" 2>/dev/null &
elif [ -f "/mnt/c/Windows/explorer.exe" ]; then
    /mnt/c/Windows/explorer.exe "http://localhost:$FRONTEND_PORT" 2>/dev/null &
fi
