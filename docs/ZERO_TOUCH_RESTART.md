# Zero-Touch Graceful Restart System

## Design Document
**Version:** 1.0.0  
**Author:** Senior Platform Engineer  
**Goal:** Eliminate manual ./stop ./start while protecting all stateful components

---

## PHASE 1: CURRENT UPDATE FLOW AUDIT

### Current Flow Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│                    CURRENT UPDATE FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User runs ./start.sh update (or git pull)                   │
│  2. Git fetches latest code                                      │
│  3. Hot reload SOMETIMES works:                                  │
│     - Backend: uvicorn --reload (works)                         │
│     - Frontend: React hot reload (works)                        │
│     - WhatsApp: NO HOT RELOAD (BROKEN)                          │
│  4. Dependencies: Background install (unreliable)               │
│  5. Full restart required when:                                 │
│     - requirements.txt changes                                  │
│     - package.json changes                                      │
│     - whatsapp-service/ changes                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why Manual Restart is Required

| Component | Hot Reload | Why Manual Restart Needed |
|-----------|------------|---------------------------|
| Backend | ✅ Works | Never (hot reload handles it) |
| Frontend | ✅ Works | Never (HMR handles it) |
| WhatsApp | ❌ None | ANY code change requires restart |
| Scheduler | ❌ None | Job changes require reload |
| Dependencies | ❌ None | npm/pip installs require restart |

### Risks of Naive Auto-Restart

| Risk | Impact | Probability |
|------|--------|-------------|
| WhatsApp session corruption | QR rescan required | HIGH |
| Duplicate scheduler execution | Double messages | HIGH |
| Partial MongoDB writes | Data inconsistency | MEDIUM |
| Zombie distributed locks | Stuck schedules | MEDIUM |
| Reconnect storms | System overload | LOW |

---

## PHASE 2: SAFE RESTART ARCHITECTURE

### Graceful Shutdown Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                 GRACEFUL SHUTDOWN SEQUENCE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ON RESTART SIGNAL (SIGTERM):                                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 1. SCHEDULER PAUSE (immediate)                            │   │
│  │    - scheduler.pause()                                    │   │
│  │    - Set accepting_jobs = false                          │   │
│  │    - Reject new job claims                                │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 2. DRAIN IN-FLIGHT (wait up to 30s)                       │   │
│  │    - Wait for active HTTP requests                        │   │
│  │    - Wait for executing messages                          │   │
│  │    - Timeout safety valve                                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 3. WHATSAPP SESSION SAVE (critical)                       │   │
│  │    - Force session sync to MongoDB                        │   │
│  │    - Verify save completed                                │   │
│  │    - Close browser gracefully                             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 4. RELEASE DISTRIBUTED LOCKS                              │   │
│  │    - Release execution locks                              │   │
│  │    - Release reconnect locks                              │   │
│  │    - Clear worker registration                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 5. CLOSE CONNECTIONS                                      │   │
│  │    - Close MongoDB connections                            │   │
│  │    - Close HTTP clients                                   │   │
│  │    - Close WebSocket connections                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 6. FLUSH LOGS                                             │   │
│  │    - Sync file buffers                                    │   │
│  │    - Write shutdown marker                                │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 7. EXIT                                                   │   │
│  │    - process.exit(0)                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## PHASE 3: PM2 PROCESS SUPERVISOR

### ecosystem.config.js

See `/app/ecosystem.config.js` for the complete configuration.

### Key Features

| Feature | Backend | WhatsApp | Frontend |
|---------|---------|----------|----------|
| Graceful reload | ✅ | ✅ | ✅ |
| Kill timeout | 10s | 30s | 5s |
| Memory limit | 512MB | 2GB | 1GB |
| Auto-restart | ✅ | ✅ | ✅ |
| Cluster mode | No | No | No |
| Watch mode | Dev only | No | Dev only |

### PM2 Commands

```bash
# Start all services
pm2 start ecosystem.config.js

# Graceful reload (zero-downtime)
pm2 reload wa-scheduler --update-env

# View logs
pm2 logs

# Monitor
pm2 monit

# Status
pm2 status

# Save config (for system startup)
pm2 save
pm2 startup
```

---

## PHASE 4: ZERO-DOWNTIME UPDATE FLOW

### New Update Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│                 ZERO-DOWNTIME UPDATE FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. UPDATE DETECTION                                            │
│     - Webhook from GitHub (or cron poll)                        │
│     - Parse changed files                                       │
│                                                                  │
│  2. PRE-FLIGHT CHECKS                                           │
│     - Verify no in-flight messages                              │
│     - Verify session health                                     │
│     - Create rollback snapshot                                  │
│                                                                  │
│  3. STAGED DEPLOYMENT                                           │
│     - Git pull to staging directory                             │
│     - Install dependencies                                      │
│     - Run health checks                                         │
│                                                                  │
│  4. GRACEFUL RELOAD                                             │
│     - Backend: pm2 reload (seamless)                            │
│     - WhatsApp: pm2 reload (30s drain)                          │
│     - Frontend: pm2 reload (immediate)                          │
│                                                                  │
│  5. POST-DEPLOYMENT VALIDATION                                  │
│     - Health check all services                                 │
│     - Verify session restored                                   │
│     - Rollback if failed                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Files

1. `/app/ecosystem.config.js` - PM2 configuration
2. `/app/whatsapp-service/src/graceful.js` - Shutdown coordinator
3. `/app/backend/core/graceful.py` - Backend shutdown
4. `/app/scripts/zero-touch-update.sh` - Update orchestrator
