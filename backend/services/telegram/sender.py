"""Telegram message sending functionality"""
import httpx
from core.logging import logger
from core.database import get_database


async def send_telegram_message(token: str, chat_id: str, text: str, parse_mode: str = "HTML") -> bool:
    """Send a message via Telegram bot"""
    if not token or not chat_id:
        return False
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(
                f"https://api.telegram.org/bot{token}/sendMessage",
                json={
                    "chat_id": chat_id,
                    "text": text,
                    "parse_mode": parse_mode
                },
                timeout=10.0
            )
            return response.status_code == 200
    except Exception as e:
        logger.error(f"Telegram send error: {e}")
        return False


async def send_telegram_notification(message: str):
    """Send a notification to the configured Telegram chat"""
    try:
        database = await get_database()
        settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
        if settings and settings.get('telegram_enabled') and settings.get('telegram_token'):
            await send_telegram_message(
                settings['telegram_token'],
                settings.get('telegram_chat_id', ''),
                message
            )
    except Exception:
        pass
