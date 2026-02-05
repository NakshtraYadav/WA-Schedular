# 🔒 WA Scheduler - DURABILITY & RESTART SAFETY AUDIT

**Audit Focus:** State persistence across failures  
**Perspective:** Distributed Systems Engineer  
**Version:** 2.8.0  

---

## FAILURE SCENARIO MATRIX

| Scenario | Scheduler Jobs | WhatsApp Session | Message Queue | DB State |
|----------|---------------|------------------|---------------|----------|
| Process crash (SIGKILL) | ❌ LOST | ⚠️ PARTIAL | ❌ NO QUEUE | ✅ SAFE |
| Container restart | ❌ LOST* | ✅ RECOVERS | ❌ NO QUEUE | ✅ SAFE |
| Machine reboot | ❌ LOST* | ✅ RECOVERS | ❌ NO QUEUE | ✅ SAFE |
| Network drop | ✅ IN-MEMORY | ⚠️ RECONNECTS | ❌ FAILS SILENTLY | ✅ SAFE |
| WhatsApp disconnect | ✅ IN-MEMORY | ⚠️ 10s DELAY | ❌ MSGS FAIL | ✅ SAFE |
| MongoDB crash | ✅ IN-MEMORY | ❌ NO PERSIST | ❌ FAILS | ❌ UNAVAILABLE |

*Jobs reload from DB on startup via `reload_schedules()`

---

## FLAW #1: SCHEDULER JOBS IN VOLATILE MEMORY

### Location
```
/app/backend/core/scheduler.py
```

### Current Implementation
```python
scheduler = AsyncIOScheduler()  # In-memory job store
```

### How It Fails
1. **Process crash** → All scheduled jobs vanish instantly
2. **Graceful restart** → Jobs lost between shutdown and `reload_schedules()`
3. **Race condition** → Job fires DURING reload, gets skipped

### Production Impact
- One-time scheduled messages silently never send
- User thinks message was scheduled, but process restarted
- No audit trail of what was supposed to run

### Current Mitigation
`reload_schedules()` runs on startup - **ADEQUATE for single-user**

### Robust Redesign (If Needed for Multi-User)
```python
from apscheduler.jobstores.mongodb import MongoDBJobStore

async def create_scheduler():
    client = AsyncIOMotorClient(settings.MONGO_URL)
    
    scheduler = AsyncIOScheduler(
        jobstores={
            'default': MongoDBJobStore(
                database=settings.DB_NAME,
                collection='scheduler_jobs',
                client=client
            )
        },
        job_defaults={
            'coalesce': True,  # Combine missed runs
            'max_instances': 1,
            'misfire_grace_time': 3600  # 1 hour grace for missed jobs
        }
    )
    return scheduler
```

### Verdict: ⚠️ ACCEPTABLE
Current `reload_schedules()` approach is sufficient for single-user desktop app. MongoDB job store adds complexity without proportional benefit.

---

## FLAW #2: NO MESSAGE DELIVERY QUEUE

### Location
```
/app/backend/services/scheduler/executor.py:32
```

### Current Implementation
```python
result = await send_whatsapp_message(contact_phone, message)
# If this fails, message is logged as "failed" but NEVER RETRIED
```

### How It Fails
1. **WhatsApp temporarily disconnected** → Message fails, no retry
2. **Network blip during send** → Message lost
3. **WhatsApp service restarting** → Messages during window fail silently

### Production Impact
- "Hey honey happy birthday!" scheduled for midnight → WhatsApp reconnecting → LOST
- User checks logs next day: "failed" with no automatic recovery

