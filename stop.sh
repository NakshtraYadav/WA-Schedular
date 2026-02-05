#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Stop All Services (Ubuntu/WSL)
#  v2.2.0 - Graceful shutdown for session persistence
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
# GRACEFUL SHUTDOWN FOR WHATSAPP SERVICE (CRITICAL FOR SESSION)
# ============================================================================
echo -e "${YELLOW}[1/5]${NC} Gracefully stopping WhatsApp service (preserving session)..."

# Try to trigger graceful shutdown via API first (preserves session)
if curl -s --max-time 5 http://localhost:$WHATSAPP_PORT/health > /dev/null 2>&1; then
    echo "  Sending graceful shutdown signal to WhatsApp service..."
    # The service has shutdown handlers that will save session
    # Give it time to save
    
    # Find the WhatsApp service process and send SIGTERM (not SIGKILL)
    WA_PID=$(lsof -t -i:$WHATSAPP_PORT 2>/dev/null | head -1)
    if [ -n "$WA_PID" ]; then
        kill -TERM $WA_PID 2>/dev/null
        echo "  Waiting for WhatsApp service to save session (up to 15s)..."
        for i in {1..15}; do
            if ! kill -0 $WA_PID 2>/dev/null; then
                echo -e "  ${GREEN}[OK]${NC} WhatsApp service stopped gracefully"
                break
            fi
            sleep 1
        done
        # Force kill only if still running after graceful timeout
        if kill -0 $WA_PID 2>/dev/null; then
            echo "  Forcing shutdown..."
            kill -9 $WA_PID 2>/dev/null
        fi
    fi
else
    echo "  WhatsApp service not responding, cleaning up..."
fi

echo ""

# ============================================================================
# STOP BY PID FILES
# ============================================================================
echo -e "${YELLOW}[2/5]${NC} Stopping services by PID..."

for pidfile in .wa.pid .backend.pid .frontend.pid; do
    if [ -f "$SCRIPT_DIR/$pidfile" ]; then
        pid=$(cat "$SCRIPT_DIR/$pidfile")
        if ps -p $pid > /dev/null 2>&1; then
            # Use SIGTERM first for graceful shutdown
            kill -TERM $pid 2>/dev/null
            sleep 1
            # Force kill if still running
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid 2>/dev/null
            fi
            echo "  Stopped PID $pid ($pidfile)"
        fi
        rm -f "$SCRIPT_DIR/$pidfile"
    fi
done

echo -e "${GREEN}[OK]${NC} PID-based stop complete"
echo ""

# ============================================================================
# STOP BY PORT (with graceful first)
# ============================================================================
echo -e "${YELLOW}[3/5]${NC} Cleaning up ports..."

for port in $BACKEND_PORT $FRONTEND_PORT; do
    pids=$(lsof -t -i:$port 2>/dev/null)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            # Try graceful first
            kill -TERM $pid 2>/dev/null
            sleep 1
            # Then force if needed
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid 2>/dev/null
            fi
            echo "  Killed process on port $port (PID: $pid)"
        done
    fi
done

# Final check for WhatsApp port
pids=$(lsof -t -i:$WHATSAPP_PORT 2>/dev/null)
if [ -n "$pids" ]; then
    for pid in $pids; do
        kill -9 $pid 2>/dev/null
        echo "  Force killed lingering WhatsApp process (PID: $pid)"
    done
fi

echo -e "${GREEN}[OK]${NC} Ports cleared"
echo ""

# ============================================================================
# STOP AUTO-UPDATER
# ============================================================================
if [ -f "$SCRIPT_DIR/.auto-updater.pid" ]; then
    echo -e "${YELLOW}[4/5]${NC} Stopping auto-updater..."
    "$SCRIPT_DIR/auto-updater.sh" stop 2>/dev/null || true
    echo ""
else
    echo -e "${YELLOW}[4/5]${NC} Auto-updater not running"
    echo ""
fi

# ============================================================================
# KILL ORPHAN PROCESSES (but NOT Chromium - let it persist for session)
# ============================================================================
echo -e "${YELLOW}[5/5]${NC} Cleaning up orphan processes..."

# Kill node processes for our services
pkill -TERM -f "react-scripts" 2>/dev/null && echo "  Stopped React processes" || true
pkill -TERM -f "uvicorn.*server:app" 2>/dev/null && echo "  Stopped Backend processes" || true

# Don't kill Chromium immediately - WhatsApp session may need it
# The Chromium processes will be cleaned up when new WhatsApp service starts

sleep 2

# Force cleanup of any stuck processes
pkill -9 -f "react-scripts" 2>/dev/null || true
pkill -9 -f "uvicorn.*server:app" 2>/dev/null || true

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
    echo ""
    echo -e "  ${CYAN}Session Status:${NC} WhatsApp session preserved in MongoDB/filesystem"
    echo -e "  ${CYAN}Note:${NC} On next start, session will be automatically restored"
else
    echo -e "${YELLOW}  Some processes may still be running. Try running ./stop.sh again${NC}"
fi

echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  To start services again: ./start.sh"
echo ""
