#!/bin/bash
# ============================================================================
#  WA Scheduler - Auto Updater Daemon
#  Runs in background and checks for updates every 30 minutes
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_LOG="$SCRIPT_DIR/logs/system/auto-update.log"
PID_FILE="$SCRIPT_DIR/.auto-updater.pid"
CHECK_INTERVAL=1800  # 30 minutes in seconds

# GitHub config
GITHUB_REPO="NakshtraYadav/WA-Schedular"
GITHUB_BRANCH="main"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/commits/${GITHUB_BRANCH}"
VERSION_FILE="$SCRIPT_DIR/.version"

mkdir -p "$SCRIPT_DIR/logs/system"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$UPDATE_LOG"
}

get_remote_version() {
    curl -s "$GITHUB_API" 2>/dev/null | grep '"sha"' | head -1 | cut -d'"' -f4
}

get_local_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "none"
    fi
}

check_and_update() {
    log "Checking for updates..."
    
    REMOTE_SHA=$(get_remote_version)
    LOCAL_SHA=$(get_local_version)
    
    if [ -z "$REMOTE_SHA" ]; then
        log "Could not fetch remote version"
        return
    fi
    
    if [ "$REMOTE_SHA" = "$LOCAL_SHA" ]; then
        log "Already up to date (${LOCAL_SHA:0:7})"
        return
    fi
    
    log "Update available: ${LOCAL_SHA:0:7} -> ${REMOTE_SHA:0:7}"
    log "Running auto-update..."
    
    # Run the update script in force mode
    cd "$SCRIPT_DIR"
    ./update.sh force >> "$UPDATE_LOG" 2>&1
    
    log "Auto-update completed"
}

start_daemon() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "Auto-updater is already running (PID: $OLD_PID)"
            exit 1
        fi
    fi
    
    echo "Starting auto-updater daemon..."
    log "=== Auto-updater started ==="
    
    # Run in background
    (
        echo $$ > "$PID_FILE"
        
        while true; do
            check_and_update
            sleep $CHECK_INTERVAL
        done
    ) &
    
    DAEMON_PID=$!
    echo $DAEMON_PID > "$PID_FILE"
    
    echo "Auto-updater started (PID: $DAEMON_PID)"
    echo "Checking for updates every 30 minutes"
    echo "Log: $UPDATE_LOG"
}

stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" 2>/dev/null
            rm -f "$PID_FILE"
            echo "Auto-updater stopped"
            log "=== Auto-updater stopped ==="
        else
            echo "Auto-updater not running"
            rm -f "$PID_FILE"
        fi
    else
        echo "Auto-updater not running"
    fi
}

status_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Auto-updater is running (PID: $PID)"
            echo ""
            echo "Last 10 log entries:"
            echo "---"
            tail -10 "$UPDATE_LOG" 2>/dev/null
        else
            echo "Auto-updater is not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        echo "Auto-updater is not running"
    fi
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
    *)
        echo ""
        echo "Usage: ./auto-updater.sh [command]"
        echo ""
        echo "Commands:"
        echo "  start   - Start the auto-updater daemon"
        echo "  stop    - Stop the auto-updater daemon"
        echo "  restart - Restart the daemon"
        echo "  status  - Show daemon status and recent logs"
        echo ""
        ;;
esac
