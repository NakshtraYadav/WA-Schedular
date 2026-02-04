#!/bin/bash
# ============================================================================
#  WA Scheduler - Update Script v2.1
#  Fixed for local WSL development
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_REPO="NakshtraYadav/WA-Schedular"
GITHUB_BRANCH="main"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/commits/${GITHUB_BRANCH}"
GITHUB_ARCHIVE="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.zip"
VERSION_FILE="$SCRIPT_DIR/.version"
UPDATE_LOG="$SCRIPT_DIR/logs/system/update.log"
LOCK_FILE="$SCRIPT_DIR/.update.lock"
BACKUP_DIR="$SCRIPT_DIR/.backup"

# Create log directory
mkdir -p "$SCRIPT_DIR/logs/system"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$UPDATE_LOG"
    echo -e "$1"
}

# Lock management
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$LOCK_PID" ] && ps -p "$LOCK_PID" > /dev/null 2>&1; then
            log "${RED}[!] Another update is in progress (PID: $LOCK_PID)${NC}"
            return 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

cleanup() {
    release_lock
    rm -rf /tmp/wa-update-* 2>/dev/null
}
trap cleanup EXIT

get_remote_version() {
    RESPONSE=$(curl -s -w "\n%{http_code}" "$GITHUB_API" 2>/dev/null)
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" = "403" ]; then
        log "${YELLOW}[!] GitHub API rate limit exceeded${NC}"
        return 1
    fi
    
    echo "$BODY" | grep '"sha"' | head -1 | cut -d'"' -f4
}

get_local_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "none"
    fi
}

check_update() {
    log "${BLUE}Checking for updates...${NC}"
    
    REMOTE_SHA=$(get_remote_version)
    LOCAL_SHA=$(get_local_version)
    
    if [ -z "$REMOTE_SHA" ]; then
        log "${RED}[!] Could not fetch remote version${NC}"
        return 2
    fi
    
    if [ "$REMOTE_SHA" = "$LOCAL_SHA" ]; then
        log "${GREEN}[OK] Already up to date (${LOCAL_SHA:0:7})${NC}"
        return 1
    else
        log "${YELLOW}[!] Update available: ${LOCAL_SHA:0:7} -> ${REMOTE_SHA:0:7}${NC}"
        return 0
    fi
}

create_backup() {
    log "${BLUE}Creating backup...${NC}"
    
    BACKUP_TIME=$(date '+%Y%m%d_%H%M%S')
    CURRENT_BACKUP="$BACKUP_DIR/$BACKUP_TIME"
    mkdir -p "$CURRENT_BACKUP"
    
    [ -f "$SCRIPT_DIR/backend/server.py" ] && cp "$SCRIPT_DIR/backend/server.py" "$CURRENT_BACKUP/"
    [ -d "$SCRIPT_DIR/frontend/src" ] && cp -r "$SCRIPT_DIR/frontend/src" "$CURRENT_BACKUP/frontend_src"
    [ -f "$SCRIPT_DIR/version.json" ] && cp "$SCRIPT_DIR/version.json" "$CURRENT_BACKUP/"
    [ -f "$VERSION_FILE" ] && cp "$VERSION_FILE" "$CURRENT_BACKUP/.version"
    
    ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null
    
    echo "$CURRENT_BACKUP"
    log "${GREEN}[OK] Backup created${NC}"
}

