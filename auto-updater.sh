#!/bin/bash
# ============================================================================
#  WA Scheduler - Auto Updater
#  Checks for updates periodically and applies them automatically
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.auto-updater.pid"
LOG_FILE="$SCRIPT_DIR/logs/auto-update.log"
CHECK_INTERVAL=${AUTO_UPDATE_INTERVAL:-3600}  # Default: 1 hour (was 5 min - too aggressive)

mkdir -p "$SCRIPT_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_git_remote() {
    cd "$SCRIPT_DIR"
    
    # Check if we have a git repo
    if [ ! -d ".git" ]; then
        log "ERROR: Not a git repository"
        return 1
    fi
    
    # Check if origin remote exists
    if ! git remote | grep -q "^origin$"; then
        log "No git remote 'origin' configured"
        log "To enable auto-updates, run:"
        log "  git remote add origin https://github.com/YourUsername/WA-Scheduler.git"
        return 1
    fi
    
    return 0
}

check_and_update() {
    cd "$SCRIPT_DIR"
    
    # Verify git remote is configured
    if ! check_git_remote; then
        return 2
    fi
    
    # Fetch latest without merging
    log "Fetching latest from remote..."
    if ! git fetch origin main --quiet 2>/dev/null; then
        log "Could not fetch from remote (network issue or remote doesn't exist)"
        return 1
    fi
    
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    
    if [ -z "$LOCAL" ] || [ -z "$REMOTE" ]; then
        log "Could not determine local or remote version"
        return 1
    fi
    
    LOCAL_SHORT="${LOCAL:0:7}"
    REMOTE_SHORT="${REMOTE:0:7}"
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log "Update available: $LOCAL_SHORT -> $REMOTE_SHORT"
        log "Running auto-update..."
        
        # Use the zero-touch update script if available
        if [ -x "$SCRIPT_DIR/scripts/zero-touch-update.sh" ]; then
            "$SCRIPT_DIR/scripts/zero-touch-update.sh" >> "$LOG_FILE" 2>&1
        elif [ -x "$SCRIPT_DIR/start.sh" ]; then
            "$SCRIPT_DIR/start.sh" update >> "$LOG_FILE" 2>&1
        else
            log "No update script found"
            return 1
        fi
        
        log "Auto-update completed"
        return 0
    else
        log "Already up to date ($LOCAL_SHORT)"
        return 0
    fi
}

start_daemon() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo -e "Auto-updater already running (PID: $OLD_PID)"
            exit 0
        fi
    fi
    
    # Check if git remote is configured before starting
    if ! check_git_remote; then
        echo -e "${YELLOW}Warning:${NC} Git remote not configured. Auto-updater will not function."
        echo "To configure, run:"
        echo "  git remote add origin https://github.com/YourUsername/WA-Scheduler.git"
        echo ""
        echo "Starting anyway (will retry on each check)..."
    fi
    
    log "Starting auto-updater daemon (interval: ${CHECK_INTERVAL}s / $(($CHECK_INTERVAL / 60)) min)"
    
    (
        while true; do
            log "Checking for updates..."
            check_and_update
            sleep "$CHECK_INTERVAL"
        done
    ) &
    
    echo $! > "$PID_FILE"
    echo -e "${GREEN}Auto-updater started${NC} (PID: $!)"
    echo "  Check interval: ${CHECK_INTERVAL} seconds ($(($CHECK_INTERVAL / 60)) minutes)"
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
    echo ""
    echo "=== Auto-Updater Status ==="
    echo ""
    
    # Check git remote
    cd "$SCRIPT_DIR"
    if [ -d ".git" ]; then
        REMOTE_URL=$(git remote get-url origin 2>/dev/null)
        if [ -n "$REMOTE_URL" ]; then
            echo -e "Git Remote: ${GREEN}Configured${NC}"
            echo "  URL: $REMOTE_URL"
        else
            echo -e "Git Remote: ${YELLOW}Not Configured${NC}"
            echo "  Auto-updates disabled until remote is set"
        fi
    else
        echo -e "Git Repo: ${RED}Not Found${NC}"
    fi
    echo ""
    
    # Check daemon status
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "Daemon: ${GREEN}Running${NC} (PID: $PID)"
            echo "  Interval: ${CHECK_INTERVAL} seconds ($(($CHECK_INTERVAL / 60)) minutes)"
        else
            echo -e "Daemon: ${YELLOW}Stopped${NC} (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "Daemon: ${YELLOW}Stopped${NC}"
    fi
    
    echo ""
    echo "Recent Log:"
    if [ -f "$LOG_FILE" ]; then
        tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    else
        echo "  (no log file)"
    fi
    echo ""
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
        echo "Commands:"
        echo "  start    Start auto-updater daemon"
        echo "  stop     Stop auto-updater daemon"
        echo "  restart  Restart auto-updater"
        echo "  status   Check if running and show git status"
        echo "  check    Run single update check now"
        echo ""
        echo "Environment Variables:"
        echo "  AUTO_UPDATE_INTERVAL=3600  # Check interval in seconds (default: 1 hour)"
        echo ""
        echo "Setup:"
        echo "  Before auto-updates work, you need to configure git remote:"
        echo "  git remote add origin https://github.com/YourUsername/WA-Scheduler.git"
        ;;
esac
