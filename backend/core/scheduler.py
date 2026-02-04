"""APScheduler configuration and instance"""
from apscheduler.schedulers.asyncio import AsyncIOScheduler

# Create scheduler instance
scheduler = AsyncIOScheduler()

def start_scheduler():
    """Start the scheduler"""
    if not scheduler.running:
        scheduler.start()

def shutdown_scheduler():
    """Shutdown the scheduler"""
    if scheduler.running:
        scheduler.shutdown()
