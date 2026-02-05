#!/bin/bash
# =============================================================================
#  WA Scheduler - Bulletproof Setup Script
#  
#  This script handles EVERYTHING needed to set up the application:
#  - Detects and installs missing dependencies (Node.js, Python, MongoDB)
#  - Works on Ubuntu/Debian, CentOS/RHEL, macOS, and WSL
#  - Handles permission issues gracefully
#  - Creates virtual environments
#  - Installs all packages
#  - Sets up the database
#  - Configures environment files
#
#  Usage:
#    chmod +x setup.sh && ./setup.sh
#
#  Requirements:
#    - Sudo access (for system packages)
#    - Internet connection
#    - 4GB+ RAM recommended
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/setup.log"

# Minimum versions
MIN_NODE_VERSION=18
MIN_PYTHON_VERSION="3.9"
MIN_NPM_VERSION=8

# Track what was installed
INSTALLED_NODE=false
INSTALLED_PYTHON=false
INSTALLED_MONGO=false
INSTALLED_CHROME=false

# =============================================================================
# LOGGING
# =============================================================================
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    log "=== $1 ==="
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
    log "STEP: $1"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    log "INFO: $1"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
command_exists() {
    command -v "$1" &> /dev/null
}

version_gte() {
    # Compare versions: returns 0 if $1 >= $2
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

get_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "$ID"
        elif [ -f /etc/redhat-release ]; then
            echo "rhel"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || [ -n "$WSL_DISTRO_NAME" ]
}

has_sudo() {
    if command_exists sudo; then
        sudo -n true 2>/dev/null
        return $?
    fi
    return 1
}

run_sudo() {
    if has_sudo; then
        sudo "$@"
    else
        print_warning "sudo not available, trying without..."
        "$@"
    fi
}

# =============================================================================
# DEPENDENCY CHECKS
# =============================================================================
check_node() {
    print_step "Checking Node.js..."
    
    if command_exists node; then
        local node_version=$(node -v | sed 's/v//' | cut -d. -f1)
        if [ "$node_version" -ge "$MIN_NODE_VERSION" ]; then
            print_success "Node.js v$(node -v | sed 's/v//') installed"
            return 0
        else
            print_warning "Node.js $(node -v) is too old (need v$MIN_NODE_VERSION+)"
            return 1
        fi
    else
        print_warning "Node.js not found"
        return 1
    fi
}

check_npm() {
    print_step "Checking npm..."
    
    if command_exists npm; then
        local npm_version=$(npm -v | cut -d. -f1)
        if [ "$npm_version" -ge "$MIN_NPM_VERSION" ]; then
            print_success "npm v$(npm -v) installed"
            return 0
        else
            print_warning "npm $(npm -v) is too old"
            return 1
        fi
    else
        print_warning "npm not found"
        return 1
    fi
}

