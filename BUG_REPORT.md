# 🐛 WA Scheduler - Bug Report v2.1.4

## Fixed Issues ✅

### 1. ✅ Update Not Working from Localhost (FIXED)
**Root Cause:** Missing `REACT_APP_BACKEND_URL` in frontend/.env
**Fix:** Created `/app/frontend/.env` with `REACT_APP_BACKEND_URL=http://localhost:8001`

### 2. ✅ Settings.jsx apiClient Import Error (FIXED)
**Root Cause:** `apiClient.post('/api/telegram/test')` used without importing apiClient
**Fix:** Changed to use imported `testTelegram()` function from '../api'

### 3. ✅ Version Context Mismatch (FIXED)
**Root Cause:** Settings.jsx destructured `checkVersion` but hook returned `refresh`
**Fix:** Changed to `const { version: versionInfo, refresh: checkVersion }`

### 4. ✅ Diagnostics Logs Not Showing (FIXED)
**Root Cause:** start.sh writes to `logs/backend.log` but diagnostics checked `logs/backend/`
**Fix:** Updated diagnostics.py to check both direct log files and subdirectory

---

## Previously Fixed Issues