### Robust Redesign
```python
# /app/backend/services/scheduler/executor.py

MAX_RETRIES = 3
RETRY_DELAYS = [30, 120, 300]  # 30s, 2min, 5min

async def execute_scheduled_message(schedule_id: str):
    """Execute with retry logic"""
    database = await get_database()
    schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    
    if not schedule:
        return
    
    # Check for existing pending attempt (deduplication)
    existing_attempt = await database.message_attempts.find_one({
        "schedule_id": schedule_id,
        "status": "pending",
        "created_at": {"$gt": (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat()}
    })
    
    if existing_attempt:
        logger.info(f"Dedup: attempt already pending for {schedule_id}")
        return
    
    # Create attempt record BEFORE sending (crash-safe)
    attempt_id = str(uuid.uuid4())
    await database.message_attempts.insert_one({
        "id": attempt_id,
        "schedule_id": schedule_id,
        "status": "pending",
        "attempt_number": 1,
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    
    # Try sending with retries
    for attempt in range(MAX_RETRIES):
        result = await send_whatsapp_message(schedule['contact_phone'], schedule['message'])
        
        if result.get('success'):
            await database.message_attempts.update_one(
                {"id": attempt_id},
                {"$set": {"status": "sent", "completed_at": datetime.now(timezone.utc).isoformat()}}
            )
            await log_message(database, schedule, "sent")
            return
        
        # Update attempt count
        await database.message_attempts.update_one(
            {"id": attempt_id},
            {"$set": {"attempt_number": attempt + 1, "last_error": result.get('error')}}
        )
        
        if attempt < MAX_RETRIES - 1:
            await asyncio.sleep(RETRY_DELAYS[attempt])
    
    # All retries exhausted
    await database.message_attempts.update_one(
        {"id": attempt_id},
        {"$set": {"status": "failed", "completed_at": datetime.now(timezone.utc).isoformat()}}
    )
    await log_message(database, schedule, "failed", result.get('error'))
```

### Simpler Alternative (Recommended)
Add retry recovery on startup:

```python
# In server.py startup
async def recover_pending_messages():
    """Retry any messages that were pending when we crashed"""
    database = await get_database()
    
    pending = await database.message_attempts.find({
        "status": "pending",
        "attempt_number": {"$lt": 3}
    }).to_list(100)
    
    for attempt in pending:
        logger.info(f"Recovering pending message: {attempt['schedule_id']}")
        asyncio.create_task(retry_message_attempt(attempt['id']))
```

---

## FLAW #3: NON-ATOMIC SCHEDULE EXECUTION

### Location
```
/app/backend/services/scheduler/executor.py:51-67
```

### Current Implementation
```python
# Step 1: Send message
result = await send_whatsapp_message(...)

# Step 2: Log to database  
await database.logs.insert_one(log_doc)  # CRASH HERE = no log

# Step 3: Update last_run
await database.schedules.update_one(...)  # CRASH HERE = stale last_run

# Step 4: Mark complete (one-time)
await database.schedules.update_one(...)  # CRASH HERE = runs again!
```

### How It Fails
1. **Crash after send, before log** → Message sent but no record
2. **Crash after log, before complete** → One-time message runs TWICE on restart

### Production Impact
- Birthday message sends twice (embarrassing)
- No record of sent messages (audit failure)

### Robust Redesign
```python
async def execute_scheduled_message(schedule_id: str):
    """Execute with idempotency guarantee"""
    database = await get_database()
    
    # STEP 1: Claim this execution with atomic update
    # This prevents double-execution on crash recovery
    claim_result = await database.schedules.find_one_and_update(
        {
            "id": schedule_id,
            "is_active": True,
            "$or": [
                {"execution_lock": {"$exists": False}},
                {"execution_lock": {"$lt": datetime.now(timezone.utc) - timedelta(minutes=5)}}
            ]
        },
        {
            "$set": {"execution_lock": datetime.now(timezone.utc).isoformat()}
        },
        return_document=True
    )
    
    if not claim_result:
        logger.info(f"Schedule {schedule_id} already being executed or inactive")
        return
    
    schedule = claim_result
    execution_id = str(uuid.uuid4())
    
    try:
        # STEP 2: Send message
        result = await send_whatsapp_message(schedule['contact_phone'], schedule['message'])
        status = "sent" if result.get('success') else "failed"
        
        # STEP 3: Atomic completion (log + update in pseudo-transaction)
        # MongoDB 4.0+ supports transactions, but for simplicity:
        
        log_doc = {
            "id": str(uuid.uuid4()),
            "execution_id": execution_id,
            "schedule_id": schedule_id,
            "contact_phone": schedule['contact_phone'],
            "message": schedule['message'],
            "status": status,
            "error_message": result.get('error'),
            "sent_at": datetime.now(timezone.utc).isoformat()
        }
        await database.logs.insert_one(log_doc)
        
        update_fields = {
            "last_run": datetime.now(timezone.utc).isoformat(),
            "last_execution_id": execution_id,
            "execution_lock": None  # Release lock
        }
        
        if schedule.get('schedule_type') == 'once':
            update_fields["is_active"] = False
            update_fields["completed_at"] = datetime.now(timezone.utc).isoformat()
        
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": update_fields}
        )
        
    except Exception as e:
        # Release lock on error
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": {"execution_lock": None}}
        )
        raise
```