check_python() {
    print_step "Checking Python..."
    
    # Try python3 first, then python
    local python_cmd=""
    if command_exists python3; then
        python_cmd="python3"
    elif command_exists python; then
        python_cmd="python"
    fi
    
    if [ -n "$python_cmd" ]; then
        local python_version=$($python_cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
        if version_gte "$python_version" "$MIN_PYTHON_VERSION"; then
            print_success "Python $python_version installed"
            return 0
        else
            print_warning "Python $python_version is too old (need $MIN_PYTHON_VERSION+)"
            return 1
        fi
    else
        print_warning "Python not found"
        return 1
    fi
}

check_mongodb() {
    print_step "Checking MongoDB..."
    
    # Check if mongod is running or can connect
    if command_exists mongosh; then
        if mongosh --eval "db.version()" --quiet 2>/dev/null; then
            print_success "MongoDB is running"
            return 0
        fi
    elif command_exists mongo; then
        if mongo --eval "db.version()" --quiet 2>/dev/null; then
            print_success "MongoDB is running"
            return 0
        fi
    fi
    
    # Check if service exists
    if command_exists systemctl; then
        if systemctl is-active --quiet mongod 2>/dev/null; then
            print_success "MongoDB service is active"
            return 0
        fi
    fi
    
    # Check Docker
    if command_exists docker; then
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q mongo; then
            print_success "MongoDB running in Docker"
            return 0
        fi
    fi
    
    print_warning "MongoDB not detected"
    return 1
}

check_chromium() {
    print_step "Checking Chromium/Chrome..."
    
    local browsers=(
        "/usr/bin/chromium-browser"
        "/usr/bin/chromium"
        "/usr/bin/google-chrome"
        "/usr/bin/google-chrome-stable"
        "/snap/bin/chromium"
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    )
    
    for browser in "${browsers[@]}"; do
        if [ -x "$browser" ]; then
            print_success "Found: $browser"
            return 0
        fi
    done
    
    if command_exists chromium-browser || command_exists chromium || command_exists google-chrome; then
        print_success "Browser found in PATH"
        return 0
    fi
    
    print_warning "No Chromium/Chrome found"
    return 1
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================
install_node() {
    print_step "Installing Node.js v$MIN_NODE_VERSION..."
    
    local os=$(get_os)
    
    case "$os" in
        ubuntu|debian|pop)
            # Use NodeSource repository (includes npm)
            print_info "Adding NodeSource repository..."
            curl -fsSL https://deb.nodesource.com/setup_${MIN_NODE_VERSION}.x | run_sudo bash -
            run_sudo apt-get install -y nodejs
            
            # Refresh PATH and hash table
            hash -r 2>/dev/null || true
            export PATH="/usr/bin:$PATH"
            ;;
        
        fedora|rhel|centos|rocky|alma)
            curl -fsSL https://rpm.nodesource.com/setup_${MIN_NODE_VERSION}.x | run_sudo bash -
            run_sudo dnf install -y nodejs || run_sudo yum install -y nodejs
            hash -r 2>/dev/null || true
            ;;
        
        macos)
            if command_exists brew; then
                brew install node@$MIN_NODE_VERSION
                brew link node@$MIN_NODE_VERSION --force --overwrite
            else
                print_error "Please install Homebrew first: https://brew.sh"
                exit 1
            fi
            ;;
        
        *)
            # Fallback: use nvm
            print_info "Using nvm to install Node.js..."
            export NVM_DIR="$HOME/.nvm"
            mkdir -p "$NVM_DIR"
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            
            # Source nvm
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
            
            nvm install $MIN_NODE_VERSION
            nvm use $MIN_NODE_VERSION
            nvm alias default $MIN_NODE_VERSION
            
            # Add to profile for persistence
            if [ -f "$HOME/.bashrc" ]; then
                echo 'export NVM_DIR="$HOME/.nvm"' >> "$HOME/.bashrc"
                echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$HOME/.bashrc"
            fi
            ;;
    esac
    
    # Wait a moment for installation to settle
    sleep 1
    
    # Refresh command cache
    hash -r 2>/dev/null || true
    
    # Try multiple ways to find node
    local node_path=""
    if command_exists node; then
        node_path="node"
    elif [ -x "/usr/bin/node" ]; then
        node_path="/usr/bin/node"
        export PATH="/usr/bin:$PATH"
    elif [ -x "/usr/local/bin/node" ]; then
        node_path="/usr/local/bin/node"
        export PATH="/usr/local/bin:$PATH"
    elif [ -n "$NVM_DIR" ] && [ -x "$NVM_DIR/versions/node/v${MIN_NODE_VERSION}."*/bin/node ]; then
        # NVM installation
        local nvm_node=$(ls -d "$NVM_DIR/versions/node/v${MIN_NODE_VERSION}."*/bin 2>/dev/null | head -1)
        if [ -n "$nvm_node" ]; then
            export PATH="$nvm_node:$PATH"
            node_path="node"
        fi
    fi
    
    # Verify installation
    if [ -n "$node_path" ] && $node_path -v &>/dev/null; then
        print_success "Node.js $($node_path -v) installed"
        INSTALLED_NODE=true
    else
        print_error "Node.js installation failed"
        print_info "Please install Node.js manually: https://nodejs.org/"
        print_info "Or try: curl -fsSL https://deb.nodesource.com/setup_${MIN_NODE_VERSION}.x | sudo bash - && sudo apt-get install -y nodejs"
        exit 1
    fi
}

