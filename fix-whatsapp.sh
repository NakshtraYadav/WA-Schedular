#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Fix WhatsApp Session (Ubuntu/WSL)
#  Clears session data, browser locks, and restarts the service
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WA_DIR="$SCRIPT_DIR/whatsapp-service"
DATA_DIR="$SCRIPT_DIR/data/whatsapp-sessions"

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${YELLOW}       WhatsApp Scheduler - Fix WhatsApp Session${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  This will:"
echo "    1. Kill any stuck browser processes"
echo "    2. Remove browser lock files"
echo "    3. Optionally clear session (requires new QR scan)"
echo "    4. Restart the service"
echo ""

read -p "  Clear session completely? (requires new QR scan) [y/N]: " clear_session
read -p "  Continue? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    exit 0
fi

echo ""

# ============================================================================
# KILL BROWSER PROCESSES
# ============================================================================
echo -e "${YELLOW}[1/4]${NC} Killing stuck browser processes..."

# Kill chromium/chrome processes related to whatsapp-sessions
pkill -f "chromium.*whatsapp-sessions" 2>/dev/null || true
pkill -f "chrome.*whatsapp-sessions" 2>/dev/null || true
pkill -f "chromium.*wa-scheduler" 2>/dev/null || true
pkill -f "chrome.*wa-scheduler" 2>/dev/null || true

# Kill by port
pid=$(lsof -t -i:3001 2>/dev/null)
if [ -n "$pid" ]; then
    kill -9 $pid 2>/dev/null
    echo "  Killed WhatsApp service PID $pid"
fi

# Kill by process name
pkill -f "node.*index.js" 2>/dev/null || true
pkill -f "node.*whatsapp-service" 2>/dev/null || true

sleep 2
echo -e "${GREEN}[OK]${NC} Processes killed"
echo ""

# ============================================================================
# REMOVE LOCK FILES
# ============================================================================
echo -e "${YELLOW}[2/4]${NC} Removing browser lock files..."

SESSION_DIR="$DATA_DIR/session-wa-scheduler"
if [ -d "$SESSION_DIR" ]; then
    rm -f "$SESSION_DIR/SingletonLock" 2>/dev/null && echo "  Removed SingletonLock"
    rm -f "$SESSION_DIR/SingletonCookie" 2>/dev/null && echo "  Removed SingletonCookie"  
    rm -f "$SESSION_DIR/SingletonSocket" 2>/dev/null && echo "  Removed SingletonSocket"
fi

# Also check old location
OLD_SESSION="$WA_DIR/.wwebjs_auth/session-wa-scheduler"
if [ -d "$OLD_SESSION" ]; then
    rm -f "$OLD_SESSION/SingletonLock" 2>/dev/null
    rm -f "$OLD_SESSION/SingletonCookie" 2>/dev/null
    rm -f "$OLD_SESSION/SingletonSocket" 2>/dev/null
fi

echo -e "${GREEN}[OK]${NC} Lock files removed"
echo ""

# ============================================================================
# CLEAR SESSION (OPTIONAL)
# ============================================================================
if [[ "$clear_session" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[3/4]${NC} Clearing session data..."
    
    # New location
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"/*
        echo "  Cleared $DATA_DIR"
    fi
    
    # Old locations
    cd "$WA_DIR"
    if [ -d ".wwebjs_auth" ]; then
        rm -rf .wwebjs_auth
        echo "  Cleared .wwebjs_auth"
    fi
    if [ -d ".wwebjs_cache" ]; then
        rm -rf .wwebjs_cache
        echo "  Cleared .wwebjs_cache"
    fi
    
    echo -e "${GREEN}[OK]${NC} Session cleared - QR scan required"
else
    echo -e "${YELLOW}[3/4]${NC} Keeping session data (no QR scan needed if session valid)"
fi
echo ""

# ============================================================================
# RESTART SERVICE
# ============================================================================
echo -e "${YELLOW}[4/4]${NC} Restarting WhatsApp service..."

cd "$WA_DIR"

LOG_DIR="$SCRIPT_DIR/logs/whatsapp"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WA_LOG="$LOG_DIR/service_$TIMESTAMP.log"

nohup node index.js > "$WA_LOG" 2>&1 &
WA_PID=$!
echo $WA_PID > "$SCRIPT_DIR/.wa.pid"

echo "  Started with PID $WA_PID"

# Wait for service
echo -n "  Waiting for service"
for i in {1..30}; do
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}[OK]${NC} WhatsApp service ready"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# ============================================================================
# DONE
# ============================================================================
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}                         FIX COMPLETE${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
if [[ "$clear_session" =~ ^[Yy]$ ]]; then
    echo "  Session was cleared. Next steps:"
    echo "    1. Open http://localhost:3000/connect"
    echo "    2. Wait for QR code to appear (30-90 seconds)"
    echo "    3. Scan QR code with WhatsApp on your phone"
else
    echo "  Session kept. The service should reconnect automatically."
    echo "  If QR code appears, scan it to reconnect."
fi
echo ""
echo "  Log file: $WA_LOG"
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo ""