---

## FLAW #4: WHATSAPP RECONNECT HAS 10-SECOND BLIND SPOT

### Location
```
/app/whatsapp-service/src/services/whatsapp/client.js:517-525
```

### Current Implementation
```javascript
client.on('disconnected', async (reason) => {
  // ...
  if (reason !== 'LOGOUT' && !isShuttingDown) {
    setTimeout(() => {
      initWhatsApp();  // 10 second delay before reconnect
    }, 10000);
  }
});
```

### How It Fails
1. WhatsApp disconnects at 11:59:55
2. Scheduled message fires at 12:00:00
3. WhatsApp still reconnecting → Message fails
4. Reconnect completes at 12:00:05
5. Message already logged as "failed" - no retry

### Production Impact
- Messages scheduled during reconnect window silently fail
- ~10 seconds of vulnerability on every disconnect

### Robust Redesign
```javascript
// Track connection state for callers
let connectionState = 'disconnected';
let reconnectAttempt = 0;
const MAX_RECONNECT_ATTEMPTS = 5;
const pendingMessages = [];  // Queue during reconnect

const getConnectionState = () => connectionState;

// Queue messages during reconnect
const queueMessage = (phone, message) => {
  pendingMessages.push({ phone, message, timestamp: Date.now() });
};

const flushPendingMessages = async () => {
  while (pendingMessages.length > 0) {
    const msg = pendingMessages.shift();
    // Only send if queued < 5 minutes ago
    if (Date.now() - msg.timestamp < 300000) {
      await sendMessage(msg.phone, msg.message);
    }
  }
};

client.on('disconnected', async (reason) => {
  connectionState = 'reconnecting';
  
  if (reason !== 'LOGOUT' && !isShuttingDown) {
    const delay = Math.min(5000 * Math.pow(2, reconnectAttempt), 60000);
    reconnectAttempt++;
    
    log('INFO', `Reconnecting in ${delay/1000}s (attempt ${reconnectAttempt})`);
    
    setTimeout(async () => {
      if (!isShuttingDown) {
        await initWhatsApp();
      }
    }, delay);
  }
});

client.on('ready', async () => {
  connectionState = 'connected';
  reconnectAttempt = 0;
  
  // Flush any messages that were queued during reconnect
  await flushPendingMessages();
});
```

**Backend integration:**
```python
# /app/backend/services/whatsapp/message_sender.py

async def send_whatsapp_message(phone: str, message: str) -> dict:
    """Send with connection-aware retry"""
    http_client = await get_http_client()
    
    for attempt in range(3):
        try:
            # Check connection state first
            status_response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=2.0)
            status = status_response.json()
            
            if not status.get('isReady'):
                if status.get('connectionState') == 'reconnecting':
                    # Queue for later
                    await http_client.post(
                        f"{WA_SERVICE_URL}/queue-message",
                        json={"phone": phone, "message": message}
                    )
                    return {"success": True, "queued": True}
                
                await asyncio.sleep(2)
                continue
            
            response = await http_client.post(
                f"{WA_SERVICE_URL}/send",
                json={"phone": phone, "message": message},
                timeout=30.0
            )
            return response.json()
            
        except Exception as e:
            if attempt < 2:
                await asyncio.sleep(2)
            else:
                return {"success": False, "error": str(e)}
```

