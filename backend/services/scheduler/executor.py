"""Schedule execution logic"""
from datetime import datetime, timezone
from core.database import get_database
from core.logging import logger
from services.whatsapp.message_sender import send_whatsapp_message
from services.telegram.sender import send_telegram_notification
from models.message_log import MessageLog


async def execute_scheduled_message(schedule_id: str):
    """Execute a scheduled message"""
    logger.info(f"🔔 EXECUTING SCHEDULE: {schedule_id}")
    try:
        database = await get_database()
        schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
        
        if not schedule:
            logger.warning(f"Schedule {schedule_id} not found in database")
            return
            
        if not schedule.get('is_active'):
            logger.info(f"Schedule {schedule_id} is inactive, skipping")
            return
        
        logger.info(f"📤 Sending to {schedule['contact_name']} ({schedule['contact_phone']}): {schedule['message'][:50]}...")
        
        # Send the message
        result = await send_whatsapp_message(schedule['contact_phone'], schedule['message'])
        
        status = "sent" if result.get('success') else "failed"
        logger.info(f"📬 Result: {status} - {result}")
        
        # Log the message
        log = MessageLog(
            contact_id=schedule['contact_id'],
            contact_name=schedule['contact_name'],
            contact_phone=schedule['contact_phone'],
            message=schedule['message'],
            status=status,
            error_message=result.get('error'),
            scheduled_message_id=schedule_id
        )
        log_doc = log.model_dump()
        log_doc['sent_at'] = log_doc['sent_at'].isoformat()
        await database.logs.insert_one(log_doc)
        
        # Update last run
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": {"last_run": datetime.now(timezone.utc).isoformat()}}
        )
        
        # Send Telegram notification if enabled
        await send_telegram_notification(
            f"{'✅' if status == 'sent' else '❌'} Scheduled message {status}\n\n"
            f"📞 {schedule['contact_name']}\n"
            f"💬 {schedule['message'][:100]}"
        )
                
    except Exception as e:
        logger.error(f"❌ Execute scheduled message error: {e}", exc_info=True)
