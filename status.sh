#!/bin/bash
# ============================================================================
#  WhatsApp Scheduler - Service Status (Ubuntu/WSL)
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ports
FRONTEND_PORT=3000
BACKEND_PORT=8001
WHATSAPP_PORT=3001
MONGO_PORT=27017

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}       WhatsApp Scheduler - Service Status${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# ============================================================================
# CHECK SERVICES
# ============================================================================

echo "  Service                Port        Status"
echo "  ---------------------------------------------------------------------------"

# WhatsApp Service
if curl -s http://localhost:$WHATSAPP_PORT/health > /dev/null 2>&1; then
    WA_STATUS=$(curl -s http://localhost:$WHATSAPP_PORT/status 2>/dev/null)
    IS_READY=$(echo $WA_STATUS | grep -o '"isReady":true' || echo "")
    if [ -n "$IS_READY" ]; then
        echo -e "  WhatsApp Service       $WHATSAPP_PORT         ${GREEN}[CONNECTED]${NC}"
    else
        echo -e "  WhatsApp Service       $WHATSAPP_PORT         ${YELLOW}[WAITING FOR QR]${NC}"
    fi
else
    echo -e "  WhatsApp Service       $WHATSAPP_PORT         ${RED}[STOPPED]${NC}"
fi

# Backend
if curl -s http://localhost:$BACKEND_PORT/api/ > /dev/null 2>&1; then
    echo -e "  Backend API            $BACKEND_PORT         ${GREEN}[RUNNING]${NC}"
else
    echo -e "  Backend API            $BACKEND_PORT         ${RED}[STOPPED]${NC}"
fi

# Frontend
if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
    echo -e "  Frontend Dashboard     $FRONTEND_PORT         ${GREEN}[RUNNING]${NC}"
else
    echo -e "  Frontend Dashboard     $FRONTEND_PORT         ${RED}[STOPPED]${NC}"
fi

# MongoDB
if curl -s http://localhost:$MONGO_PORT > /dev/null 2>&1 || pgrep -x "mongod" > /dev/null; then
    echo -e "  MongoDB                $MONGO_PORT        ${GREEN}[RUNNING]${NC}"
else
    echo -e "  MongoDB                $MONGO_PORT        ${YELLOW}[NOT DETECTED]${NC}"
fi

echo "  ---------------------------------------------------------------------------"
echo ""

# ============================================================================
# WHATSAPP DETAILS
# ============================================================================
if curl -s http://localhost:$WHATSAPP_PORT/status > /dev/null 2>&1; then
    echo "  WhatsApp Service Details:"
    echo "  ---------------------------------------------------------------------------"
    WA_STATUS=$(curl -s http://localhost:$WHATSAPP_PORT/status 2>/dev/null)
    
    IS_READY=$(echo $WA_STATUS | grep -o '"isReady":[^,]*' | cut -d: -f2)
    IS_AUTH=$(echo $WA_STATUS | grep -o '"isAuthenticated":[^,]*' | cut -d: -f2)
    HAS_QR=$(echo $WA_STATUS | grep -o '"hasQrCode":[^,]*' | cut -d: -f2)
    IS_INIT=$(echo $WA_STATUS | grep -o '"isInitializing":[^,]*' | cut -d: -f2)
    
    echo "    Ready:         $IS_READY"
    echo "    Authenticated: $IS_AUTH"
    echo "    Has QR Code:   $HAS_QR"
    echo "    Initializing:  $IS_INIT"
    echo "  ---------------------------------------------------------------------------"
    echo ""
fi

# ============================================================================
# SYSTEM RESOURCES
# ============================================================================
echo "  System Resources:"
echo "  ---------------------------------------------------------------------------"
echo "    CPU:    $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')% used"
echo "    Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "    Disk:   $(df -h / | awk 'NR==2{print $5}') used"
echo "  ---------------------------------------------------------------------------"
echo ""

# ============================================================================
# URLS
# ============================================================================
echo "  URLs:"
echo -e "    Dashboard:    ${CYAN}http://localhost:$FRONTEND_PORT${NC}"
echo -e "    Diagnostics:  ${CYAN}http://localhost:$FRONTEND_PORT/diagnostics${NC}"
echo -e "    Connect WA:   ${CYAN}http://localhost:$FRONTEND_PORT/connect${NC}"
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo ""
