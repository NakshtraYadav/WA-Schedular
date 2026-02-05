# 🐛 WA Scheduler - Bug Report v2.1.4

## Critical Issues (Must Fix)

### 1. ❌ Toast Notifications Not Showing
**Severity:** HIGH  
**Impact:** Users don't see any feedback when clicking buttons

**Problem:**
- `App.js` uses shadcn `Toaster` from `./components/ui/toaster`
- All pages use `sonner` library (`import { toast } from 'sonner'`)
- These are TWO DIFFERENT toast systems - they don't work together!

**Fix:** Either:
- A) Add Sonner's `<Toaster />` to App.js, OR
- B) Convert all pages to use shadcn's `useToast` hook

---

### 2. ❌ Chromium Browser Not Found (WhatsApp Service)
**Severity:** HIGH  
**Impact:** WhatsApp service won't start without browser

**Problem:**
```
Browser was not found at the configured executablePath (/usr/bin/chromium)
```

**Fix:** Add to `start.sh setup`:
```bash
# Ubuntu/Debian
sudo apt install chromium-browser
# OR
sudo apt install chromium
```

---

### 3. ❌ Logs Not Showing in Diagnostics
**Severity:** MEDIUM  
**Impact:** Can't debug issues from UI

**Problem:**
- Backend looks for logs at `/app/logs/backend/` expecting `.log` files
- `start.sh` writes to `/app/logs/backend.log` (not in subdirectory)
- Log directory structure mismatch

**Fix:** Either:
- A) Change `start.sh` to write to `/app/logs/backend/app.log`, OR
- B) Change diagnostics route to look for `/app/logs/backend.log`

---

## Medium Issues

### 4. ⚠️ No Chromium Installation in Setup
**Impact:** First-time users get confusing error

**Fix:** Add to setup command in `start.sh`

---

### 5. ⚠️ Virtual Environment Not Activated for Some Operations
**Impact:** May cause import errors in some scenarios

**Current:** venv created but update command may not use it

---

### 6. ⚠️ Frontend Hot Reload Inconsistent on WSL
**Impact:** Changes sometimes don't appear

**Problem:** WSL file system events unreliable

**Current Fix:** Added `CHOKIDAR_USEPOLLING=true`

---

## Minor Issues

### 7. 📝 Missing `sendNow` Export
**Status:** May have been fixed by testing agent

---

### 8. 📝 Old Scripts References in Code
**Problem:** Some code may still reference `update.sh`, `setup.sh`

---

### 9. 📝 Dashboard May Show Stale Data
**Impact:** Stats don't auto-refresh

---

## Environment-Specific Issues

### WSL (Windows)
- File watching requires polling mode
- Port cleanup may need manual intervention
- Virtual environment required for Python 3.12+

### Ubuntu 24.04+
- Requires virtual environment (externally-managed-environment)
- Chromium package name varies (`chromium` vs `chromium-browser`)

### Ubuntu 22.04 / 20.04
- May work without venv
- Need to check chromium package name

---

## Recommended Fix Priority

1. **Toast System** - Users can't see any feedback
2. **Chromium Setup** - WhatsApp won't work at all
3. **Logs Path** - Debugging impossible from UI
4. **Setup Script** - First-time experience broken

---

## Files to Fix

| File | Issue |
|------|-------|
| `/app/frontend/src/App.js` | Add Sonner Toaster |
| `/app/start.sh` | Add chromium install, fix log paths |
| `/app/backend/routes/diagnostics.py` | Fix log file paths |
| All pages in `/app/frontend/src/pages/` | Toast import consistency |
