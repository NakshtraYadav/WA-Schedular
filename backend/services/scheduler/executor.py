"""Schedule execution logic"""
from datetime import datetime, timezone
from core.database import get_database
from core.logging import logger
from services.whatsapp.message_sender import send_whatsapp_message
from services.telegram.sender import send_telegram_notification
from models.message_log import MessageLog


async def execute_scheduled_message(schedule_id: str):
    """Execute a scheduled message - called by APScheduler"""
    logger.info(f"⏰ EXECUTING scheduled message: {schedule_id}")
    try:
        database = await get_database()
        schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
        
        if not schedule:
            logger.warning(f"⚠️ Schedule not found: {schedule_id}")
            return
            
        if not schedule.get('is_active'):
            logger.info(f"⏸️ Schedule is inactive, skipping: {schedule_id}")
            return
        
        contact_name = schedule.get('contact_name', 'Unknown')
        contact_phone = schedule.get('contact_phone')
        message = schedule.get('message', '')
        
        logger.info(f"📤 Sending to {contact_name} ({contact_phone}): {message[:50]}...")
        
        # Send the message
        result = await send_whatsapp_message(contact_phone, message)
        
        status = "sent" if result.get('success') else "failed"
        
        if result.get('success'):
            logger.info(f"✅ Message sent successfully: {schedule_id} -> {contact_name}")
        else:
            logger.error(f"❌ Message failed: {schedule_id} -> {contact_name}: {result.get('error')}")
        
        # Log the message
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
        
        # Update last run
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": {"last_run": datetime.now(timezone.utc).isoformat()}}
        )
        
        # If one-time schedule, mark as completed
        if schedule.get('schedule_type') == 'once':
            await database.schedules.update_one(
                {"id": schedule_id},
                {"$set": {"is_active": False, "completed_at": datetime.now(timezone.utc).isoformat()}}
            )
            logger.info(f"📝 One-time schedule marked complete: {schedule_id}")
        
        # Send Telegram notification if enabled
        await send_telegram_notification(
            f"{'✅' if status == 'sent' else '❌'} Scheduled message {status}\n\n"
            f"📞 {schedule['contact_name']}\n"
            f"💬 {schedule['message'][:100]}"
        )
                
    except Exception as e:
        logger.error(f"❌ Execute scheduled message error: {e}", exc_info=True)
