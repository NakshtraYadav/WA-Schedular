"""Dashboard routes"""
from fastapi import APIRouter
from datetime import datetime
from core.database import get_database

router = APIRouter(prefix="/dashboard")


@router.get("/stats")
async def get_dashboard_stats():
    """Get dashboard statistics"""
    database = await get_database()
    
    contacts_count = await database.contacts.count_documents({})
    templates_count = await database.templates.count_documents({})
    active_schedules = await database.schedules.count_documents({"is_active": True})
    total_messages = await database.logs.count_documents({})
    sent_messages = await database.logs.count_documents({"status": "sent"})
    failed_messages = await database.logs.count_documents({"status": "failed"})
    
    recent_logs = await database.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(5)
    for log_entry in recent_logs:
        if isinstance(log_entry.get('sent_at'), str):
            log_entry['sent_at'] = datetime.fromisoformat(log_entry['sent_at'])
    
    upcoming = await database.schedules.find({"is_active": True}, {"_id": 0}).to_list(5)
    for schedule in upcoming:
        for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
            if isinstance(schedule.get(field), str):
                schedule[field] = datetime.fromisoformat(schedule[field])
    
    return {
        "contacts_count": contacts_count,
        "templates_count": templates_count,
        "active_schedules": active_schedules,
        "total_messages": total_messages,
        "sent_messages": sent_messages,
        "failed_messages": failed_messages,
        "recent_logs": recent_logs,
        "upcoming_schedules": upcoming
    }
