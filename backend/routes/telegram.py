"""Telegram routes"""
from fastapi import APIRouter
import httpx
from core.database import get_database
from services.telegram import start_telegram_bot, stop_telegram_bot, send_telegram_message
from services.telegram.state import telegram_bot_running

router = APIRouter(prefix="/telegram")


@router.post("/test")
async def test_telegram_bot():
    """Test Telegram bot connection"""
    database = await get_database()
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    
    if not settings or not settings.get('telegram_token'):
        return {"success": False, "error": "Telegram bot token not configured"}
    
    token = settings['telegram_token']
    
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(
                f"https://api.telegram.org/bot{token}/getMe",
                timeout=10.0
            )
            data = response.json()
            
            if data.get('ok'):
                bot_info = data.get('result', {})
                
                # Try to send test message if chat_id is set
                chat_id = settings.get('telegram_chat_id')
                if chat_id:
                    success = await send_telegram_message(
                        token, chat_id,
                        "✅ <b>Test Successful!</b>\n\nYour WA Scheduler bot is working correctly."
                    )
                    return {
                        "success": True,
                        "bot_name": bot_info.get('first_name'),
                        "bot_username": bot_info.get('username'),
                        "message_sent": success
                    }
                
                return {
                    "success": True,
                    "bot_name": bot_info.get('first_name'),
                    "bot_username": bot_info.get('username'),
                    "message_sent": False,
                    "note": "Send /start to the bot to set chat ID"
                }
            else:
                return {"success": False, "error": data.get('description', 'Unknown error')}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.get("/status")
async def get_telegram_status():
    """Get Telegram bot status"""
    database = await get_database()
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    
    return {
        "enabled": settings.get('telegram_enabled', False) if settings else False,
        "has_token": bool(settings.get('telegram_token')) if settings else False,
        "has_chat_id": bool(settings.get('telegram_chat_id')) if settings else False,
        "polling_active": telegram_bot_running
    }
