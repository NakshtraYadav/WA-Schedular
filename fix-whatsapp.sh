#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Fix WhatsApp Session (Ubuntu/WSL)
#  Clears session data and restarts the service
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WA_DIR="$SCRIPT_DIR/whatsapp-service"

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${YELLOW}       WhatsApp Scheduler - Fix WhatsApp Session${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  This will:"
echo "    1. Stop WhatsApp service"
echo "    2. Clear session and cache data"
echo "    3. Restart the service"
echo ""
echo "  You will need to scan the QR code again."
echo ""
read -p "  Continue? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    exit 0
fi

echo ""

# ============================================================================
# STOP SERVICE
# ============================================================================
echo -e "${YELLOW}[1/3]${NC} Stopping WhatsApp service..."

# Kill by port
pid=$(lsof -t -i:3001 2>/dev/null)
if [ -n "$pid" ]; then
    kill -9 $pid 2>/dev/null
    echo "  Killed PID $pid"
fi

# Kill by process name
pkill -f "node.*index.js" 2>/dev/null || true

sleep 2
echo -e "${GREEN}[OK]${NC} Service stopped"
echo ""

# ============================================================================
# CLEAR SESSION
# ============================================================================
echo -e "${YELLOW}[2/3]${NC} Clearing session data..."

cd "$WA_DIR"

if [ -d ".wwebjs_auth" ]; then
    rm -rf .wwebjs_auth
    echo "  Cleared .wwebjs_auth"
fi

if [ -d ".wwebjs_cache" ]; then
    rm -rf .wwebjs_cache
    echo "  Cleared .wwebjs_cache"
fi

echo -e "${GREEN}[OK]${NC} Session cleared"
echo ""

# ============================================================================
# RESTART SERVICE
# ============================================================================
echo -e "${YELLOW}[3/3]${NC} Restarting WhatsApp service..."

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
for i in {1..20}; do
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
echo "  Next steps:"
echo "    1. Open http://localhost:3000/connect"
echo "    2. Wait for QR code to appear (30-90 seconds)"
echo "    3. Scan QR code with WhatsApp on your phone"
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo ""
