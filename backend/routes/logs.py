"""Message logs routes"""
from fastapi import APIRouter
from typing import List
from datetime import datetime
from core.database import get_database
from models.message_log import MessageLog

router = APIRouter(prefix="/logs")


@router.get("", response_model=List[MessageLog])
async def get_logs(limit: int = 100):
    """Get message logs"""
    database = await get_database()
    logs = await database.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(limit)
    for l in logs:
        if isinstance(l.get('sent_at'), str):
            l['sent_at'] = datetime.fromisoformat(l['sent_at'])
    return logs


@router.delete("")
async def clear_logs():
    """Clear all logs"""
    database = await get_database()
    await database.logs.delete_many({})
    return {"success": True}
