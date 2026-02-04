#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - View Logs (Ubuntu/WSL)
# ============================================================================

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}       WhatsApp Scheduler - Log Viewer${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Find latest log for each service
echo "  Available logs:"
echo ""

echo -e "  ${CYAN}[1]${NC} WhatsApp Service"
WA_LOG=$(ls -t "$LOG_DIR/whatsapp/"*.log 2>/dev/null | head -1)
if [ -n "$WA_LOG" ]; then
    echo "      $WA_LOG"
else
    echo "      (no logs yet)"
fi

echo ""
echo -e "  ${CYAN}[2]${NC} Backend API"
BE_LOG=$(ls -t "$LOG_DIR/backend/"*.log 2>/dev/null | head -1)
if [ -n "$BE_LOG" ]; then
    echo "      $BE_LOG"
else
    echo "      (no logs yet)"
fi

echo ""
echo -e "  ${CYAN}[3]${NC} Frontend"
FE_LOG=$(ls -t "$LOG_DIR/frontend/"*.log 2>/dev/null | head -1)
if [ -n "$FE_LOG" ]; then
    echo "      $FE_LOG"
else
    echo "      (no logs yet)"
fi

echo ""
echo -e "  ${CYAN}[4]${NC} All logs (tail -f)"
echo ""
echo -e "  ${CYAN}[0]${NC} Exit"
echo ""

read -p "  Select option [1-4]: " choice

case $choice in
    1)
        if [ -n "$WA_LOG" ]; then
            echo ""
            echo "  Showing WhatsApp logs (Ctrl+C to exit):"
            echo "  ---------------------------------------------------------------------------"
            tail -f "$WA_LOG"
        else
            echo "  No WhatsApp logs found"
        fi
        ;;
    2)
        if [ -n "$BE_LOG" ]; then
            echo ""
            echo "  Showing Backend logs (Ctrl+C to exit):"
            echo "  ---------------------------------------------------------------------------"
            tail -f "$BE_LOG"
        else
            echo "  No Backend logs found"
        fi
        ;;
    3)
        if [ -n "$FE_LOG" ]; then
            echo ""
            echo "  Showing Frontend logs (Ctrl+C to exit):"
            echo "  ---------------------------------------------------------------------------"
            tail -f "$FE_LOG"
        else
            echo "  No Frontend logs found"
        fi
        ;;
    4)
        echo ""
        echo "  Showing all logs (Ctrl+C to exit):"
        echo "  ---------------------------------------------------------------------------"
        tail -f "$LOG_DIR/whatsapp/"*.log "$LOG_DIR/backend/"*.log "$LOG_DIR/frontend/"*.log 2>/dev/null
        ;;
    *)
        echo "  Exiting..."
        ;;
esac
