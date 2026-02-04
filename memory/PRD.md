# WhatsApp Scheduler - PRD

## Original Problem Statement
Fix compilation errors and add version system:
1. Missing `simulateConnect` export from api.js
2. React Hook "useTemplate" called inside callbacks (invalid hook usage)
3. Add version system for updates

## Architecture
- Frontend: React with Tailwind CSS
- Backend: FastAPI with MongoDB
- WhatsApp service integration

## What's Been Implemented (2026-02-04)
- Fixed `simulateConnect` import error - removed unused import and function
- Fixed React Hook violation - renamed `useTemplate` to `applyTemplate` 
- Added `/api/version` endpoint for version tracking
- Added `getAppVersion()` to frontend API

## Version System
- Backend exposes `/api/version` returning `{version, git_sha, app_name, build_date}`
- Update system exists at `/api/updates/check` and `/api/updates/install`
- Auto-updater daemon control available

## Next Tasks
- Display version in UI (footer/settings page)
- Integrate version check on app startup
