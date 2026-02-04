"""Schedule job management"""
from datetime import datetime, timezone
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.date import DateTrigger
from core.scheduler import scheduler
from core.database import get_database, db
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
            logger.info(f"✅ One-time job added to scheduler: {schedule_id}")
        elif schedule_type == "recurring" and cron_expression:
            scheduler.add_job(
                execute_scheduled_message,
                CronTrigger.from_crontab(cron_expression),
                args=[schedule_id],
                id=schedule_id,
                replace_existing=True
            )
            logger.info(f"✅ Recurring job added to scheduler: {schedule_id}")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to add job to scheduler: {e}", exc_info=True)
        return False


def remove_schedule_job(schedule_id: str):
    """Remove a job from the scheduler"""
    try:
        scheduler.remove_job(schedule_id)
        return True
    except Exception:
        return False


async def reload_schedules():
    """Reload all active schedules from database"""
    if db is None:
        logger.warning("Database not available, cannot reload schedules")
        return
    
    try:
        schedules = await db.schedules.find({"is_active": True}, {"_id": 0}).to_list(1000)
        for schedule in schedules:
            try:
                if schedule['schedule_type'] == "once" and schedule.get('scheduled_time'):
                    sched_time = schedule['scheduled_time']
                    if isinstance(sched_time, str):
                        sched_time = datetime.fromisoformat(sched_time)
                    if sched_time > datetime.now(timezone.utc):
                        add_schedule_job(
                            schedule['id'],
                            'once',
                            scheduled_time=sched_time
                        )
                elif schedule['schedule_type'] == "recurring" and schedule.get('cron_expression'):
                    add_schedule_job(
                        schedule['id'],
                        'recurring',
                        cron_expression=schedule['cron_expression']
                    )
            except Exception as e:
                logger.warning(f"Failed to reload schedule {schedule['id']}: {e}")
        logger.info(f"Reloaded {len(schedules)} schedules")
    except Exception as e:
        logger.warning(f"Could not reload schedules: {e}")
