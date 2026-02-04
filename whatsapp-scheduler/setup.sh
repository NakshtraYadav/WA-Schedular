#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Ubuntu/WSL Setup Script
#  Installs everything from scratch on a fresh Ubuntu/WSL installation
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs/system"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SETUP_LOG="$LOG_DIR/setup_$TIMESTAMP.log"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$SCRIPT_DIR/logs/backend"
mkdir -p "$SCRIPT_DIR/logs/frontend"
mkdir -p "$SCRIPT_DIR/logs/whatsapp"

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}       WhatsApp Scheduler - Ubuntu/WSL Setup${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  This script will install and configure:"
echo "    - Node.js 20.x LTS"
echo "    - Python 3 + pip + venv"
echo "    - Chromium browser (for WhatsApp automation)"
echo "    - MongoDB (local or you can use Atlas)"
echo "    - All project dependencies"
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Log start
echo "[$(date)] Setup started" > "$SETUP_LOG"
echo "[$(date)] Directory: $SCRIPT_DIR" >> "$SETUP_LOG"

# ============================================================================
# SYSTEM UPDATE
# ============================================================================
echo -e "${YELLOW}[1/8]${NC} Updating system packages..."
sudo apt update -y >> "$SETUP_LOG" 2>&1
echo -e "${GREEN}[OK]${NC} System updated"

# ============================================================================
# INSTALL NODE.JS
# ============================================================================
echo -e "${YELLOW}[2/8]${NC} Checking Node.js..."

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}[OK]${NC} Node.js already installed: $NODE_VERSION"
else
    echo "  Installing Node.js 20.x LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - >> "$SETUP_LOG" 2>&1
    sudo apt install -y nodejs >> "$SETUP_LOG" 2>&1
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}[OK]${NC} Node.js installed: $NODE_VERSION"
fi

# Verify npm
NPM_VERSION=$(npm -v)
echo -e "${GREEN}[OK]${NC} npm version: $NPM_VERSION"

# ============================================================================
# INSTALL PYTHON
# ============================================================================
echo -e "${YELLOW}[3/8]${NC} Checking Python..."

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}[OK]${NC} $PYTHON_VERSION"
else
    echo "  Installing Python 3..."
    sudo apt install -y python3 python3-pip python3-venv >> "$SETUP_LOG" 2>&1
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}[OK]${NC} $PYTHON_VERSION installed"
fi

# Ensure pip and venv are available
sudo apt install -y python3-pip python3-venv >> "$SETUP_LOG" 2>&1
echo -e "${GREEN}[OK]${NC} pip and venv available"

# ============================================================================
# INSTALL CHROMIUM
# ============================================================================
echo -e "${YELLOW}[4/8]${NC} Checking Chromium browser..."

if command -v chromium-browser &> /dev/null || command -v chromium &> /dev/null; then
    echo -e "${GREEN}[OK]${NC} Chromium already installed"
else
    echo "  Installing Chromium browser..."
    sudo apt install -y chromium-browser >> "$SETUP_LOG" 2>&1 || \
    sudo apt install -y chromium >> "$SETUP_LOG" 2>&1 || \
    echo -e "${YELLOW}[!]${NC} Chromium install failed - puppeteer will download its own"
fi

# Install additional dependencies for puppeteer
echo "  Installing puppeteer dependencies..."
sudo apt install -y \
    ca-certificates \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    libxshmfence1 \
    libglu1-mesa \
    >> "$SETUP_LOG" 2>&1 || true

echo -e "${GREEN}[OK]${NC} Browser dependencies installed"

# ============================================================================
# INSTALL MONGODB (Optional - can use Atlas)
# ============================================================================
echo -e "${YELLOW}[5/8]${NC} Checking MongoDB..."

if command -v mongod &> /dev/null; then
    echo -e "${GREEN}[OK]${NC} MongoDB already installed"
elif systemctl list-units --type=service | grep -q mongod; then
    echo -e "${GREEN}[OK]${NC} MongoDB service found"
