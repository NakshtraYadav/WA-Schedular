# Performance Optimization Guide

## Current Resource Usage Analysis

The WhatsApp Scheduler uses significant resources due to:
1. **Chromium Browser** (whatsapp-web.js) - Biggest consumer (~300-500MB RAM)
2. **MongoDB** - Database engine (~100-200MB RAM)
3. **Node.js WhatsApp Service** - ~50-100MB RAM
4. **Python Backend (FastAPI)** - ~50-100MB RAM
5. **React Frontend Dev Server** - ~100-200MB RAM (dev only)

**Total Typical Usage: 600MB - 1.2GB RAM**

---

## Optimization Strategies

### 1. Chromium/Browser Optimizations (Biggest Impact)

```javascript
// In whatsapp-service/src/services/whatsapp/client.js
const client = new Client({
  puppeteer: {
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',      // Use /tmp instead of /dev/shm
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--single-process',              // Reduces memory but slower
      '--disable-gpu',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-default-apps',
      '--disable-sync',
      '--disable-translate',
      '--metrics-recording-only',
      '--mute-audio',
      '--no-default-browser-check',
      '--safebrowsing-disable-auto-update',
      // Memory limits
      '--js-flags="--max-old-space-size=256"',  // Limit JS heap
    ]
  }
});
```

**Estimated Savings: 100-200MB RAM**

### 2. MongoDB Optimizations

```javascript
// Limit MongoDB memory usage via config
// mongod.conf or startup args
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.25  // Limit to 256MB cache

// Or via connection string
mongodb://localhost:27017/wa_scheduler?maxPoolSize=5
```

**Alternative: Use SQLite instead of MongoDB for low-end PCs**
- Much lighter (~10MB vs ~200MB)
- No separate process needed
- Trade-off: Less scalable for high message volume

**Estimated Savings: 100-150MB RAM**

### 3. Frontend Optimizations

**Production Build (Critical!)**
```bash
# Instead of dev server, use production build
cd frontend
npm run build
# Serve with nginx or simple static server
```

**Why it matters:**
- Dev server: ~200MB RAM + constant rebuilding
- Production build: ~10MB RAM (static files)

**Code Splitting & Lazy Loading**
```javascript
// Instead of importing everything upfront
import { lazy, Suspense } from 'react';

const Settings = lazy(() => import('./pages/Settings'));
const Contacts = lazy(() => import('./pages/Contacts'));

// In router
<Suspense fallback={<Loading />}>
  <Settings />
</Suspense>
```

**Estimated Savings: 100-200MB RAM**

### 4. Backend Optimizations

```python
# Use uvicorn with limited workers
uvicorn server:app --workers 1 --limit-concurrency 10

# In requirements.txt - remove unused packages
# Audit with: pip-autoremove

# Use gunicorn with memory limits
gunicorn server:app -w 1 --max-requests 1000 --max-requests-jitter 100
```

**Estimated Savings: 20-50MB RAM**

### 5. Process Management

**Run services only when needed:**
```bash
# Lazy start WhatsApp service
# Only start browser when user needs to connect
# Keep session in MongoDB, browser can restart

# Script: start-lite.sh
#!/bin/bash
# Start only essential services
mongod --config /path/to/lite-config.conf &
python -m uvicorn server:app --host 0.0.0.0 --port 8001 &
# WhatsApp service starts on-demand via API
```

---

## Recommended Configurations

### For Low-End PCs (4GB RAM)
```
┌────────────────────────────────────┐
│  Configuration: LITE MODE          │
├────────────────────────────────────┤
│  MongoDB cache: 128MB              │
│  Chromium: Single process + limits │
│  Frontend: Production build        │
│  Backend: 1 worker                 │
├────────────────────────────────────┤
│  Expected RAM: 400-600MB           │
└────────────────────────────────────┘
```

### For Standard PCs (8GB RAM)
```
┌────────────────────────────────────┐
│  Configuration: STANDARD           │
├────────────────────────────────────┤
│  MongoDB cache: 256MB              │
│  Chromium: Default with some opts  │
│  Frontend: Dev or Production       │
│  Backend: 1-2 workers              │
├────────────────────────────────────┤
│  Expected RAM: 600-900MB           │
└────────────────────────────────────┘
```

---

## Implementation Priority

| Priority | Change | Impact | Effort |
|----------|--------|--------|--------|
| 1 | Production frontend build | -200MB | Low |
| 2 | Chromium args optimization | -150MB | Low |
| 3 | MongoDB cache limit | -100MB | Low |
| 4 | Lazy load frontend routes | -50MB | Medium |
| 5 | SQLite option | -200MB | High |
| 6 | On-demand WhatsApp start | -300MB idle | Medium |

---

## Quick Wins (No Code Changes)

1. **Close Chrome/browser tabs** while running
2. **Use production build** instead of dev server
3. **Disable Telegram bot** if not using
4. **Restart services weekly** to clear memory leaks
5. **Schedule fewer concurrent messages** (batch them)

---

## Commands to Monitor Usage

```bash
# Check per-process memory
ps aux --sort=-%mem | head -10

# Real-time monitoring
htop

# Node.js memory
node --expose-gc -e "console.log(process.memoryUsage())"

# MongoDB stats
mongo --eval "db.serverStatus().mem"
```

---

## Future Considerations

1. **Desktop app with Electron** - Can package with resource limits
2. **Cloud option** - Run WhatsApp service in cloud, UI locally
3. **Mobile-first PWA** - Lighter than desktop app
4. **Scheduled hibernation** - Stop services during off-hours

---

*Document Version: 1.0*
*Created: 2026-02-05*