install_python() {
    print_step "Installing Python 3.9+..."
    
    local os=$(get_os)
    
    case "$os" in
        ubuntu|debian|pop)
            run_sudo apt-get update
            run_sudo apt-get install -y python3 python3-pip python3-venv python3-dev
            ;;
        
        fedora|rhel|centos|rocky|alma)
            run_sudo dnf install -y python3 python3-pip python3-devel || \
            run_sudo yum install -y python3 python3-pip python3-devel
            ;;
        
        macos)
            if command_exists brew; then
                brew install python@3.11
            else
                print_error "Please install Homebrew first: https://brew.sh"
                exit 1
            fi
            ;;
        
        *)
            print_error "Unknown OS - please install Python 3.9+ manually"
            exit 1
            ;;
    esac
    
    if command_exists python3; then
        print_success "Python $(python3 --version) installed"
        INSTALLED_PYTHON=true
    else
        print_error "Python installation failed"
        exit 1
    fi
}

install_mongodb() {
    print_step "Installing MongoDB..."
    
    local os=$(get_os)
    
    case "$os" in
        ubuntu|debian|pop)
            # Import MongoDB GPG key
            curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
                run_sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
            
            # Add repository
            echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | \
                run_sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
            
            run_sudo apt-get update
            run_sudo apt-get install -y mongodb-org
            run_sudo systemctl start mongod
            run_sudo systemctl enable mongod
            ;;
        
        fedora|rhel|centos|rocky|alma)
            cat << 'EOF' | run_sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF
            run_sudo dnf install -y mongodb-org || run_sudo yum install -y mongodb-org
            run_sudo systemctl start mongod
            run_sudo systemctl enable mongod
            ;;
        
        macos)
            if command_exists brew; then
                brew tap mongodb/brew
                brew install mongodb-community
                brew services start mongodb-community
            fi
            ;;
        
        *)
            print_warning "Please install MongoDB manually or use Docker:"
            print_info "docker run -d -p 27017:27017 --name mongodb mongo:7"
            return 1
            ;;
    esac
    
    # Wait for MongoDB to start
    sleep 3
    
    if check_mongodb; then
        INSTALLED_MONGO=true
    else
        print_warning "MongoDB installed but not running - trying Docker..."
        if command_exists docker; then
            docker run -d -p 27017:27017 --name wa-mongodb mongo:7
            sleep 3
            INSTALLED_MONGO=true
        fi
    fi
}

install_chromium() {
    print_step "Installing Chromium..."
    
    local os=$(get_os)
    
    case "$os" in
        ubuntu|debian|pop)
            run_sudo apt-get update
            run_sudo apt-get install -y chromium-browser || run_sudo apt-get install -y chromium
            ;;
        
        fedora|rhel|centos|rocky|alma)
            run_sudo dnf install -y chromium || run_sudo yum install -y chromium
            ;;
        
        macos)
            if command_exists brew; then
                brew install --cask chromium
            fi
            ;;
        
        *)
            print_warning "Please install Chromium manually"
            ;;
    esac
    
    INSTALLED_CHROME=true
}

install_build_tools() {
    print_step "Installing build tools..."
    
    local os=$(get_os)
    
    case "$os" in
        ubuntu|debian|pop)
            run_sudo apt-get update
            run_sudo apt-get install -y build-essential git curl wget
            ;;
        
        fedora|rhel|centos|rocky|alma)
            run_sudo dnf groupinstall -y "Development Tools" || \
            run_sudo yum groupinstall -y "Development Tools"
            run_sudo dnf install -y git curl wget || \
            run_sudo yum install -y git curl wget
            ;;
        
        macos)
            xcode-select --install 2>/dev/null || true
            ;;
    esac
    
    print_success "Build tools ready"
}

