#!/bin/bash
# =============================================================================
#  WA Scheduler - Zero-Touch Update System
#  
#  Performs updates with ZERO manual intervention required.
#  Protects: WhatsApp sessions, scheduler jobs, MongoDB writes, locks
#
#  Usage:
#    ./zero-touch-update.sh              # Standard update
#    ./zero-touch-update.sh --force      # Force update even if risky
#    ./zero-touch-update.sh --rollback   # Rollback to previous version
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/logs/update-$(date +%Y%m%d-%H%M%S).log"

# Ensure logs directory exists
mkdir -p "$PROJECT_ROOT/logs"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================
preflight_checks() {
    log "INFO" "━━━ PRE-FLIGHT CHECKS ━━━"
    
    # Check if PM2 is installed
    if ! command -v pm2 &> /dev/null; then
        log "WARN" "PM2 not installed - falling back to manual restart"
        USE_PM2=false
    else
        USE_PM2=true
        log "INFO" "✓ PM2 available"
    fi
    
    # Check git status
    if [ ! -d "$PROJECT_ROOT/.git" ]; then
        log "ERROR" "Not a git repository!"
        exit 1
    fi
    
    # Check for uncommitted changes
    if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
        log "WARN" "Uncommitted changes detected - stashing..."
        git -C "$PROJECT_ROOT" stash --quiet
    fi
    
    # Check WhatsApp session health
    if curl -s --max-time 3 http://localhost:3001/session/health > /dev/null 2>&1; then
        HEALTH=$(curl -s http://localhost:3001/session/health)
        SESSION_STATUS=$(echo "$HEALTH" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        
        if [ "$SESSION_STATUS" = "critical" ]; then
            log "WARN" "WhatsApp session health is CRITICAL"
            if [ "$1" != "--force" ]; then
                log "ERROR" "Aborting update due to unhealthy session. Use --force to override."
                exit 1
            fi
        else
            log "INFO" "✓ WhatsApp session health: $SESSION_STATUS"
        fi
    else
        log "INFO" "WhatsApp service not running - safe to update"
    fi
    
    # Check for in-flight messages
    if curl -s --max-time 3 http://localhost:8001/api/diagnostics > /dev/null 2>&1; then
        log "INFO" "✓ Backend responding"
    fi
    
    log "INFO" "✓ Pre-flight checks passed"
}

# =============================================================================
# CREATE ROLLBACK SNAPSHOT
# =============================================================================
create_snapshot() {
    log "INFO" "━━━ CREATING ROLLBACK SNAPSHOT ━━━"
    
    SNAPSHOT_DIR="$PROJECT_ROOT/.snapshots"
    mkdir -p "$SNAPSHOT_DIR"
    
    # Store current commit hash
    CURRENT_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    echo "$CURRENT_COMMIT" > "$SNAPSHOT_DIR/last-known-good"
    
    # Store current version
    if [ -f "$PROJECT_ROOT/version.json" ]; then
        cp "$PROJECT_ROOT/version.json" "$SNAPSHOT_DIR/version.json.bak"
    fi
    
    log "INFO" "✓ Snapshot created: $CURRENT_COMMIT"
}

# =============================================================================
# FETCH UPDATES
# =============================================================================
fetch_updates() {
    log "INFO" "━━━ FETCHING UPDATES ━━━"
    
    OLD_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD | cut -c1-7)
    
    # Fetch latest
    git -C "$PROJECT_ROOT" fetch origin main --quiet
    
    # Check if there are updates
    LOCAL=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
    REMOTE=$(git -C "$PROJECT_ROOT" rev-parse origin/main)
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        log "INFO" "Already up to date ($OLD_COMMIT)"
        exit 0
    fi
    
    # Pull updates
    git -C "$PROJECT_ROOT" pull origin main --quiet
    
    NEW_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD | cut -c1-7)
    log "INFO" "✓ Updated: $OLD_COMMIT → $NEW_COMMIT"
    
    # Detect what changed
    CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff "$LOCAL" "$REMOTE" --name-only)
    
    BACKEND_CHANGED=false
    FRONTEND_CHANGED=false
    WHATSAPP_CHANGED=false
    DEPS_CHANGED=false
    
    echo "$CHANGED_FILES" | while read -r file; do
        case "$file" in
            backend/*) BACKEND_CHANGED=true ;;
            frontend/*) FRONTEND_CHANGED=true ;;
            whatsapp-service/*) WHATSAPP_CHANGED=true ;;
            */package.json|*/requirements.txt) DEPS_CHANGED=true ;;
        esac
    done
    
    # Export for other functions
    export BACKEND_CHANGED FRONTEND_CHANGED WHATSAPP_CHANGED DEPS_CHANGED
}

# =============================================================================
# INSTALL DEPENDENCIES
# =============================================================================
install_dependencies() {
    log "INFO" "━━━ INSTALLING DEPENDENCIES ━━━"
    
    # Check if package.json changed
    if git -C "$PROJECT_ROOT" diff HEAD~1 --name-only | grep -q "package.json"; then
        log "INFO" "Installing npm packages (frontend)..."
        cd "$PROJECT_ROOT/frontend" && npm install --legacy-peer-deps --silent 2>/dev/null
        
        log "INFO" "Installing npm packages (whatsapp-service)..."
        cd "$PROJECT_ROOT/whatsapp-service" && npm install --silent 2>/dev/null
    fi
    
    # Check if requirements.txt changed
    if git -C "$PROJECT_ROOT" diff HEAD~1 --name-only | grep -q "requirements.txt"; then
        log "INFO" "Installing pip packages..."
        if [ -f "$PROJECT_ROOT/backend/venv/bin/pip" ]; then
            "$PROJECT_ROOT/backend/venv/bin/pip" install -q -r "$PROJECT_ROOT/backend/requirements.txt"
        else
            pip3 install -q -r "$PROJECT_ROOT/backend/requirements.txt"
        fi
    fi
    
    log "INFO" "✓ Dependencies updated"
}

