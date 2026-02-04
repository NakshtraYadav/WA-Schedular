"""Command router for Telegram bot"""
from services.telegram.state import telegram_user_state
from services.telegram.sender import send_telegram_message
from .base import handle_start, handle_help, handle_cancel
from .status import handle_status, handle_contacts, handle_schedules, handle_logs
from .messaging import handle_send, handle_search
from .schedule_wizard import handle_create, handle_wizard_step


async def process_telegram_command(token: str, chat_id: str, text: str):
    """Process incoming Telegram commands"""
    text = text.strip()
    
    # Basic commands
    if text == "/start":
        await handle_start(token, chat_id)
    elif text == "/help":
        await handle_help(token, chat_id)
    elif text == "/cancel":
        await handle_cancel(token, chat_id)
    elif text == "/status":
        await handle_status(token, chat_id)
    elif text == "/contacts":
        await handle_contacts(token, chat_id)
    elif text == "/schedules":
        await handle_schedules(token, chat_id)
    elif text == "/logs":
        await handle_logs(token, chat_id)
    elif text == "/create":
        await handle_create(token, chat_id)
    elif text.startswith("/send "):
        await handle_send(token, chat_id, text)
    elif text.startswith("/search "):
        await handle_search(token, chat_id, text)
    elif chat_id in telegram_user_state:
        # Handle wizard flow
        await handle_wizard_step(token, chat_id, text)
    else:
        await send_telegram_message(token, chat_id, "❓ Unknown command. Type /help for available commands.")
