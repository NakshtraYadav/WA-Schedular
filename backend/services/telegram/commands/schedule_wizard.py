"""Schedule creation wizard for Telegram"""
import uuid
import re
from datetime import datetime, timezone, timedelta
from apscheduler.triggers.date import DateTrigger
from apscheduler.triggers.cron import CronTrigger
from core.database import get_database
from core.scheduler import scheduler
from services.telegram.sender import send_telegram_message
from services.telegram.state import telegram_user_state, set_user_state, clear_user_state
from services.scheduler.presets import TELEGRAM_SCHEDULE_PRESETS


async def handle_create(token: str, chat_id: str):
    """Handle /create command - start schedule wizard"""
    set_user_state(chat_id, {"step": "search_contact", "data": {}})
    
    await send_telegram_message(token, chat_id,
        "📅 <b>Create Schedule - Step 1/4</b>\n\n"
        "Type the <b>name</b> of the contact to search:\n"
        "(partial match works, e.g., 'john' finds 'John Doe')\n\n"
        "/cancel to abort"
    )


async def handle_wizard_step(token: str, chat_id: str, text: str):
    """Handle wizard flow steps"""
    state = telegram_user_state.get(chat_id)
    if not state:
        return
    
    step = state["step"]
    database = await get_database()
    
    if step == "search_contact":
        await _handle_search_contact(token, chat_id, text, state, database)
    elif step == "pick_contact":
        await _handle_pick_contact(token, chat_id, text, state)
    elif step == "enter_message":
        await _handle_enter_message(token, chat_id, text, state)
    elif step == "select_schedule":
        await _handle_select_schedule(token, chat_id, text, state)
    elif step == "select_time":
        await _handle_select_time(token, chat_id, text, state)
    elif step == "confirm":
        await _handle_confirm(token, chat_id, text, state, database)


async def _handle_search_contact(token: str, chat_id: str, text: str, state: dict, database):
    query = text.strip()
    if len(query) < 2:
        await send_telegram_message(token, chat_id, "❌ Too short. Enter at least 2 characters.")
        return
    
    contacts = await database.contacts.find(
        {"name": {"$regex": query, "$options": "i"}},
        {"_id": 0}
    ).to_list(10)
    
    if not contacts:
        await send_telegram_message(token, chat_id, 
            f"❌ No contacts found for '{query}'\n\nTry another name or /cancel"
        )
        return
    
    if len(contacts) == 1:
        contact = contacts[0]
        state["data"]["contact"] = contact
        state["step"] = "enter_message"
        
        await send_telegram_message(token, chat_id, 
            f"✅ Selected: <b>{contact['name']}</b>\n\n"
            "📅 <b>Step 2/4</b>\n"
            "Enter the message to send:\n\n"
            "/cancel to abort"
        )
    else:
        state["data"]["search_results"] = contacts
        state["step"] = "pick_contact"
        
        lines = [f"🔍 Found {len(contacts)} contacts:\n"]
        for i, c in enumerate(contacts, 1):
            lines.append(f"<b>{i}.</b> {c['name']} ({c['phone']})")
        lines.append("\nReply with number to select, or /cancel")
        await send_telegram_message(token, chat_id, "\n".join(lines))


async def _handle_pick_contact(token: str, chat_id: str, text: str, state: dict):
    try:
        idx = int(text.strip()) - 1
        contacts = state["data"].get("search_results", [])
        if 0 <= idx < len(contacts):
            contact = contacts[idx]
            state["data"]["contact"] = contact
            state["step"] = "enter_message"
            del state["data"]["search_results"]
            
            await send_telegram_message(token, chat_id, 
                f"✅ Selected: <b>{contact['name']}</b>\n\n"
                "📅 <b>Step 2/4</b>\n"
                "Enter the message to send:\n\n"
                "/cancel to abort"
            )
        else:
            await send_telegram_message(token, chat_id, "❌ Invalid number. Try again.")
    except ValueError:
        await send_telegram_message(token, chat_id, "❌ Please enter a number.")


async def _handle_enter_message(token: str, chat_id: str, text: str, state: dict):
    state["data"]["message"] = text.strip()
    state["step"] = "select_schedule"
    
    lines = ["📅 <b>Step 3/4</b>\n", "Select schedule type:\n"]
    for key, preset in TELEGRAM_SCHEDULE_PRESETS.items():
        lines.append(f"<b>{key}.</b> {preset['label']} - {preset['desc']}")
    lines.append("\n/cancel to abort")
    await send_telegram_message(token, chat_id, "\n".join(lines))


