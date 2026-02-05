"""Settings routes"""
from fastapi import APIRouter
from datetime import datetime, timezone
import pytz
from core.database import get_database
from models.settings import Settings, SettingsUpdate
from services.telegram import start_telegram_bot, stop_telegram_bot

router = APIRouter(prefix="/settings")


@router.get("", response_model=Settings)
async def get_settings():
    """Get application settings"""
    database = await get_database()
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    if not settings:
        try:
            from tzlocal import get_localzone_name
            system_tz = get_localzone_name()
        except Exception:
            system_tz = None
        default_settings = Settings(timezone=system_tz)
        settings = default_settings.model_dump()
        settings['updated_at'] = settings['updated_at'].isoformat()
        await database.settings.insert_one(settings)
        settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
    else:
        if isinstance(settings.get('updated_at'), str):
            settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
    return Settings(**settings)


@router.put("", response_model=Settings)
async def update_settings(data: SettingsUpdate):
    """Update application settings"""
    database = await get_database()
    
    update_data = data.model_dump()
    update_data['updated_at'] = datetime.now(timezone.utc).isoformat()
    
    await database.settings.update_one(
        {"id": "settings"},
        {"$set": update_data},
        upsert=True
    )
    
    # Start or stop Telegram bot based on settings
    if data.telegram_enabled and data.telegram_token:
        await start_telegram_bot()
    else:
        await stop_telegram_bot()
    
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    if isinstance(settings.get('updated_at'), str):
        settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
    return Settings(**settings)


@router.get("/timezone")
async def get_timezone_info():
    """Get system timezone and available timezones"""
    try:
        from tzlocal import get_localzone_name
        system_tz = get_localzone_name()
    except Exception:
        system_tz = "UTC"
    
    common_timezones = [
        "UTC", "America/New_York", "America/Chicago", "America/Denver",
        "America/Los_Angeles", "Europe/London", "Europe/Paris", "Europe/Berlin",
        "Asia/Tokyo", "Asia/Shanghai", "Asia/Kolkata", "Asia/Dubai",
        "Australia/Sydney", "Pacific/Auckland"
    ]
    
    return {
        "system_timezone": system_tz,
        "common_timezones": common_timezones,
        "all_timezones": pytz.common_timezones
    }
