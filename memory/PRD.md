# WhatsApp Scheduler - Windows Hardening PRD

## Original Problem Statement
Harden, fix, and fully automate a WhatsApp Scheduler project to run flawlessly on Windows 10/11 with zero manual intervention. Create production-grade automation with self-healing, health checks, and bulletproof error handling.

## Architecture
- **Frontend**: React (port 3000)
- **Backend**: FastAPI/Python (port 8001)
- **WhatsApp Service**: Node.js with whatsapp-web.js (port 3001)
- **Database**: MongoDB (port 27017)

## What's Been Implemented (Feb 2026)

### Core Scripts Created:
1. **setup.bat** - Production setup with:
   - Auto-detect Node.js, Python, MongoDB
   - Dependency installation with retry logic
   - Environment file auto-creation
   - Port validation and cleanup
   - Task Scheduler integration (optional)

2. **start.bat** - Production start with:
   - Sequential service startup (MongoDB → WhatsApp → Backend → Frontend)
   - Health checks with retry logic
   - Dashboard status display
   - Built-in watchdog monitoring
   - Browser auto-launch

3. **stop.bat** - Graceful shutdown with:
   - Process termination by window title
   - Port cleanup
   - Orphan process detection
   - Verification of clean shutdown

4. **restart.bat** - Clean restart with port verification

5. **health-check.bat** - Full diagnostics with:
   - Service status checks
   - System resource monitoring (memory, CPU, disk)
   - Log file status
   - Auto-repair option

6. **watchdog.bat** - Self-healing monitor with:
   - 30-second health checks
   - Auto-restart after 3 consecutive failures
   - Resource monitoring
   - Comprehensive logging

### Utility Scripts (scripts/ folder):
- **install-task.bat** - Windows Task Scheduler auto-start
- **uninstall-task.bat** - Remove auto-start
- **rotate-logs.bat** - Log cleanup (7-day retention)
- **diagnose.bat** - Full diagnostic report generator
- **reset-whatsapp-session.bat** - WhatsApp re-authentication

### PowerShell Scripts:
- **setup.ps1** - Advanced setup with error handling
- **watchdog.ps1** - Advanced watchdog with metrics

### Directory Structure:
```
logs/
├── backend/    # Timestamped API logs
├── frontend/   # Timestamped React logs
├── whatsapp/   # Timestamped WA service logs
└── system/     # Setup/watchdog/diagnostic logs
```

## Key Features
- Zero manual intervention required
- Self-healing with auto-restart
- Structured, timestamped logging
- Windows 10/11 optimized (PowerShell 5.1)
- Port conflict resolution
- MongoDB service detection and auto-start
- Dependency version locking

## Next Steps / Backlog
- P1: Add email notification for critical failures
- P1: Implement log rotation in watchdog
- P2: Add Prometheus metrics endpoint
- P2: Create Windows service wrapper
- P3: Add backup/restore for MongoDB data
