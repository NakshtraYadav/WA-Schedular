"""Schedules routes"""
from fastapi import APIRouter, HTTPException
from typing import List
from datetime import datetime, timezone
from core.database import get_database
from core.scheduler import scheduler
from core.logging import logger
from models.schedule import ScheduledMessage, ScheduledMessageCreate
from models.message_log import MessageLog
from services.scheduler.executor import execute_scheduled_message
from services.scheduler.job_manager import add_schedule_job, remove_schedule_job
from services.whatsapp.message_sender import send_whatsapp_message

router = APIRouter(prefix="/schedules")


@router.get("", response_model=List[ScheduledMessage])
async def get_schedules():
    """Get all scheduled messages"""
    database = await get_database()
    schedules = await database.schedules.find({}, {"_id": 0}).to_list(1000)
    for s in schedules:
        for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
            if isinstance(s.get(field), str):
                s[field] = datetime.fromisoformat(s[field])
    return schedules


@router.post("", response_model=ScheduledMessage)
async def create_schedule(data: ScheduledMessageCreate):
    """Create a new scheduled message"""
    logger.info(f"📅 Creating schedule: type={data.schedule_type}, contact={data.contact_id}")
    
    database = await get_database()
    contact = await database.contacts.find_one({"id": data.contact_id}, {"_id": 0})
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    schedule = ScheduledMessage(
        contact_id=data.contact_id,
        contact_name=contact['name'],
        contact_phone=contact['phone'],
        message=data.message,
        schedule_type=data.schedule_type,
        scheduled_time=data.scheduled_time,
        cron_expression=data.cron_expression,
        cron_description=data.cron_description
    )
    
    doc = schedule.model_dump()
    for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
        if doc.get(field):
            doc[field] = doc[field].isoformat()
    
    await database.schedules.insert_one(doc)
    logger.info(f"✅ Schedule saved to DB: {schedule.id}")
    
    # Add to scheduler
    add_schedule_job(
        schedule.id,
        data.schedule_type,
        scheduled_time=data.scheduled_time,
        cron_expression=data.cron_expression
    )
    
    return schedule


@router.put("/{schedule_id}/toggle")
async def toggle_schedule(schedule_id: str):
    """Toggle a schedule active/inactive"""
    database = await get_database()
    schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    new_status = not schedule.get('is_active', True)
    await database.schedules.update_one({"id": schedule_id}, {"$set": {"is_active": new_status}})
    
    try:
        if new_status:
            if schedule['schedule_type'] == "once" and schedule.get('scheduled_time'):
                sched_time = schedule['scheduled_time']
                if isinstance(sched_time, str):
                    sched_time = datetime.fromisoformat(sched_time)
                add_schedule_job(schedule_id, 'once', scheduled_time=sched_time)
            elif schedule['schedule_type'] == "recurring" and schedule.get('cron_expression'):
                add_schedule_job(schedule_id, 'recurring', cron_expression=schedule['cron_expression'])
        else:
            remove_schedule_job(schedule_id)
    except Exception as e:
        logger.warning(f"Scheduler update warning: {e}")
    
    return {"success": True, "is_active": new_status}


@router.delete("/{schedule_id}")
async def delete_schedule(schedule_id: str):
    """Delete a scheduled message"""
    database = await get_database()
    result = await database.schedules.delete_one({"id": schedule_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    remove_schedule_job(schedule_id)
    return {"success": True}


@router.put("/{schedule_id}")
async def update_schedule(schedule_id: str, data: ScheduledMessageCreate):
    """Update an existing scheduled message"""
    logger.info(f"📝 Updating schedule: {schedule_id}")
    
    database = await get_database()
    existing = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    # Get contact info
    contact = await database.contacts.find_one({"id": data.contact_id}, {"_id": 0})
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    # Build update document
    update_doc = {
        "contact_id": data.contact_id,
        "contact_name": contact['name'],
        "contact_phone": contact['phone'],
        "message": data.message,
        "schedule_type": data.schedule_type,
        "scheduled_time": data.scheduled_time.isoformat() if data.scheduled_time else None,
        "cron_expression": data.cron_expression,
        "cron_description": data.cron_description
    }
    
    await database.schedules.update_one({"id": schedule_id}, {"$set": update_doc})
    logger.info(f"✅ Schedule updated: {schedule_id}")
    
    # Update scheduler job
    remove_schedule_job(schedule_id)
    if existing.get('is_active', True):
        add_schedule_job(
            schedule_id,
            data.schedule_type,
            scheduled_time=data.scheduled_time,
            cron_expression=data.cron_expression
        )
    
    # Return updated schedule
    updated = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
        if isinstance(updated.get(field), str):
            updated[field] = datetime.fromisoformat(updated[field])
    
    return updated


@router.get("/{schedule_id}")
async def get_schedule(schedule_id: str):
    """Get a single schedule by ID"""
    database = await get_database()
    schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
        if isinstance(schedule.get(field), str):
            schedule[field] = datetime.fromisoformat(schedule[field])
    
    return schedule


@router.get("/debug")
async def debug_schedules():
    """Debug endpoint to see scheduler status"""
    database = await get_database()
    
    db_schedules = await database.schedules.find({}, {"_id": 0}).to_list(100)
    
    scheduler_jobs = []
    for job in scheduler.get_jobs():
        next_run = job.next_run_time
        scheduler_jobs.append({
            "id": job.id,
            "name": job.name,
            "next_run": next_run.isoformat() if next_run else None,
            "trigger": str(job.trigger)
        })
    
    return {
        "database": {
            "total_schedules": len(db_schedules),
            "active_schedules": len([s for s in db_schedules if s.get('is_active')]),
            "schedules": [{
                "id": s["id"],
                "contact": s.get("contact_name"),
                "type": s.get("schedule_type"),
                "is_active": s.get("is_active"),
                "cron": s.get("cron_expression"),
                "scheduled_time": s.get("scheduled_time"),
                "last_run": s.get("last_run")
            } for s in db_schedules]
        },
        "scheduler": {
            "running": scheduler.running,
            "job_count": len(scheduler_jobs),
            "jobs": scheduler_jobs
        },
        "server_time": {
            "utc": datetime.now(timezone.utc).isoformat(),
            "local": datetime.now().isoformat()
        }
    }


@router.post("/test-run/{schedule_id}")
async def test_run_schedule(schedule_id: str):
    """Manually trigger a schedule to test if it works"""
    logger.info(f"🧪 TEST RUN: {schedule_id}")
    
    database = await get_database()
    schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    await execute_scheduled_message(schedule_id)
    
    return {
        "success": True,
        "message": f"Test run executed for schedule {schedule_id}",
        "schedule": {
            "contact": schedule.get("contact_name"),
            "phone": schedule.get("contact_phone"),
            "message_preview": schedule.get("message", "")[:50]
        }
    }


# Send Now endpoint
@router.post("/send-now")
async def send_message_now(contact_id: str, message: str):
    """Send a message immediately"""
    database = await get_database()
    contact = await database.contacts.find_one({"id": contact_id}, {"_id": 0})
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    result = await send_whatsapp_message(contact['phone'], message)
    
    log = MessageLog(
        contact_id=contact_id,
        contact_name=contact['name'],
        contact_phone=contact['phone'],
        message=message,
        status="sent" if result.get('success') else "failed",
        error_message=result.get('error')
    )
    log_doc = log.model_dump()
    log_doc['sent_at'] = log_doc['sent_at'].isoformat()
    await database.logs.insert_one(log_doc)
    
    return result