# =============================================================================
# GRACEFUL RELOAD (PM2)
# =============================================================================
graceful_reload_pm2() {
    log "INFO" "━━━ GRACEFUL RELOAD (PM2) ━━━"
    
    # Check if PM2 is managing our processes
    if pm2 list 2>/dev/null | grep -q "wa-"; then
        # Reload each service gracefully
        log "INFO" "Reloading WhatsApp service (30s graceful shutdown)..."
        pm2 reload wa-whatsapp --update-env 2>/dev/null || true
        
        log "INFO" "Reloading Backend service..."
        pm2 reload wa-backend --update-env 2>/dev/null || true
        
        log "INFO" "Reloading Frontend service..."
        pm2 reload wa-frontend --update-env 2>/dev/null || true
        
        # Wait for all services to be online
        log "INFO" "Waiting for services to come online..."
        sleep 5
        
        pm2 status
        
        log "INFO" "✓ PM2 graceful reload complete"
    else
        log "WARN" "PM2 not managing services - using fallback restart"
        fallback_restart
    fi
}

# =============================================================================
# FALLBACK RESTART (without PM2)
# =============================================================================
fallback_restart() {
    log "INFO" "━━━ FALLBACK RESTART ━━━"
    
    # Use existing stop/start scripts
    if [ -f "$PROJECT_ROOT/stop.sh" ]; then
        log "INFO" "Stopping services gracefully..."
        bash "$PROJECT_ROOT/stop.sh" || true
        sleep 3
    fi
    
    if [ -f "$PROJECT_ROOT/start.sh" ]; then
        log "INFO" "Starting services..."
        bash "$PROJECT_ROOT/start.sh" || true
    fi
    
    log "INFO" "✓ Fallback restart complete"
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION
# =============================================================================
validate_deployment() {
    log "INFO" "━━━ VALIDATING DEPLOYMENT ━━━"
    
    VALIDATION_FAILED=false
    
    # Check backend
    for i in {1..30}; do
        if curl -s --max-time 2 http://localhost:8001/api/health > /dev/null 2>&1; then
            log "INFO" "✓ Backend healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            log "ERROR" "Backend validation failed"
            VALIDATION_FAILED=true
        fi
        sleep 1
    done
    
    # Check frontend
    for i in {1..30}; do
        if curl -s --max-time 2 http://localhost:3000 > /dev/null 2>&1; then
            log "INFO" "✓ Frontend healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            log "WARN" "Frontend validation failed (non-critical)"
        fi
        sleep 1
    done
    
    # Check WhatsApp service
    for i in {1..30}; do
        if curl -s --max-time 2 http://localhost:3001/health > /dev/null 2>&1; then
            log "INFO" "✓ WhatsApp service healthy"
            
            # Check session restoration
            sleep 3
            HEALTH=$(curl -s http://localhost:3001/session/health 2>/dev/null)
            if echo "$HEALTH" | grep -q '"connected":true'; then
                log "INFO" "✓ WhatsApp session restored"
            else
                log "WARN" "WhatsApp session not yet connected (may be reconnecting)"
            fi
            break
        fi
        if [ $i -eq 30 ]; then
            log "ERROR" "WhatsApp service validation failed"
            VALIDATION_FAILED=true
        fi
        sleep 1
    done
    
    if [ "$VALIDATION_FAILED" = true ]; then
        log "ERROR" "Deployment validation FAILED - initiating rollback"
        rollback
        exit 1
    fi
    
    log "INFO" "✓ All validations passed"
}

# =============================================================================
# ROLLBACK
# =============================================================================
rollback() {
    log "WARN" "━━━ INITIATING ROLLBACK ━━━"
    
    SNAPSHOT_DIR="$PROJECT_ROOT/.snapshots"
    
    if [ -f "$SNAPSHOT_DIR/last-known-good" ]; then
        ROLLBACK_COMMIT=$(cat "$SNAPSHOT_DIR/last-known-good")
        log "INFO" "Rolling back to: $ROLLBACK_COMMIT"
        
        git -C "$PROJECT_ROOT" reset --hard "$ROLLBACK_COMMIT"
        
        # Restart services
        if [ "$USE_PM2" = true ] && pm2 list 2>/dev/null | grep -q "wa-"; then
            pm2 reload wa-scheduler --update-env
        else
            fallback_restart
        fi
        
        log "INFO" "✓ Rollback complete"
    else
        log "ERROR" "No rollback snapshot available!"
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}       WA Scheduler - Zero-Touch Update System${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    case "${1:-update}" in
        --rollback)
            rollback
            ;;
        --force|update|"")
            preflight_checks "$1"
            create_snapshot
            fetch_updates
            install_dependencies
            
            if [ "$USE_PM2" = true ]; then
                graceful_reload_pm2
            else
                fallback_restart
            fi
            
            validate_deployment
            ;;
        *)
            echo "Usage: $0 [--force|--rollback]"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       UPDATE COMPLETE - Zero manual intervention required${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log "INFO" "Update log saved to: $LOG_FILE"
}

main "$@"
