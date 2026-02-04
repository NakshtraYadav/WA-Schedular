"""Base telegram commands: /start, /help, /cancel"""
from core.database import get_database
from services.telegram.sender import send_telegram_message
from services.telegram.state import clear_user_state, telegram_user_state


async def handle_start(token: str, chat_id: str):
    """Handle /start command"""
    database = await get_database()
    await database.settings.update_one(
        {"id": "settings"},
        {"$set": {"telegram_chat_id": chat_id}},
        upsert=True
    )
    response = (
        "🟢 <b>WA Scheduler Bot Connected!</b>\n\n"
        "Your Chat ID has been saved automatically.\n\n"
        "<b>Available Commands:</b>\n"
        "/status - WhatsApp connection status\n"
        "/contacts - List all contacts\n"
        "/schedules - List active schedules\n"
        "/send &lt;name&gt; &lt;message&gt; - Send message now\n"
        "/help - Show this help"
    )
    await send_telegram_message(token, chat_id, response)


async def handle_help(token: str, chat_id: str):
    """Handle /help command"""
    response = (
        "📱 <b>WA Scheduler Commands</b>\n\n"
        "/status - Check WhatsApp connection\n"
        "/contacts - List contacts (shows first 20)\n"
        "/search &lt;name&gt; - Search contacts\n"
        "/schedules - List active schedules\n"
        "/send &lt;name&gt; &lt;message&gt; - Send message now\n"
        "/create - Create a new schedule\n"
        "/cancel - Cancel current operation\n"
        "/logs - Recent message history\n"
        "/help - Show this help"
    )
    await send_telegram_message(token, chat_id, response)


async def handle_cancel(token: str, chat_id: str):
    """Handle /cancel command"""
    if chat_id in telegram_user_state:
        clear_user_state(chat_id)
        await send_telegram_message(token, chat_id, "❌ Operation cancelled.")
    else:
        await send_telegram_message(token, chat_id, "ℹ️ Nothing to cancel.")
