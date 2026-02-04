# WhatsApp Scheduler - Windows Hardening PRD

## Original Problem Statement
Harden, fix, and fully automate a WhatsApp Scheduler project to run flawlessly on Windows 10/11 with zero manual intervention. Create production-grade automation with self-healing, health checks, and bulletproof error handling.

## Architecture
- **Frontend**: React (port 3000)
- **Backend**: FastAPI/Python (port 8001)
- **WhatsApp Service**: Node.js with whatsapp-web.js (port 3001)
- **Database**: MongoDB (port 27017)

## What's Been Implemented

### December 2025 - Latest Updates

#### 1. WhatsApp Service Fix (P0 Complete) ✅
**Issue:** WhatsApp service was failing with outdated dependencies

**Solution:** Updated to latest stable version:
- **`whatsapp-web.js@1.34.6`** (latest stable)
- Removed explicit puppeteer dependency (now bundled automatically)
- Updated index.js with official v1.34.x patterns
- Better error handling and logging

**Files Changed:**
- `/whatsapp-service/package.json` - Updated to v3.0.0
- `/whatsapp-service/index.js` - Complete rewrite
- `/scripts/reinstall-whatsapp.bat` - Updated for v1.34.6

#### 2. Web-Based Diagnostics Dashboard (NEW) ✅
**Feature:** Real-time monitoring without multiple command windows

**Backend Endpoints Added:**
- `GET /api/diagnostics` - Full system diagnostics (CPU, memory, service status)
- `GET /api/diagnostics/logs/{service}` - Read logs for backend/frontend/whatsapp/system
- `GET /api/diagnostics/logs` - Get summary of all log files
- `POST /api/diagnostics/clear-logs/{service}` - Clear logs
- `POST /api/whatsapp/retry` - Retry WhatsApp initialization
- `POST /api/whatsapp/clear-session` - Clear session and restart
- `GET /api/whatsapp/test-browser` - Test browser launch

**Frontend Page:**
- `/diagnostics` - New diagnostics page with:
  - Real-time service status cards (WhatsApp, Backend, MongoDB)
  - System metrics (CPU, Memory, Platform)
  - Live log viewer for all services
  - WhatsApp actions (Retry, Clear Session, Test Browser)
  - Log management (view, clear)
  - Auto-refresh toggle

**Files Created:**
- `/frontend/src/pages/Diagnostics.jsx` - Diagnostics dashboard
- `/launch.bat` - Silent background launcher

**Files Modified:**
- `/frontend/src/App.js` - Added Diagnostics route
- `/frontend/src/lib/api.js` - Added diagnostic API functions
- `/backend/server.py` - Added diagnostic endpoints
- `/backend/requirements.txt` - Added psutil

#### 3. Single-Window Background Launcher (NEW) ✅
**Feature:** Run all services in background without extra windows

**New Script:** `launch.bat`
- Uses PowerShell `Start-Process -WindowStyle Hidden` 
- All services run silently in background
- Logs saved to `logs/` directory
- Opens dashboard automatically
- No more multiple command windows!

**Modified:** `stop.bat`
- Added handling for react-scripts processes
- Added pythonw.exe cleanup for background processes

#### 4. Windows 11 Compatibility Fix ✅
**Issue:** `wmic` command not recognized (deprecated in Windows 11)

**Solution:** Replaced all WMIC commands with PowerShell equivalents:
- Timestamp generation: `powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`
- Process lookup: `powershell -Command "Get-Process node | Where-Object {...}"`

**Files Updated:**
- `setup.bat` - PowerShell timestamp
- `start.bat` - PowerShell timestamp  
- `stop.bat` - PowerShell timestamp + process lookup
- `launch.bat` - PowerShell timestamp
- `scripts/diagnose.bat` - PowerShell timestamp
- `scripts/fix-whatsapp.bat` - PowerShell process lookup

#### 5. NPM Progress Indicator Fix ✅
**Issue:** Setup appeared stuck with no feedback during 200MB download

**Solution:** Removed output suppression and added `--progress` flag:
- `setup.bat` - Shows npm install progress
- `scripts/reinstall-whatsapp.bat` - Shows npm install progress

### Directory Structure:
```
whatsapp-scheduler/
├── backend/           # FastAPI Python backend
├── frontend/          # React frontend with Diagnostics page
├── whatsapp-service/  # Node.js WhatsApp service (v3.0.0)
├── logs/
│   ├── backend/       # Backend API logs
│   ├── frontend/      # React compilation logs
│   ├── whatsapp/      # WhatsApp service logs
│   └── system/        # Setup/stop/start logs
├── scripts/           # Utility scripts
├── launch.bat         # ⭐ NEW: Silent background launcher
├── setup.bat          # One-command setup
├── start.bat          # Traditional start (with windows)
├── stop.bat           # Stop all services
└── restart.bat        # Restart services
```

## How to Use

### Option 1: Silent Background Mode (Recommended)
```batch
launch.bat
```
- All services start in background
- No extra command windows
- Monitor via http://localhost:3000/diagnostics

### Option 2: Traditional Mode (with windows)
```batch
start.bat
```
- Services start in separate windows
- Built-in watchdog monitoring

### Stopping Services
```batch
stop.bat
```

## Key Features
- ✅ Zero manual intervention required
- ✅ Single-window operation (launch.bat)
- ✅ Web-based diagnostics dashboard
- ✅ Real-time log viewing
- ✅ Self-healing with auto-restart
- ✅ Structured, timestamped logging
- ✅ Windows 10/11 optimized
- ✅ Latest whatsapp-web.js@1.34.6

## Next Steps / Backlog

### P0 (Completed)
- ✅ Fix WhatsApp service with correct dependencies
- ✅ Web-based diagnostics dashboard
- ✅ Single-window launcher

### P1 (User Testing Required)
- Test launch.bat on Windows
- Verify QR code generation and WhatsApp connection
- Test full workflow: setup → launch → connect → send message

### P2 (Future)
- Add email/Telegram notifications for critical failures
- Windows service wrapper for auto-start on boot
- Backup/restore for MongoDB data
- Remove/fix PowerShell scripts (.ps1 files)
