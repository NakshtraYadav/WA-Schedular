# WhatsApp Scheduler - Product Requirements Document

## Original Problem Statement
1. Add feature to manually run scheduled messages
2. Scheduled messages don't go (not working)
3. WhatsApp connection terminates permanently after ./stop.sh and ./start.sh even though session is being cached

## Architecture Overview
- **Frontend**: React.js (port 3000)
- **Backend**: FastAPI Python (port 8001)  
- **WhatsApp Service**: Node.js WhatsApp-web.js (port 3001)
- **Database**: MongoDB
- **Scheduler**: APScheduler (AsyncIOScheduler)

## User Personas
1. **Power User**: Schedules recurring WhatsApp messages for business/personal use
2. **Casual User**: Sends one-time scheduled messages

## Core Requirements (Static)
- Send WhatsApp messages via web interface
- Schedule one-time and recurring messages
- Manage contacts and message templates
- View message logs and history
- Telegram notification integration

---

## What's Been Implemented

### January 2026 - Bug Fixes

#### 1. Manual Run Feature for Scheduled Messages
- **Files Changed**: `/app/frontend/src/pages/Scheduler.jsx`
- **Implementation**: Added Play button (▶) in the Actions column of scheduled messages table
- **Functionality**: Clicking Play button triggers `/api/schedules/test-run/{id}` endpoint to immediately execute any scheduled message
- **Testing**: Verified button renders, API endpoint responds correctly

#### 2. Fixed Scheduled Messages Not Sending
- **Files Changed**: `/app/backend/services/scheduler/job_manager.py`
- **Root Cause**: `execute_scheduled_message` is async but APScheduler wasn't properly awaiting it
- **Fix**: Created `run_scheduled_message()` sync wrapper that uses `asyncio.create_task()` to properly execute async coroutines within the running event loop
- **Testing**: APScheduler now correctly dispatches jobs

#### 3. Fixed WhatsApp Session Persistence After Stop/Start
- **Files Changed**: `/app/stop.sh`, `/app/whatsapp-service/src/app.js`, `/app/start.sh`
- **Root Cause**: `stop.sh` was using `kill -9` (SIGKILL) which doesn't allow graceful shutdown for session saving
- **Fixes**:
  - Updated `stop.sh` (v2.2.0) to use SIGTERM first with 15-second grace period before SIGKILL
  - Added auto-initialization in `app.js` that checks for existing MongoDB/filesystem sessions on startup
  - Updated `start.sh` to show session restoration status
- **Testing**: Session preservation logic verified

---

## Prioritized Backlog

### P0 (Critical)
- [x] Manual run scheduled messages
- [x] Fix scheduled messages execution
- [x] Fix WhatsApp session persistence

### P1 (High Priority)
- [ ] Add bulk scheduling for multiple contacts
- [ ] Add message delivery confirmation/read receipts

### P2 (Medium Priority)  
- [ ] Add message scheduling preview/dry-run
- [ ] Export message logs to CSV

### Future Enhancements
- [ ] WhatsApp group messaging support
- [ ] Media attachment support (images, documents)
- [ ] Message templates with variables
- [ ] Analytics dashboard for message performance

---

## Next Tasks
1. Test the full stop/start cycle on user's WSL Ubuntu environment
2. Verify scheduled messages actually send at scheduled times
3. Test manual run button with real WhatsApp messages
