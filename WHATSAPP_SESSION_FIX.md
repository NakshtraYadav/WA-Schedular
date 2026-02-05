# WhatsApp Session Persistence - Root Cause Analysis & Production Fix

## Executive Summary

**Root Cause Identified:** Multiple compounding issues causing session loss

---

## 1️⃣ ROOT CAUSE ANALYSIS

### Finding #1: RELATIVE SESSION PATH (CRITICAL)

**File:** `/app/whatsapp-service/src/config/env.js`
```javascript
const SESSION_PATH = process.env.SESSION_PATH || './.wwebjs_auth';
```

**Problem:** Relative path `./.wwebjs_auth` resolves differently depending on:
- Where `node` is started from
- Current working directory at runtime
- How the process is spawned (nohup, supervisor, etc.)

**Evidence:** No `.wwebjs_auth` directory exists anywhere in `/app`:
```
find /app -name ".wwebjs*" -type d 2>/dev/null
# Returns empty
```

This means either:
1. WhatsApp was never successfully initialized, OR
2. Session data was written to an unexpected location, OR
3. Session data was wiped by the overlay filesystem

---

### Finding #2: OVERLAY FILESYSTEM (CRITICAL)

**Discovery:**
```
mount | grep overlay
overlay on / type overlay (rw,relatime,lowerdir=...,upperdir=/var/lib/containerd/...)
```

The root filesystem is a **container overlay**. While `/app` is on persistent storage (`/dev/nvme0n4`), any files written outside `/app` are **EPHEMERAL**.

**Risk:** If the working directory isn't `/app/whatsapp-service` when the process starts, `./.wwebjs_auth` could resolve to `/` (overlay) and vanish on restart.

---

### Finding #3: DANGEROUS `npm run clean` SCRIPT

**File:** `/app/whatsapp-service/package.json`
```json
"clean": "node -e \"const fs=require('fs');['.wwebjs_auth','.wwebjs_cache'].forEach(p=>{if(fs.existsSync(p)){fs.rmSync(p,{recursive:true});console.log('Cleared:',p)}})\""
```

**Problem:** This script deletes ALL session data. If run accidentally (or by CI/CD), sessions are gone.

---

### Finding #4: `client.destroy()` WITHOUT GRACEFUL SHUTDOWN

**File:** `/app/whatsapp-service/src/services/whatsapp/client.js`
```javascript
if (client) {
  try {
    await client.destroy();  // This can corrupt session!
  } catch (e) {
    log('WARN', 'Error destroying old client:', e.message);
  }
}
client = createClient();  // Immediately creates new client
```

**Problem:** `client.destroy()` triggers Puppeteer shutdown which may not complete session save before the new client starts, causing:
- Chromium profile lock conflicts
- Incomplete session write
- Corrupted IndexedDB

---

### Finding #5: NO SESSION INTEGRITY VALIDATION

The code never verifies session data exists before initialization. It just initializes and shows QR code if session is invalid/missing.

---

## 2️⃣ WSL FILESYSTEM AUDIT

### Current Environment
This is NOT WSL2 - it's a **Kubernetes container** with overlay filesystem.

However, the principles apply similarly:

| Location | Persistence | Risk |
|----------|-------------|------|
| `/app/` | ✅ Persistent (NVMe) | Safe for sessions |
| `/tmp/` | ❌ Ephemeral | Sessions lost on restart |
| `/` (root overlay) | ❌ Ephemeral | Sessions lost on restart |
| `./.wwebjs_auth` | ⚠️ Depends on CWD | Unpredictable |

### Recommended Session Path
```
/app/data/whatsapp-sessions/
```

**Why this is safe:**
1. Absolute path - no CWD ambiguity
2. Inside `/app` which is on persistent NVMe storage
3. Survives container restarts
4. Can be backed up easily

---

## 3️⃣ BUILD/RESTART SESSION WIPE

### Potential Wipe Triggers

1. **`npm run clean`** - Explicitly deletes sessions
2. **`npm install`** - Doesn't delete, but can reset timestamps
3. **Container rebuild** - Only wipes if session outside `/app`
4. **`git clean -fdx`** - Would delete untracked `.wwebjs_auth`

### Git Ignore Status
```
.wwebjs_auth/
.wwebjs_cache/
```
Sessions ARE in `.gitignore` which is correct.

---

## 4️⃣ AUTH STRATEGY VALIDATION

### Current Strategy: `LocalAuth`
```javascript
new LocalAuth({ dataPath: SESSION_PATH })
```

**LocalAuth is ACCEPTABLE** if configured correctly. The problem is the relative path.

### LocalAuth Requirements
| Requirement | Current Status |
|-------------|----------------|
| Stable absolute dataPath | ❌ Relative path |
| Not in temp folder | ⚠️ Unknown (depends on CWD) |
| Not in build directory | ✅ If CWD is correct |
| Correct permissions | ⚠️ Running as root |
| Survives restarts | ❌ Currently broken |

---

## 5️⃣ PERMANENT FIX

### Option A: Production-Grade LocalAuth (RECOMMENDED)

**Create persistent session directory:**
```bash
mkdir -p /app/data/whatsapp-sessions
chmod 755 /app/data/whatsapp-sessions
```

**Updated configuration:**