else
    echo "  Do you want to install MongoDB locally? (y/n)"
    echo "  (You can skip and use MongoDB Atlas cloud instead)"
    read -r INSTALL_MONGO
    
    if [[ "$INSTALL_MONGO" =~ ^[Yy]$ ]]; then
        echo "  Installing MongoDB..."
        # Import MongoDB GPG key
        curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
            sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor >> "$SETUP_LOG" 2>&1
        
        # Add MongoDB repo
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
            sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >> "$SETUP_LOG" 2>&1
        
        sudo apt update >> "$SETUP_LOG" 2>&1
        sudo apt install -y mongodb-org >> "$SETUP_LOG" 2>&1
        
        # Start MongoDB
        sudo systemctl start mongod >> "$SETUP_LOG" 2>&1 || true
        sudo systemctl enable mongod >> "$SETUP_LOG" 2>&1 || true
        
        echo -e "${GREEN}[OK]${NC} MongoDB installed and started"
    else
        echo -e "${YELLOW}[!]${NC} Skipping MongoDB - update backend/.env with your Atlas URL"
    fi
fi

# ============================================================================
# SETUP BACKEND
# ============================================================================
echo -e "${YELLOW}[6/8]${NC} Setting up Python backend..."

cd "$SCRIPT_DIR/backend"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "  Creating virtual environment..."
    python3 -m venv venv
fi

# Activate and install dependencies
source venv/bin/activate
pip install --upgrade pip >> "$SETUP_LOG" 2>&1
pip install -r requirements.txt >> "$SETUP_LOG" 2>&1
deactivate

# Create .env if not exists
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
HOST=0.0.0.0
PORT=8001
EOF
    echo -e "${GREEN}[OK]${NC} Created backend/.env"
else
    echo -e "${GREEN}[OK]${NC} backend/.env exists"
fi

echo -e "${GREEN}[OK]${NC} Backend setup complete"

# ============================================================================
# SETUP WHATSAPP SERVICE
# ============================================================================
echo -e "${YELLOW}[7/8]${NC} Setting up WhatsApp service..."
echo "  This downloads ~200MB (puppeteer + chromium)"
echo ""

cd "$SCRIPT_DIR/whatsapp-service"

# Clean install
rm -rf node_modules package-lock.json yarn.lock 2>/dev/null || true

# Install with progress
echo "  Running npm install (watch progress below):"
echo "  ---------------------------------------------------------------------------"
npm install --progress
echo "  ---------------------------------------------------------------------------"

if [ -d "node_modules/whatsapp-web.js" ]; then
    echo -e "${GREEN}[OK]${NC} WhatsApp service dependencies installed"
else
    echo -e "${RED}[!!]${NC} WhatsApp dependencies failed - try running: cd whatsapp-service && npm install"
fi

# ============================================================================
# SETUP FRONTEND
# ============================================================================
echo -e "${YELLOW}[8/8]${NC} Setting up React frontend..."
echo "  This may take a few minutes..."

cd "$SCRIPT_DIR/frontend"

# Create .env if not exists
if [ ! -f ".env" ]; then
    echo "REACT_APP_BACKEND_URL=http://localhost:8001" > .env
    echo -e "${GREEN}[OK]${NC} Created frontend/.env"
fi

# Install dependencies
npm install --legacy-peer-deps >> "$SETUP_LOG" 2>&1

echo -e "${GREEN}[OK]${NC} Frontend setup complete"

# ============================================================================
# MAKE SCRIPTS EXECUTABLE
# ============================================================================
cd "$SCRIPT_DIR"
chmod +x *.sh 2>/dev/null || true

# ============================================================================
# SETUP COMPLETE
# ============================================================================
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}                    SETUP COMPLETE!${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "  To start all services, run:"
echo ""
echo -e "    ${GREEN}./start.sh${NC}"
echo ""
echo "  Then open in your browser:"
echo ""
echo "    Dashboard:    http://localhost:3000"
echo "    Diagnostics:  http://localhost:3000/diagnostics"
echo "    WhatsApp:     http://localhost:3000/connect"
echo ""
echo "  To stop all services:"
echo ""
echo -e "    ${YELLOW}./stop.sh${NC}"
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo ""

echo "[$(date)] Setup completed successfully" >> "$SETUP_LOG"