# =============================================================================
# SETUP FUNCTIONS
# =============================================================================
setup_backend() {
    print_header "Setting Up Backend"
    
    cd "$SCRIPT_DIR/backend"
    
    # Create virtual environment
    print_step "Creating Python virtual environment..."
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    print_success "Virtual environment ready"
    
    # Activate and install
    print_step "Installing Python packages..."
    source venv/bin/activate
    pip install --upgrade pip --quiet
    pip install -r requirements.txt --quiet
    deactivate
    print_success "Python packages installed"
    
    # Create .env if not exists
    if [ ! -f ".env" ]; then
        print_step "Creating backend .env file..."
        cat > .env << EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
EOF
        print_success "Backend .env created"
    else
        print_info "Backend .env already exists"
    fi
    
    cd "$SCRIPT_DIR"
}

setup_frontend() {
    print_header "Setting Up Frontend"
    
    cd "$SCRIPT_DIR/frontend"
    
    print_step "Installing npm packages (this may take a few minutes)..."
    npm install --legacy-peer-deps 2>/dev/null || npm install 2>/dev/null
    print_success "Frontend packages installed"
    
    # Create .env if not exists
    if [ ! -f ".env" ]; then
        print_step "Creating frontend .env file..."
        cat > .env << EOF
REACT_APP_BACKEND_URL=http://localhost:8001
PORT=3000
BROWSER=none
EOF
        print_success "Frontend .env created"
    else
        print_info "Frontend .env already exists"
    fi
    
    cd "$SCRIPT_DIR"
}

setup_whatsapp_service() {
    print_header "Setting Up WhatsApp Service"
    
    cd "$SCRIPT_DIR/whatsapp-service"
    
    print_step "Installing npm packages..."
    npm install 2>/dev/null
    print_success "WhatsApp service packages installed"
    
    # Create data directories
    mkdir -p data/whatsapp-sessions
    mkdir -p data/session-backups
    
    # Create .env if not exists
    if [ ! -f ".env" ]; then
        print_step "Creating whatsapp-service .env file..."
        cat > .env << EOF
PORT=3001
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
SESSION_CLIENT_ID=wa-scheduler
EOF
        print_success "WhatsApp service .env created"
    else
        print_info "WhatsApp service .env already exists"
    fi
    
    cd "$SCRIPT_DIR"
}

create_directories() {
    print_step "Creating required directories..."
    
    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$SCRIPT_DIR/data"
    mkdir -p "$SCRIPT_DIR/.snapshots"
    
    print_success "Directories created"
}

