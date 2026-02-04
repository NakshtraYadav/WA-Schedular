"""Status-related telegram commands"""
import httpx
from core.database import get_database
from core.config import WA_SERVICE_URL
from services.telegram.sender import send_telegram_message


async def handle_status(token: str, chat_id: str):
    """Handle /status command"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=5.0)
            wa_status = response.json()
            
        if wa_status.get("isReady"):
            info = wa_status.get("clientInfo", {})
            name = info.get("pushname", "Unknown")
            phone = info.get("phone", "Unknown")
            msg = f"🟢 <b>WhatsApp Connected</b>\n\nName: {name}\nPhone: {phone}"
        elif wa_status.get("isInitializing"):
            msg = "🟡 <b>WhatsApp Initializing...</b>\n\nPlease wait for QR code."
        elif wa_status.get("hasQrCode"):
            msg = "🟡 <b>Waiting for QR Scan</b>\n\nOpen the web dashboard to scan QR code."
        else:
            error = wa_status.get("error", "Unknown")
            msg = f"🔴 <b>WhatsApp Disconnected</b>\n\nError: {error}"
    except:
        msg = "🔴 <b>WhatsApp Service Unavailable</b>"
    await send_telegram_message(token, chat_id, msg)


async def handle_contacts(token: str, chat_id: str):
    """Handle /contacts command"""
    database = await get_database()
    total_count = await database.contacts.count_documents({})
    contacts = await database.contacts.find({}, {"_id": 0}).limit(20).to_list(20)
    if contacts:
        lines = [f"📋 <b>Contacts</b> ({total_count} total)\n"]
        for c in contacts[:20]:
            lines.append(f"• {c['name']}: {c['phone']}")
        if total_count > 20:
            lines.append(f"\n... and {total_count - 20} more")
            lines.append("Use /search &lt;name&gt; to find specific contacts")
        response = "\n".join(lines)
    else:
        response = "📋 <b>No contacts found</b>\n\nAdd contacts via the web dashboard or sync from WhatsApp."
    await send_telegram_message(token, chat_id, response)


async def handle_schedules(token: str, chat_id: str):
    """Handle /schedules command"""
    database = await get_database()
    schedules = await database.schedules.find({"is_active": True}, {"_id": 0}).to_list(20)
    if schedules:
        lines = ["📅 <b>Active Schedules</b>\n"]
        for s in schedules:
            type_icon = "🔄" if s['schedule_type'] == "recurring" else "⏰"
            schedule_info = s.get('cron_description') or s.get('scheduled_time', '')[:16]
            lines.append(f"{type_icon} {s['contact_name']}: {schedule_info}")
        response = "\n".join(lines)
    else:
        response = "📅 <b>No active schedules</b>\n\nCreate schedules via the web dashboard."
    await send_telegram_message(token, chat_id, response)


async def handle_logs(token: str, chat_id: str):
    """Handle /logs command"""
    database = await get_database()
    logs = await database.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(10)
    if logs:
        lines = ["📝 <b>Recent Messages</b>\n"]
        for l in logs:
            status_icon = "✅" if l['status'] == "sent" else "❌"
            lines.append(f"{status_icon} {l['contact_name']}: {l['message'][:30]}...")
        response = "\n".join(lines)
    else:
        response = "📝 <b>No message history</b>"
    await send_telegram_message(token, chat_id, response)
