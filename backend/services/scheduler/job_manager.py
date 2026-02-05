"""Schedule job management"""
from datetime import datetime, timezone
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.date import DateTrigger
from core.scheduler import scheduler
from core.database import get_database
from core.logging import logger
from .executor import execute_scheduled_message


def add_schedule_job(schedule_id: str, schedule_type: str, scheduled_time=None, cron_expression=None):
    """Add a job to the scheduler"""
    try:
        if schedule_type == "once" and scheduled_time:
            scheduler.add_job(
                execute_scheduled_message,
                DateTrigger(run_date=scheduled_time),
                args=[schedule_id],
                id=schedule_id,
                replace_existing=True
            )
            logger.info(f"📅 One-time job scheduled: {schedule_id} at {scheduled_time}")
        elif schedule_type == "recurring" and cron_expression:
            scheduler.add_job(
                execute_scheduled_message,
                CronTrigger.from_crontab(cron_expression),
                args=[schedule_id],
                id=schedule_id,
                replace_existing=True
            )
            logger.info(f"🔄 Recurring job scheduled: {schedule_id} cron={cron_expression}")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to add job to scheduler: {e}", exc_info=True)
        return False


def remove_schedule_job(schedule_id: str):
    """Remove a job from the scheduler"""
    try:
        scheduler.remove_job(schedule_id)
        logger.info(f"🗑️ Job removed from scheduler: {schedule_id}")
        return True
    except Exception:
        return False


async def reload_schedules():
    """Reload all active schedules from database"""
    logger.info("🔄 Reloading schedules from database...")
    
    try:
        database = await get_database()
        if database is None:
            logger.warning("⚠️ Database not available, cannot reload schedules")
            return 0
        
        schedules = await database.schedules.find({"is_active": True}, {"_id": 0}).to_list(1000)
        loaded = 0
        skipped = 0
        
        for schedule in schedules:
            try:
                schedule_id = schedule['id']
                schedule_type = schedule.get('schedule_type')
                
                if schedule_type == "once" and schedule.get('scheduled_time'):
                    sched_time = schedule['scheduled_time']
                    if isinstance(sched_time, str):
                        sched_time = datetime.fromisoformat(sched_time)
                    
                    # Make timezone aware if naive
                    if sched_time.tzinfo is None:
                        sched_time = sched_time.replace(tzinfo=timezone.utc)
                    
                    if sched_time > datetime.now(timezone.utc):
                        add_schedule_job(schedule_id, 'once', scheduled_time=sched_time)
                        loaded += 1
                    else:
                        logger.debug(f"⏭️ Skipping past one-time schedule: {schedule_id}")
                        skipped += 1
                        
                elif schedule_type == "recurring" and schedule.get('cron_expression'):
                    add_schedule_job(
                        schedule_id,
                        'recurring',
                        cron_expression=schedule['cron_expression']
                    )
                    loaded += 1
                else:
                    logger.warning(f"⚠️ Invalid schedule config: {schedule_id}")
                    skipped += 1
                    
            except Exception as e:
                logger.warning(f"⚠️ Failed to reload schedule {schedule.get('id', '?')}: {e}")
                skipped += 1
        
        total_jobs = len(scheduler.get_jobs())
        logger.info(f"✅ Schedule reload complete: {loaded} loaded, {skipped} skipped, {total_jobs} total jobs")
        return loaded
        
    except Exception as e:
        logger.error(f"❌ Could not reload schedules: {e}", exc_info=True)
        return 0