---

## FLAW #5: MESSAGE DEDUPLICATION MISSING

### Location
```
/app/backend/services/scheduler/executor.py
```

### Current Implementation
No deduplication. If `execute_scheduled_message` runs twice with same schedule_id, message sends twice.

### How It Fails
1. Job fires, execution starts
2. Process crashes mid-execution
3. Restart → `reload_schedules()` adds job again
4. Job fires again → duplicate message

### Production Impact
"Happy Birthday!" sent twice because of a crash

### Robust Redesign
```python
async def execute_scheduled_message(schedule_id: str):
    """Idempotent execution with deduplication"""
    database = await get_database()
    
    # Generate deterministic execution key based on schedule + time window
    # Same key = same execution attempt
    time_window = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H")  # Hour granularity
    execution_key = f"{schedule_id}:{time_window}"
    
    # Try to claim this execution (atomic)
    try:
        await database.executions.insert_one({
            "_id": execution_key,
            "schedule_id": schedule_id,
            "started_at": datetime.now(timezone.utc).isoformat(),
            "status": "running"
        })
    except DuplicateKeyError:
        # Already executed in this time window
        logger.info(f"Dedup: {schedule_id} already executed in {time_window}")
        return
    
    try:
        # ... execute message ...
        
        await database.executions.update_one(
            {"_id": execution_key},
            {"$set": {"status": "completed", "completed_at": datetime.now(timezone.utc).isoformat()}}
        )
    except Exception as e:
        await database.executions.update_one(
            {"_id": execution_key},
            {"$set": {"status": "failed", "error": str(e)}}
        )
        raise
```

---

## FLAW #6: DB OPERATIONS NOT CRASH-SAFE

### Location
```
/app/backend/services/scheduler/executor.py:51-67
```

### Current Implementation
```python
await database.logs.insert_one(log_doc)           # Operation 1
await database.schedules.update_one({"id": ...})  # Operation 2
await database.schedules.update_one({"id": ...})  # Operation 3
```

### How It Fails
Crash between any operations leaves inconsistent state.

### Robust Redesign
Use write concern and transactions:

```python
async def execute_with_transaction(schedule_id: str, schedule: dict, result: dict):
    """Atomic multi-document update"""
    database = await get_database()
    
    async with await database.client.start_session() as session:
        async with session.start_transaction():
            # All or nothing
            await database.logs.insert_one(log_doc, session=session)
            await database.schedules.update_one(
                {"id": schedule_id},
                {"$set": update_fields},
                session=session
            )
```

**Simpler approach (no transactions):**
```python
# Use write concern for durability
await database.logs.insert_one(
    log_doc,
    write_concern=WriteConcern(w=1, j=True)  # Wait for journal
)
```

---

## WHATSAPP SESSION PERSISTENCE: ✅ WELL DESIGNED

### What's Done Right

1. **MongoDB RemoteAuth** - Sessions survive crashes
```javascript
authStrategy = new RemoteAuth({
  clientId: SESSION_CLIENT_ID,
  store: store,
  backupSyncIntervalMs: 60000  // Sync every 60s
});
```

2. **Graceful shutdown handlers**
```javascript
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
```

3. **Auto-reconnect on disconnect**
```javascript
client.on('disconnected', async (reason) => {
  if (reason !== 'LOGOUT') {
    setTimeout(initWhatsApp, 10000);
  }
});
```

4. **Session validation on startup**
```javascript
const hasSession = await hasExistingSession(SESSION_CLIENT_ID);
```

### Remaining Risk
- **SIGKILL (kill -9)** → Session may not save
- **60-second sync interval** → Up to 60s of session state loss

### Minor Improvement
```javascript
// Reduce sync interval for critical state
backupSyncIntervalMs: 30000  // 30s instead of 60s
```