async def _handle_select_schedule(token: str, chat_id: str, text: str, state: dict):
    if text.strip() in TELEGRAM_SCHEDULE_PRESETS:
        preset = TELEGRAM_SCHEDULE_PRESETS[text.strip()]
        state["data"]["preset"] = preset
        state["data"]["preset_key"] = text.strip()
        
        if preset["cron"] is None:
            state["step"] = "confirm"
            contact = state["data"]["contact"]
            message = state["data"]["message"]
            
            await send_telegram_message(token, chat_id,
                f"📅 <b>Step 4/4 - Confirm</b>\n\n"
                f"📞 Contact: <b>{contact['name']}</b>\n"
                f"💬 Message: {message[:50]}{'...' if len(message) > 50 else ''}\n"
                f"⏰ Schedule: <b>Once (in 1 hour)</b>\n\n"
                "Reply <b>yes</b> to confirm or /cancel to abort"
            )
        else:
            state["step"] = "select_time"
            await send_telegram_message(token, chat_id,
                "📅 <b>Step 4/4</b>\n\n"
                "Enter time in HH:MM format (24h):\n"
                "Example: <b>09:00</b> or <b>18:30</b>\n\n"
                "/cancel to abort"
            )
    else:
        await send_telegram_message(token, chat_id, "❌ Invalid option. Enter 1-6.")


async def _handle_select_time(token: str, chat_id: str, text: str, state: dict):
    time_match = re.match(r'^(\d{1,2}):(\d{2})$', text.strip())
    if time_match:
        hour, minute = int(time_match.group(1)), int(time_match.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            state["data"]["time"] = f"{hour:02d}:{minute:02d}"
            state["step"] = "confirm"
            
            contact = state["data"]["contact"]
            message = state["data"]["message"]
            preset = state["data"]["preset"]
            time_str = state["data"]["time"]
            
            await send_telegram_message(token, chat_id,
                f"📅 <b>Confirm Schedule</b>\n\n"
                f"📞 Contact: <b>{contact['name']}</b>\n"
                f"💬 Message: {message[:50]}{'...' if len(message) > 50 else ''}\n"
                f"⏰ Schedule: <b>{preset['label']}</b> at <b>{time_str}</b>\n\n"
                "Reply <b>yes</b> to confirm or /cancel to abort"
            )
        else:
            await send_telegram_message(token, chat_id, "❌ Invalid time. Use HH:MM format (00:00 - 23:59)")
    else:
        await send_telegram_message(token, chat_id, "❌ Invalid format. Use HH:MM (e.g., 09:00)")


async def _handle_confirm(token: str, chat_id: str, text: str, state: dict, database):
    # Import here to avoid circular import
    from services.scheduler.executor import execute_scheduled_message
    
    if text.strip().lower() == "yes":
        contact = state["data"]["contact"]
        message = state["data"]["message"]
        preset = state["data"]["preset"]
        
        schedule_id = str(uuid.uuid4())
        schedule_data = {
            "id": schedule_id,
            "contact_id": contact["id"],
            "contact_name": contact["name"],
            "contact_phone": contact["phone"],
            "message": message,
            "is_active": True,
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        
        if preset["cron"] is None:
            scheduled_time = datetime.now(timezone.utc) + timedelta(hours=1)
            schedule_data["schedule_type"] = "once"
            schedule_data["scheduled_time"] = scheduled_time.isoformat()
            schedule_data["cron_description"] = f"Once at {scheduled_time.strftime('%H:%M')}"
            
            try:
                scheduler.add_job(
                    execute_scheduled_message,
                    DateTrigger(run_date=scheduled_time),
                    args=[schedule_id],
                    id=schedule_id,
                    replace_existing=True
                )
            except Exception:
                pass
        else:
            time_str = state["data"].get("time", "09:00")
            hour, minute = time_str.split(":")
            cron = preset["cron"].replace("{H}", hour)
            if "{M}" in cron:
                cron = cron.replace("{M}", minute)
            else:
                cron = cron.replace(f"0 {hour}", f"{minute} {hour}")
            
            schedule_data["schedule_type"] = "recurring"
            schedule_data["cron_expression"] = cron
            schedule_data["cron_description"] = f"{preset['label']} at {time_str}"
            
            try:
                scheduler.add_job(
                    execute_scheduled_message,
                    CronTrigger.from_crontab(cron),
                    args=[schedule_id],
                    id=schedule_id,
                    replace_existing=True
                )
            except Exception:
                pass
        
        await database.schedules.insert_one(schedule_data)
        clear_user_state(chat_id)
        
        await send_telegram_message(token, chat_id,
            f"✅ <b>Schedule Created!</b>\n\n"
            f"📞 {contact['name']}\n"
            f"⏰ {schedule_data.get('cron_description', 'Scheduled')}\n\n"
            "View all schedules with /schedules"
        )
    else:
        await send_telegram_message(token, chat_id, "Reply <b>yes</b> to confirm or /cancel to abort")
