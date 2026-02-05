"""Schedule execution logic"""
from datetime import datetime, timezone, timedelta
from core.database import get_database
from core.logging import logger
from services.whatsapp.message_sender import send_whatsapp_message
from services.telegram.sender import send_telegram_notification
from models.message_log import MessageLog


async def execute_scheduled_message(schedule_id: str):
    """Execute a scheduled message - called by APScheduler
    
    DURABILITY FEATURES:
    - Execution lock prevents double-send on crash recovery
    - Lock auto-expires after 5 minutes (zombie protection)
    """
    logger.info(f"⏰ EXECUTING scheduled message: {schedule_id}")
    
    try:
        database = await get_database()
        
        # STEP 1: Atomic claim with execution lock (prevents double-send)
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
            projection={"_id": 0}
        )
        
        if not schedule:
            # Either already executing, inactive, or doesn't exist
            existing = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
            if existing and existing.get('_executing'):
                logger.info(f"⏭️ Schedule {schedule_id} already being executed, skipping")
            elif existing and not existing.get('is_active'):
                logger.info(f"⏸️ Schedule {schedule_id} is inactive, skipping")
            else:
                logger.warning(f"⚠️ Schedule not found: {schedule_id}")
            return
        
        contact_name = schedule.get('contact_name', 'Unknown')
        contact_phone = schedule.get('contact_phone')
        message = schedule.get('message', '')
        
        logger.info(f"📤 Sending to {contact_name} ({contact_phone}): {message[:50]}...")
        
        # STEP 2: Send the message (with retry logic in sender)
        result = await send_whatsapp_message(contact_phone, message)
        
        status = "sent" if result.get('success') else "failed"
        
        if result.get('success'):
            logger.info(f"✅ Message sent successfully: {schedule_id} -> {contact_name}")
        else:
            logger.error(f"❌ Message failed: {schedule_id} -> {contact_name}: {result.get('error')}")
        
        # STEP 3: Log the message
        log = MessageLog(
            contact_id=schedule['contact_id'],
            contact_name=contact_name,
            contact_phone=contact_phone,
            message=message,
            status=status,
            error_message=result.get('error'),
            scheduled_message_id=schedule_id
        )
        log_doc = log.model_dump()
        log_doc['sent_at'] = log_doc['sent_at'].isoformat()
        await database.logs.insert_one(log_doc)
        
        # STEP 4: Update schedule and release lock
        update_fields = {
            "last_run": now.isoformat(),
            "_executing": None  # Release lock
        }
        
        # If one-time schedule, mark as completed
        if schedule.get('schedule_type') == 'once':
            update_fields["is_active"] = False
            update_fields["completed_at"] = now.isoformat()
            logger.info(f"📝 One-time schedule marked complete: {schedule_id}")
        
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": update_fields}
        )
        
        # STEP 5: Send Telegram notification if enabled
        await send_telegram_notification(
            f"{'✅' if status == 'sent' else '❌'} Scheduled message {status}\n\n"
            f"📞 {contact_name}\n"
            f"💬 {message[:100]}"
        )
                
    except Exception as e:
        logger.error(f"❌ Execute scheduled message error: {e}", exc_info=True)
        
        # Release lock on error
        try:
            database = await get_database()
            await database.schedules.update_one(
                {"id": schedule_id},
                {"$set": {"_executing": None}}
            )
        except Exception:
            pass  # Best effort lock release