rollback() {
    log "${YELLOW}Rolling back...${NC}"
    
    LATEST_BACKUP=$(ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        log "${RED}[!] No backup found${NC}"
        return 1
    fi
    
    [ -f "$LATEST_BACKUP/server.py" ] && cp "$LATEST_BACKUP/server.py" "$SCRIPT_DIR/backend/"
    [ -d "$LATEST_BACKUP/frontend_src" ] && cp -r "$LATEST_BACKUP/frontend_src/"* "$SCRIPT_DIR/frontend/src/"
    [ -f "$LATEST_BACKUP/version.json" ] && cp "$LATEST_BACKUP/version.json" "$SCRIPT_DIR/"
    [ -f "$LATEST_BACKUP/.version" ] && cp "$LATEST_BACKUP/.version" "$VERSION_FILE"
    
    log "${GREEN}[OK] Rollback complete${NC}"
}

download_update() {
    log "${BLUE}Downloading update...${NC}"
    
    TEMP_DIR=$(mktemp -d /tmp/wa-update-XXXXXX)
    TEMP_ZIP="$TEMP_DIR/update.zip"
    
    if ! curl -sL --connect-timeout 30 --max-time 120 "$GITHUB_ARCHIVE" -o "$TEMP_ZIP"; then
        log "${RED}[!] Download failed${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    if [ ! -s "$TEMP_ZIP" ]; then
        log "${RED}[!] Downloaded file is empty${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    if ! unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"; then
        log "${RED}[!] Extraction failed${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "WA-Schedular-*" | head -1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        log "${RED}[!] Could not find extracted files${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    log "${GREEN}[OK] Download complete${NC}"
    echo "$EXTRACTED_DIR"
}

apply_update() {
    EXTRACTED_DIR="$1"
    
    log "${BLUE}Applying update...${NC}"
    
    # Backup .env files
    [ -f "$SCRIPT_DIR/backend/.env" ] && cp "$SCRIPT_DIR/backend/.env" "/tmp/backend.env.bak"
    [ -f "$SCRIPT_DIR/frontend/.env" ] && cp "$SCRIPT_DIR/frontend/.env" "/tmp/frontend.env.bak"
    
    # Update version.json
    [ -f "$EXTRACTED_DIR/version.json" ] && cp "$EXTRACTED_DIR/version.json" "$SCRIPT_DIR/"
    
    # Update backend
    [ -f "$EXTRACTED_DIR/backend/server.py" ] && cp "$EXTRACTED_DIR/backend/server.py" "$SCRIPT_DIR/backend/"
    [ -f "$EXTRACTED_DIR/backend/requirements.txt" ] && cp "$EXTRACTED_DIR/backend/requirements.txt" "$SCRIPT_DIR/backend/"
    
    # Update frontend source (atomic swap)
    if [ -d "$EXTRACTED_DIR/frontend/src" ]; then
        rm -rf "$SCRIPT_DIR/frontend/src.new" 2>/dev/null
        cp -r "$EXTRACTED_DIR/frontend/src" "$SCRIPT_DIR/frontend/src.new"
        rm -rf "$SCRIPT_DIR/frontend/src.old" 2>/dev/null
        mv "$SCRIPT_DIR/frontend/src" "$SCRIPT_DIR/frontend/src.old" 2>/dev/null
        mv "$SCRIPT_DIR/frontend/src.new" "$SCRIPT_DIR/frontend/src"
        rm -rf "$SCRIPT_DIR/frontend/src.old"
    fi
    [ -f "$EXTRACTED_DIR/frontend/public/index.html" ] && cp "$EXTRACTED_DIR/frontend/public/index.html" "$SCRIPT_DIR/frontend/public/"
    [ -f "$EXTRACTED_DIR/frontend/package.json" ] && cp "$EXTRACTED_DIR/frontend/package.json" "$SCRIPT_DIR/frontend/"
    
    # Update WhatsApp service
    [ -d "$SCRIPT_DIR/whatsapp-service" ] && {
        [ -f "$EXTRACTED_DIR/whatsapp-service/index.js" ] && cp "$EXTRACTED_DIR/whatsapp-service/index.js" "$SCRIPT_DIR/whatsapp-service/"
        [ -f "$EXTRACTED_DIR/whatsapp-service/package.json" ] && cp "$EXTRACTED_DIR/whatsapp-service/package.json" "$SCRIPT_DIR/whatsapp-service/"
    }
    
    # Update shell scripts
    for script in setup.sh start.sh stop.sh status.sh logs.sh fix-whatsapp.sh update.sh auto-updater.sh; do
        [ -f "$EXTRACTED_DIR/$script" ] && {
            cp "$EXTRACTED_DIR/$script" "$SCRIPT_DIR/"
            chmod +x "$SCRIPT_DIR/$script"
        }
    done
    
    # Update README
    [ -f "$EXTRACTED_DIR/README.md" ] && cp "$EXTRACTED_DIR/README.md" "$SCRIPT_DIR/"
    
    # Restore .env files
    [ -f "/tmp/backend.env.bak" ] && cp "/tmp/backend.env.bak" "$SCRIPT_DIR/backend/.env"
    [ -f "/tmp/frontend.env.bak" ] && cp "/tmp/frontend.env.bak" "$SCRIPT_DIR/frontend/.env"
    
    # Cleanup
    rm -rf "$(dirname "$EXTRACTED_DIR")"
    rm -f /tmp/backend.env.bak /tmp/frontend.env.bak
    
    log "${GREEN}[OK] Files updated${NC}"
}

install_dependencies() {
    log "${BLUE}Installing dependencies...${NC}"
    
    cd "$SCRIPT_DIR/frontend"
    if command -v yarn &> /dev/null; then
        yarn install --silent 2>/dev/null || npm install --legacy-peer-deps --silent 2>/dev/null || true
    else
        npm install --legacy-peer-deps --silent 2>/dev/null || true
    fi
    
    cd "$SCRIPT_DIR/backend"
    if [ -d "venv" ]; then
        source venv/bin/activate
        pip install -q -r requirements.txt 2>/dev/null || true
        deactivate
    else
        pip install -q -r requirements.txt 2>/dev/null || true
    fi
    
    log "${GREEN}[OK] Dependencies updated${NC}"
}

save_version() {
    REMOTE_SHA=$(get_remote_version)
    if [ -n "$REMOTE_SHA" ]; then
        echo "$REMOTE_SHA" > "$VERSION_FILE"
        log "${GREEN}[OK] Version saved: ${REMOTE_SHA:0:7}${NC}"
    fi
}

stop_services() {
    log "${BLUE}Stopping services...${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Check for supervisor first
    if command -v supervisorctl &> /dev/null && supervisorctl status &> /dev/null 2>&1; then
        sudo supervisorctl stop backend frontend 2>/dev/null || supervisorctl stop backend frontend 2>/dev/null
    else
        # Local: use stop.sh or kill by PID
        if [ -f "./stop.sh" ]; then
            ./stop.sh > /dev/null 2>&1 || true
        fi
        
        # Also kill by port as backup
        for port in 3000 8001 3001; do
            pid=$(lsof -t -i:$port 2>/dev/null)
            [ -n "$pid" ] && kill -9 $pid 2>/dev/null || true
        done
    fi
    
    sleep 2
    log "${GREEN}[OK] Services stopped${NC}"
}

start_services() {
    log "${BLUE}Starting services...${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Check for supervisor first
    if command -v supervisorctl &> /dev/null && supervisorctl status &> /dev/null 2>&1; then
        sudo supervisorctl start backend frontend 2>/dev/null || supervisorctl start backend frontend 2>/dev/null
        sleep 3
        log "${GREEN}[OK] Services started via supervisor${NC}"
    else
        # Local: use start.sh in foreground mode briefly then background
        if [ -f "./start.sh" ]; then
            log "  Starting services with start.sh..."
            # Run start.sh but don't wait for frontend compilation
            ./start.sh &
            START_PID=$!
            
            # Wait for backend to be ready (max 30 seconds)
            log "  Waiting for backend..."
            for i in {1..15}; do
                if curl -s http://localhost:8001/api/ > /dev/null 2>&1; then
                    log "${GREEN}[OK] Backend is running${NC}"
                    break
                fi
                sleep 2
            done
            
            # Don't wait for frontend - it compiles in background
            log "${GREEN}[OK] Services starting (frontend compiling in background)${NC}"
            log "  Frontend will be ready at http://localhost:3000 in 1-2 minutes"
        else
            log "${RED}[!] start.sh not found${NC}"
        fi
    fi
}

# ============================================================================
#  Main
# ============================================================================

case "${1:-check}" in
    check)
        echo ""
        echo -e "${BLUE}============================================${NC}"
        echo -e "${BLUE}  WA Scheduler - Update Check${NC}"
        echo -e "${BLUE}============================================${NC}"
        echo ""
        check_update
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            echo ""
            echo -e "Run ${CYAN}./update.sh install${NC} to apply the update"
        fi
        echo ""
        ;;
        
    install|update)
        echo ""
        echo -e "${BLUE}============================================${NC}"
        echo -e "${BLUE}  WA Scheduler - Installing Update${NC}"
        echo -e "${BLUE}============================================${NC}"
        echo ""
        
        acquire_lock || exit 1
        
        check_update
        if [ $? -eq 1 ]; then
            echo ""
            exit 0
        fi
        
        create_backup
        
        EXTRACTED=$(download_update)
        if [ $? -ne 0 ]; then
            log "${RED}[!] Download failed${NC}"
            exit 1
        fi
        
        # Stop services first
        stop_services
        
        apply_update "$EXTRACTED"
        install_dependencies
        save_version
        
        echo ""
        echo -e "${YELLOW}Restart services now?${NC}"
        read -p "  (y/n): " RESTART
        if [[ "$RESTART" =~ ^[Yy]$ ]]; then
            start_services
        else
            echo ""
            echo -e "Run ${CYAN}./start.sh${NC} to start services manually"
        fi
        
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}  Update Complete!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        ;;
        
    force)
        echo ""
        log "${YELLOW}Force updating...${NC}"
        
        acquire_lock || exit 1
        
        create_backup
        
        EXTRACTED=$(download_update)
        if [ $? -ne 0 ]; then
            log "${RED}[!] Download failed${NC}"
            exit 1
        fi
        
        stop_services
        apply_update "$EXTRACTED"
        install_dependencies
        save_version
        start_services
        
        echo ""
        echo -e "${GREEN}Force update complete!${NC}"
        echo -e "Frontend compiling in background - wait 1-2 minutes"
        echo ""
        ;;
        
    rollback)
        echo ""
        acquire_lock || exit 1
        stop_services
        rollback
        start_services
        echo ""
        ;;
        
    version)
        LOCAL=$(get_local_version)
        REMOTE=$(get_remote_version)
        echo ""
        echo "Local:  ${LOCAL:0:7}"
        echo "Remote: ${REMOTE:0:7}"
        echo ""
        ;;
        
    *)
        echo ""
        echo "Usage: ./update.sh [command]"
        echo ""
        echo "Commands:"
        echo "  check    - Check for updates (default)"
        echo "  install  - Download and install update"
        echo "  force    - Force update and restart (no prompts)"
        echo "  rollback - Rollback to previous version"
        echo "  version  - Show version info"
        echo ""
        ;;
esac
