# WA Scheduler - Product Requirements Document

## Overview
WhatsApp Scheduler is a local desktop application for scheduling WhatsApp messages with Telegram remote control integration.

## Architecture
```
Frontend (React:3000) → Backend (FastAPI:8001) → WhatsApp Service (Node:3001)
                              ↓
                         MongoDB:27017
```

## Core Requirements
1. **WhatsApp Integration** - Connect via QR code, send scheduled messages
2. **Contact Management** - Import, verify, organize contacts
3. **Message Scheduling** - One-time and recurring (cron) schedules
4. **Telegram Bot** - Remote control and notifications
5. **Message Templates** - Reusable message templates

## What's Been Implemented (Feb 2026)

### v3.0.0 - Session Persistence System
- ✅ Durable session store with atomic writes
- ✅ SHA256 checksums for corruption detection
- ✅ Session sync reduced from 60s to 10s
- ✅ Forced session save on shutdown
- ✅ Rehydration engine with exponential backoff
- ✅ Distributed locks for multi-instance safety
- ✅ Circuit breaker prevents reconnect storms
- ✅ Structured event logging for audit

### v2.8.x - Reliability Improvements
- ✅ Fixed race condition in database.py with async lock
- ✅ Added MongoDB indexes for performance
- ✅ Created shared HTTP client (connection pooling)
- ✅ Fixed hardcoded localhost URLs
- ✅ Execution lock prevents double-send
- ✅ Message retry with exponential backoff

### Core Features
- ✅ Full WhatsApp Web integration with session persistence
- ✅ Contact CRUD with WhatsApp verification
- ✅ One-time and recurring message scheduling
- ✅ Telegram bot integration for remote control
- ✅ Message history logging
- ✅ Diagnostics and system health monitoring

## Session Persistence Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  SESSION FLOW                            │
├─────────────────────────────────────────────────────────┤
│  QR Scan → Browser → RemoteAuth → MongoDB (10s sync)    │
│                                                          │
│  On Restart:                                            │
│    1. Load from MongoDB                                 │
│    2. Validate checksum                                 │
│    3. Reconnect with backoff (5s→60s)                   │
│    4. Circuit breaker after 3 failures                  │
└─────────────────────────────────────────────────────────┘
```

## Remaining Backlog

**P0 - Security:**
- [ ] Add API authentication middleware
- [ ] Configure production CORS
- [ ] Add rate limiting

**P1 - Reliability:**
- [ ] Fix remaining bare except clauses
- [ ] Add MongoDB transactions for atomic operations
- [ ] Implement dead letter queue for failed messages

**P2 - Performance:**
- [ ] Add pagination to list endpoints
- [ ] Implement log rotation
- [ ] Add response caching

## User Personas
1. **Personal User** - Schedules birthday/anniversary messages
2. **Small Business** - Customer follow-ups and appointment reminders
3. **Power User** - Complex scheduling with Telegram control

## Production Readiness Score: 7.5/10
(Improved from 5/10 after session persistence work)
