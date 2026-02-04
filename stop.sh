#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Stop All Services (Ubuntu/WSL)
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ports
FRONTEND_PORT=3000
BACKEND_PORT=8001
WHATSAPP_PORT=3001

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${RED}       WhatsApp Scheduler - Stopping Services${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# ============================================================================
# STOP BY PID FILES
# ============================================================================
echo -e "${YELLOW}[1/3]${NC} Stopping services by PID..."

for pidfile in .wa.pid .backend.pid .frontend.pid; do
    if [ -f "$SCRIPT_DIR/$pidfile" ]; then
        pid=$(cat "$SCRIPT_DIR/$pidfile")
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null
            echo "  Stopped PID $pid ($pidfile)"
        fi
        rm -f "$SCRIPT_DIR/$pidfile"
    fi
done

echo -e "${GREEN}[OK]${NC} PID-based stop complete"
echo ""

# ============================================================================
# STOP BY PORT
# ============================================================================
echo -e "${YELLOW}[2/3]${NC} Cleaning up ports..."

for port in $FRONTEND_PORT $BACKEND_PORT $WHATSAPP_PORT; do
    pids=$(lsof -t -i:$port 2>/dev/null)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            kill -9 $pid 2>/dev/null
            echo "  Killed process on port $port (PID: $pid)"
        done
    fi
done

echo -e "${GREEN}[OK]${NC} Ports cleared"
echo ""

# ============================================================================
# STOP AUTO-UPDATER
# ============================================================================
if [ -f "$SCRIPT_DIR/.auto-updater.pid" ]; then
    echo -e "${YELLOW}[3/4]${NC} Stopping auto-updater..."
    "$SCRIPT_DIR/auto-updater.sh" stop 2>/dev/null || true
    echo ""
else
    echo -e "${YELLOW}[3/4]${NC} Auto-updater not running"
    echo ""
fi

# ============================================================================
# KILL ORPHAN PROCESSES
# ============================================================================
echo -e "${YELLOW}[4/4]${NC} Cleaning up orphan processes..."

# Kill any node processes related to our services
pkill -f "node.*index.js" 2>/dev/null && echo "  Killed WhatsApp node processes" || true
pkill -f "react-scripts" 2>/dev/null && echo "  Killed React processes" || true
pkill -f "uvicorn.*server:app" 2>/dev/null && echo "  Killed Backend processes" || true

sleep 2

echo -e "${GREEN}[OK]${NC} Orphan processes cleaned"
echo ""

# ============================================================================
# VERIFY
# ============================================================================
echo -e "${BLUE}============================================================================${NC}"
echo "  Verifying shutdown..."
echo ""

ALL_STOPPED=true

for port in $FRONTEND_PORT $BACKEND_PORT $WHATSAPP_PORT; do
    if lsof -i:$port > /dev/null 2>&1; then
        echo -e "  ${RED}[!]${NC} Port $port still in use"
        ALL_STOPPED=false
    else
        echo -e "  ${GREEN}[OK]${NC} Port $port is free"
    fi
done

echo ""

if [ "$ALL_STOPPED" = true ]; then
    echo -e "${GREEN}                    ALL SERVICES STOPPED${NC}"
else
    echo -e "${YELLOW}  Some processes may still be running. Try running ./stop.sh again${NC}"
fi

echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  To start services again: ./start.sh"
echo ""