---

## PRIORITY FIXES

### P0 - Critical (Implement Now)
| Fix | Effort | Impact |
|-----|--------|--------|
| Add execution lock to prevent double-send | 30 min | Prevents duplicate messages |
| Add basic retry for failed sends | 1 hour | Recovers from transient failures |

### P1 - Important (This Week)  
| Fix | Effort | Impact |
|-----|--------|--------|
| Add message deduplication | 1 hour | Crash-safe execution |
| Connection-aware message sending | 2 hours | Handles reconnect gracefully |

### P2 - Nice to Have
| Fix | Effort | Impact |
|-----|--------|--------|
| MongoDB transactions | 2 hours | Full ACID guarantees |
| Persistent job store | 3 hours | Survives without reload |

---

## RECOMMENDED MINIMAL CHANGES

### 1. Add Execution Lock (Prevents Double-Send)

```python
# /app/backend/services/scheduler/executor.py

async def execute_scheduled_message(schedule_id: str):
    """Execute a scheduled message with idempotency"""
    logger.info(f"⏰ EXECUTING scheduled message: {schedule_id}")
    
    database = await get_database()
    
    # Atomic claim - prevents double execution
    now = datetime.now(timezone.utc)
    five_mins_ago = now - timedelta(minutes=5)
    
    schedule = await database.schedules.find_one_and_update(
        {
            "id": schedule_id,
            "is_active": True,
            "$or": [
                {"_executing": {"$exists": False}},
                {"_executing": None},
                {"_executing": {"$lt": five_mins_ago.isoformat()}}
            ]
        },
        {"$set": {"_executing": now.isoformat()}},
        return_document=True,
        projection={"_id": 0}
    )
    
    if not schedule:
        logger.info(f"⏭️ Schedule {schedule_id} already executing or inactive")
        return
    
    try:
        # ... rest of execution logic ...
        
    finally:
        # Always release lock
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": {"_executing": None}}
        )
```

### 2. Add Simple Retry (3 Attempts)

```python
# /app/backend/services/whatsapp/message_sender.py

async def send_whatsapp_message(phone: str, message: str, max_retries: int = 3) -> dict:
    """Send a WhatsApp message with retry logic"""
    http_client = await get_http_client()
    last_error = None
    
    for attempt in range(max_retries):
        try:
            response = await http_client.post(
                f"{WA_SERVICE_URL}/send",
                json={"phone": phone, "message": message},
                timeout=30.0
            )
            result = response.json()
            
            if result.get('success'):
                return result
            
            last_error = result.get('error', 'Unknown error')
            
            # Don't retry if WhatsApp explicitly rejected
            if 'not registered' in last_error.lower():
                return result
                
        except Exception as e:
            last_error = str(e)
        
        if attempt < max_retries - 1:
            delay = 2 ** attempt  # 1s, 2s, 4s
            logger.warning(f"Send failed, retrying in {delay}s: {last_error}")
            await asyncio.sleep(delay)
    
    logger.error(f"Send failed after {max_retries} attempts: {last_error}")
    return {"success": False, "error": last_error}
```

---

## FINAL ASSESSMENT

| Component | Durability Score | Notes |
|-----------|-----------------|-------|
| WhatsApp Session | 8/10 | MongoDB persistence, auto-reconnect |
| Scheduler Jobs | 6/10 | Reload from DB works, but in-memory |
| Message Delivery | 4/10 | No retry, no queue, fails silently |
| DB Operations | 5/10 | No transactions, crash = inconsistent |
| Deduplication | 2/10 | None - double-send possible |

**Overall Durability: 5/10**

For a **single-user desktop app**, this is acceptable. The WhatsApp session handling is surprisingly robust.

For **production multi-user**, you'd need:
1. Message queue (Redis/RabbitMQ)
2. Persistent scheduler jobs
3. Proper transactions
4. Dead letter queue for failures

---

*Audit complete. Prioritize execution lock and retry logic - biggest bang for buck.*
