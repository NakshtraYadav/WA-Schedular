"""Telegram user state management"""

# Global state for Telegram bot
telegram_last_update_id = 0
telegram_polling_task = None
telegram_bot_running = False
telegram_user_state = {}  # {chat_id: {step: '', data: {}}}

def get_user_state(chat_id: str) -> dict:
    """Get user state for chat"""
    return telegram_user_state.get(chat_id)

def set_user_state(chat_id: str, state: dict):
    """Set user state for chat"""
    telegram_user_state[chat_id] = state

def clear_user_state(chat_id: str):
    """Clear user state for chat"""
    if chat_id in telegram_user_state:
        del telegram_user_state[chat_id]
