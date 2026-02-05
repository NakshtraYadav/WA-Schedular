#!/bin/bash
# ============================================================================
#  WA Scheduler - Auto Updater
#  Checks for updates periodically and applies them automatically
# ============================================================================

GREEN='33[0;32m'
YELLOW='33[1;33m'
CYAN='33[0;36m'
NC='33[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.auto-updater.pid"
LOG_FILE="$SCRIPT_DIR/logs/auto-updater.log"
CHECK_INTERVAL=${AUTO_UPDATE_INTERVAL:-300}  # Default: 5 minutes

mkdir -p "$SCRIPT_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_and_update() {
    cd "$SCRIPT_DIR"
    
    # Fetch latest without merging
    git fetch origin main --quiet 2>/dev/null
    
    LOCAL=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
    REMOTE=$(git rev-parse origin/main 2>/dev/null | cut -c1-7)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log "Update available: $LOCAL -> $REMOTE"
        log "Running auto-update..."
        
        # Use start.sh update instead of deprecated update.sh
        "$SCRIPT_DIR/start.sh" update >> "$LOG_FILE" 2>&1
        
        log "Auto-update completed"
        return 0
    else
        log "Already up to date ($LOCAL)"
        return 1
    fi
}

start_daemon() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "Auto-updater already running (PID: $OLD_PID)"
            exit 0
        fi
    fi
    
    log "Starting auto-updater daemon (interval: ${CHECK_INTERVAL}s)"
    
    while true; do
        log "Checking for updates..."
        check_and_update
        sleep "$CHECK_INTERVAL"
    done &
    
    echo $! > "$PID_FILE"
    echo -e "${GREEN}Auto-updater started${NC} (PID: $!)"
    echo "  Check interval: ${CHECK_INTERVAL} seconds"
    echo "  Log file: $LOG_FILE"
}

stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" 2>/dev/null
            log "Auto-updater stopped (PID: $PID)"
            echo -e "${YELLOW}Auto-updater stopped${NC}"
        fi
        rm -f "$PID_FILE"
    else
        echo "Auto-updater not running"
    fi
}

status_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "Auto-updater: ${GREEN}Running${NC} (PID: $PID)"
            echo "  Interval: ${CHECK_INTERVAL} seconds"
            echo ""
            echo "Recent log:"
            tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
            return 0
        fi
    fi
    echo -e "Auto-updater: ${YELLOW}Stopped${NC}"
    return 1
}

case "${1:-status}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        status_daemon
        ;;
    check)
        log "Manual check triggered"
        check_and_update
        ;;
    *)
        echo "WA Scheduler - Auto Updater"
        echo ""
        echo "Usage: ./auto-updater.sh [command]"
        echo ""
        echo "  start    Start auto-updater daemon"
        echo "  stop     Stop auto-updater daemon"
        echo "  restart  Restart auto-updater"
        echo "  status   Check if running"
        echo "  check    Run single update check now"
        echo ""
        echo "Environment:"
        echo "  AUTO_UPDATE_INTERVAL=300  # Check interval in seconds"
        ;;
esac
