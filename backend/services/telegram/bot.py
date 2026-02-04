"""Telegram bot polling and management"""
import asyncio
import httpx
from core.logging import logger
from core.database import get_database
from . import state
from .commands import process_telegram_command


async def telegram_polling_loop():
    """Long-polling loop for Telegram updates"""
    while state.telegram_bot_running:
        try:
            database = await get_database()
            settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
            
            if not settings or not settings.get('telegram_enabled') or not settings.get('telegram_token'):
                await asyncio.sleep(10)
                continue
                
            token = settings['telegram_token']
            
            async with httpx.AsyncClient() as http_client:
                response = await http_client.get(
                    f"https://api.telegram.org/bot{token}/getUpdates",
                    params={
                        "offset": state.telegram_last_update_id + 1,
                        "timeout": 30
                    },
                    timeout=35.0
                )
                
                if response.status_code != 200:
                    logger.error(f"Telegram API error: {response.status_code}")
                    await asyncio.sleep(5)
                    continue
                    
                data = response.json()
                
                if not data.get('ok'):
                    logger.error(f"Telegram API returned error: {data}")
                    await asyncio.sleep(5)
                    continue
                
                for update in data.get('result', []):
                    state.telegram_last_update_id = update['update_id']
                    
                    message = update.get('message', {})
                    text = message.get('text', '')
                    chat_id = str(message.get('chat', {}).get('id', ''))
                    
                    if text and chat_id:
                        await process_telegram_command(token, chat_id, text)
                        
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Telegram polling error: {e}")
            await asyncio.sleep(5)


async def start_telegram_bot():
    """Start the Telegram bot polling"""
    if state.telegram_polling_task and not state.telegram_polling_task.done():
        return
        
    state.telegram_bot_running = True
    state.telegram_polling_task = asyncio.create_task(telegram_polling_loop())
    logger.info("Telegram bot polling started")


async def stop_telegram_bot():
    """Stop the Telegram bot polling"""
    state.telegram_bot_running = False
    if state.telegram_polling_task:
        state.telegram_polling_task.cancel()
        try:
            await state.telegram_polling_task
        except asyncio.CancelledError:
            pass
    logger.info("Telegram bot polling stopped")