# =============================================================================
# MAIN SETUP
# =============================================================================
main() {
    # Initialize log
    echo "Setup started at $(date)" > "$LOG_FILE"
    
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}║    ${BOLD}${CYAN}WA Scheduler - Bulletproof Setup${NC}${MAGENTA}                        ║${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}║    This will install all required dependencies               ║${NC}"
    echo -e "${MAGENTA}║    and configure your system automatically.                  ║${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Detect OS
    local os=$(get_os)
    print_info "Detected OS: $os"
    
    if is_wsl; then
        print_info "Running in WSL environment"
    fi
    
    # Check/Install dependencies
    print_header "Checking Dependencies"
    
    # Build tools
    install_build_tools
    
    # Node.js
    if ! check_node; then
        install_node
    fi
    
    # Verify npm is available (should come with Node from NodeSource)
    # Give it a moment and refresh PATH
    sleep 1
    hash -r 2>/dev/null || true
    
    if ! check_npm; then
        print_warning "npm not immediately available, checking alternative paths..."
        
        # Try to find npm in common locations
        local npm_found=false
        for npm_path in "/usr/bin/npm" "/usr/local/bin/npm" "$HOME/.nvm/versions/node/"*/bin/npm; do
            if [ -x "$npm_path" ] 2>/dev/null; then
                local npm_dir=$(dirname "$npm_path")
                export PATH="$npm_dir:$PATH"
                hash -r 2>/dev/null || true
                print_info "Found npm at: $npm_path"
                npm_found=true
                break
            fi
        done
        
        if ! $npm_found && ! check_npm; then
            print_warning "npm still not found, attempting reinstall..."
            local os=$(get_os)
            case "$os" in
                ubuntu|debian|pop)
                    # Don't install npm separately - it causes conflicts
                    # Instead, reinstall nodejs which includes npm
                    print_info "Reinstalling nodejs package..."
                    run_sudo apt-get install -y --reinstall nodejs
                    hash -r 2>/dev/null || true
                    ;;
                fedora|rhel|centos|rocky|alma)
                    run_sudo dnf reinstall -y nodejs || run_sudo yum reinstall -y nodejs
                    hash -r 2>/dev/null || true
                    ;;
                *)
                    # For other systems, try installing npm globally via node
                    if command_exists node; then
                        print_info "Node exists but npm missing - unusual state"
                    fi
                    ;;
            esac
            
            # Final check
            sleep 1
            if ! check_npm; then
                print_error "npm installation failed"
                print_info ""
                print_info "Please install Node.js manually which includes npm:"
                print_info "  1. Visit https://nodejs.org/"
                print_info "  2. Download and install the LTS version"
                print_info "  3. Run this setup script again"
                print_info ""
                print_info "Or try running these commands manually:"
                print_info "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -"
                print_info "  sudo apt-get install -y nodejs"
                exit 1
            fi
        fi
    fi
    
    print_success "npm $(npm -v) is ready"
    
    # Python
    if ! check_python; then
        install_python
    fi
    
    # MongoDB
    if ! check_mongodb; then
        print_info "MongoDB not running - attempting to install/start..."
        install_mongodb
        if ! check_mongodb; then
            print_warning "MongoDB not available - you can set it up later"
            print_info "The app will work once MongoDB is available at localhost:27017"
        fi
    fi
    
    # Chromium (for WhatsApp)
    if ! check_chromium; then
        install_chromium
    fi
    
    # Setup components
    create_directories
    setup_backend
    setup_frontend
    setup_whatsapp_service
    
    # Make scripts executable
    print_step "Making scripts executable..."
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR"/scripts/*.sh 2>/dev/null || true
    print_success "Scripts are executable"
    
    # Summary
    print_header "Setup Complete!"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     SETUP SUCCESSFUL!                         ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║  ${NC}Node.js:  $(node -v 2>/dev/null || echo 'Not installed')                                        ${GREEN}║${NC}"
    echo -e "${GREEN}║  ${NC}npm:      v$(npm -v 2>/dev/null || echo 'Not installed')                                        ${GREEN}║${NC}"
    echo -e "${GREEN}║  ${NC}Python:   $(python3 --version 2>/dev/null || echo 'Not installed')                              ${GREEN}║${NC}"
    echo -e "${GREEN}║  ${NC}MongoDB:  $(check_mongodb && echo 'Running ✓' || echo 'Not running')                           ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║  ${CYAN}To start the application:${NC}                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║    ${YELLOW}./start.sh${NC}                                                ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║  ${CYAN}Then open in browser:${NC}                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║    ${YELLOW}http://localhost:3000${NC}                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Log what was installed
    if $INSTALLED_NODE; then
        print_info "Installed: Node.js"
    fi
    if $INSTALLED_PYTHON; then
        print_info "Installed: Python"
    fi
    if $INSTALLED_MONGO; then
        print_info "Installed: MongoDB"
    fi
    if $INSTALLED_CHROME; then
        print_info "Installed: Chromium"
    fi
    
    print_info "Setup log saved to: $LOG_FILE"
}

# Run main
main "$@"
