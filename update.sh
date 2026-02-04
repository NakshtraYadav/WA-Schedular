#!/bin/bash
# ============================================================================
#  WA Scheduler - Update Script
#  Checks GitHub for updates and applies them
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

# Create log directory
mkdir -p "$SCRIPT_DIR/logs/system"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$UPDATE_LOG"
    echo -e "$1"
}

get_remote_version() {
    # Get latest commit SHA from GitHub
    curl -s "$GITHUB_API" 2>/dev/null | grep '"sha"' | head -1 | cut -d'"' -f4
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
        log "${RED}[!] Could not fetch remote version (network error?)${NC}"
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

download_update() {
    log "${BLUE}Downloading update...${NC}"
    
    TEMP_DIR=$(mktemp -d)
    TEMP_ZIP="$TEMP_DIR/update.zip"
    
    # Download the archive
    if ! curl -sL "$GITHUB_ARCHIVE" -o "$TEMP_ZIP"; then
        log "${RED}[!] Download failed${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Extract
    if ! unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"; then
        log "${RED}[!] Extraction failed${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Find extracted folder (usually repo-branch)
    EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "WA-Schedular-*" | head -1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        log "${RED}[!] Could not find extracted files${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    echo "$EXTRACTED_DIR"
}

apply_update() {
    EXTRACTED_DIR="$1"
    
    log "${BLUE}Applying update...${NC}"
    
    # Backup current .env files
    log "  Backing up configuration..."
    [ -f "$SCRIPT_DIR/backend/.env" ] && cp "$SCRIPT_DIR/backend/.env" "/tmp/backend.env.bak"
    [ -f "$SCRIPT_DIR/frontend/.env" ] && cp "$SCRIPT_DIR/frontend/.env" "/tmp/frontend.env.bak"
    
    # Files/folders to preserve (not overwrite)
    PRESERVE=(
        "logs"
        "backend/.env"
        "frontend/.env"
        "whatsapp-service/.wwebjs_auth"
        "whatsapp-service/.wwebjs_cache"
        ".version"
    )
    
    # Copy new files (excluding preserved)
    log "  Copying new files..."
    
    # Update backend
    cp "$EXTRACTED_DIR/backend/server.py" "$SCRIPT_DIR/backend/" 2>/dev/null
    cp "$EXTRACTED_DIR/backend/requirements.txt" "$SCRIPT_DIR/backend/" 2>/dev/null
    
    # Update frontend (source files only)
    cp -r "$EXTRACTED_DIR/frontend/src/"* "$SCRIPT_DIR/frontend/src/" 2>/dev/null
    cp "$EXTRACTED_DIR/frontend/public/index.html" "$SCRIPT_DIR/frontend/public/" 2>/dev/null
    cp "$EXTRACTED_DIR/frontend/package.json" "$SCRIPT_DIR/frontend/" 2>/dev/null
    
    # Update WhatsApp service
    cp "$EXTRACTED_DIR/whatsapp-service/index.js" "$SCRIPT_DIR/whatsapp-service/" 2>/dev/null
    cp "$EXTRACTED_DIR/whatsapp-service/package.json" "$SCRIPT_DIR/whatsapp-service/" 2>/dev/null
    
    # Update shell scripts
    for script in setup.sh start.sh stop.sh status.sh logs.sh fix-whatsapp.sh update.sh; do
        if [ -f "$EXTRACTED_DIR/$script" ]; then
            cp "$EXTRACTED_DIR/$script" "$SCRIPT_DIR/"
            chmod +x "$SCRIPT_DIR/$script"
        fi
    done
    
    # Update README and other root files
    cp "$EXTRACTED_DIR/README.md" "$SCRIPT_DIR/" 2>/dev/null
    
    # Restore .env files
    log "  Restoring configuration..."
    [ -f "/tmp/backend.env.bak" ] && cp "/tmp/backend.env.bak" "$SCRIPT_DIR/backend/.env"
    [ -f "/tmp/frontend.env.bak" ] && cp "/tmp/frontend.env.bak" "$SCRIPT_DIR/frontend/.env"
    
    # Cleanup
    rm -rf "$(dirname "$EXTRACTED_DIR")"
    rm -f /tmp/backend.env.bak /tmp/frontend.env.bak
    
    log "${GREEN}[OK] Files updated${NC}"
}

install_dependencies() {
    log "${BLUE}Checking dependencies...${NC}"
    
    # Check if package.json changed and needs install
    cd "$SCRIPT_DIR/frontend"
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        log "  Installing frontend dependencies..."
        # Use yarn if available, fallback to npm
        if command -v yarn &> /dev/null; then
            yarn install --silent 2>/dev/null
        else
            npm install --legacy-peer-deps --silent 2>/dev/null
        fi
    fi
    
    cd "$SCRIPT_DIR/whatsapp-service" 2>/dev/null
    if [ -d "$SCRIPT_DIR/whatsapp-service" ]; then
        if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
            log "  Installing WhatsApp service dependencies..."
            npm install --silent 2>/dev/null
        fi
    fi
    
    cd "$SCRIPT_DIR/backend"
    # Check for virtual environment or global pip
    if [ -d "venv" ]; then
        source venv/bin/activate
        pip install -q -r requirements.txt 2>/dev/null
        deactivate
    else
        pip install -q -r requirements.txt 2>/dev/null
    fi
    
    log "${GREEN}[OK] Dependencies updated${NC}"
}

restart_services() {
    log "${BLUE}Restarting services...${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Check if running in supervisor environment (Emergent)
    if command -v supervisorctl &> /dev/null && supervisorctl status &> /dev/null; then
        log "  Detected supervisor environment, restarting via supervisorctl..."
        sudo supervisorctl restart backend 2>/dev/null || supervisorctl restart backend 2>/dev/null
        sudo supervisorctl restart frontend 2>/dev/null || supervisorctl restart frontend 2>/dev/null
    else
        # Local development environment
        ./stop.sh > /dev/null 2>&1
        sleep 2
        ./start.sh > /dev/null 2>&1 &
    fi
    
    log "${GREEN}[OK] Services restarted${NC}"
}

save_version() {
    REMOTE_SHA=$(get_remote_version)
    echo "$REMOTE_SHA" > "$VERSION_FILE"
    log "${GREEN}[OK] Version saved: ${REMOTE_SHA:0:7}${NC}"
}

# ============================================================================
#  Main
# ============================================================================

case "${1:-check}" in
    check)
        echo ""
        echo -e "${BLUE}============================================================================${NC}"
        echo -e "${BLUE}       WA Scheduler - Update Check${NC}"
        echo -e "${BLUE}============================================================================${NC}"
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
        echo -e "${BLUE}============================================================================${NC}"
        echo -e "${BLUE}       WA Scheduler - Installing Update${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        echo ""
        
        check_update
        if [ $? -eq 1 ]; then
            echo ""
            exit 0
        fi
        
        EXTRACTED=$(download_update)
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        apply_update "$EXTRACTED"
        install_dependencies
        save_version
        
        echo ""
        echo -e "${YELLOW}Restart services to apply changes?${NC}"
        read -p "  (y/n): " RESTART
        if [[ "$RESTART" =~ ^[Yy]$ ]]; then
            restart_services
        fi
        
        echo ""
        echo -e "${GREEN}============================================================================${NC}"
        echo -e "${GREEN}       Update Complete!${NC}"
        echo -e "${GREEN}============================================================================${NC}"
        echo ""
        ;;
        
    force)
        echo ""
        log "${YELLOW}Force updating...${NC}"
        
        EXTRACTED=$(download_update)
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        apply_update "$EXTRACTED"
        install_dependencies
        save_version
        restart_services
        
        echo ""
        echo -e "${GREEN}Force update complete!${NC}"
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
        echo "  force    - Force update and restart"
        echo "  version  - Show version info"
        echo ""
        ;;
esac
