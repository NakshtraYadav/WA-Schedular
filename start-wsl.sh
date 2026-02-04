#!/bin/bash
# ============================================================================
#  WA Scheduler - WSL Quick Start
#  Single command to start everything in hot-reload mode
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         WA Scheduler - WSL Quick Start                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Create logs directory
mkdir -p "$SCRIPT_DIR/logs"

# Stop any existing processes
echo "→ Stopping existing processes..."
pkill -f "uvicorn.*server:app" 2>/dev/null
pkill -f "node.*react-scripts" 2>/dev/null
pkill -f "node.*whatsapp-service" 2>/dev/null
sleep 2

# Start MongoDB (if not running)
if ! pgrep -x mongod > /dev/null; then
    echo "→ Starting MongoDB..."
    mongod --fork --logpath "$SCRIPT_DIR/logs/mongodb.log" 2>/dev/null || true
fi

# Start WhatsApp Service
echo "→ Starting WhatsApp Service (port 3001)..."
cd "$SCRIPT_DIR/whatsapp-service"
nohup node index.js > "$SCRIPT_DIR/logs/whatsapp.log" 2>&1 &
echo $! > "$SCRIPT_DIR/.whatsapp.pid"

# Start Backend with HOT RELOAD
echo "→ Starting Backend with HOT RELOAD (port 8001)..."
cd "$SCRIPT_DIR/backend"

# WSL optimization: Use polling for file changes
export WATCHFILES_FORCE_POLLING=true

nohup python3 -m uvicorn server:app \
    --host 0.0.0.0 \
    --port 8001 \
    --reload \
    --reload-dir "$SCRIPT_DIR/backend" \
    > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
echo $! > "$SCRIPT_DIR/.backend.pid"

# Start Frontend with HOT RELOAD  
echo "→ Starting Frontend with HOT RELOAD (port 3000)..."
cd "$SCRIPT_DIR/frontend"

# WSL optimizations
export CHOKIDAR_USEPOLLING=false
export FAST_REFRESH=true
export BROWSER=none
export CI=false

nohup npm start > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
echo $! > "$SCRIPT_DIR/.frontend.pid"

# Wait for services to start
echo ""
echo "→ Waiting for services to start..."
sleep 5

# Check status
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SERVICES STARTED                          ║"
echo "╠══════════════════════════════════════════════════════════════╣"

# Check backend
if curl -s http://localhost:8001/api/ > /dev/null 2>&1; then
    echo "║  ✅ Backend     http://localhost:8001   HOT RELOAD ON       ║"
else
    echo "║  ⏳ Backend     http://localhost:8001   Starting...         ║"
fi

# Check frontend
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "║  ✅ Frontend    http://localhost:3000   HOT RELOAD ON       ║"
else
    echo "║  ⏳ Frontend    http://localhost:3000   Starting...         ║"
fi

# Check whatsapp
if curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo "║  ✅ WhatsApp    http://localhost:3001                       ║"
else
    echo "║  ⏳ WhatsApp    http://localhost:3001   Starting...         ║"
fi

echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  HOT RELOAD ACTIVE - Changes apply in 1-3 seconds!          ║"
echo "║                                                              ║"
echo "║  Update Commands:                                            ║"
echo "║    ./fast-update.sh instant  →  ~500ms update               ║"
echo "║    ./fast-update.sh update   →  ~3-5s update                ║"
echo "║                                                              ║"
echo "║  View Logs:                                                  ║"
echo "║    tail -f logs/backend.log                                 ║"
echo "║    tail -f logs/frontend.log                                ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
