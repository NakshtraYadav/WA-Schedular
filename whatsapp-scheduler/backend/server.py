from fastapi import FastAPI, APIRouter, HTTPException, BackgroundTasks
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict, field_validator
from typing import List, Optional
import uuid
from datetime import datetime, timezone
import httpx
import asyncio
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.date import DateTrigger
import pytz
from tzlocal import get_localzone_name

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# WhatsApp service URL
WA_SERVICE_URL = os.environ.get('WA_SERVICE_URL', 'http://localhost:3001')

# Create the main app
app = FastAPI(title="WhatsApp Scheduler API")

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# Scheduler
scheduler = AsyncIOScheduler()

# Telegram polling state
telegram_polling_task = None
telegram_last_update_id = 0

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============== MODELS ==============

class Contact(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    phone: str
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class ContactCreate(BaseModel):
    name: str
    phone: str
    notes: Optional[str] = None
    
    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v):
        # Remove all non-digit except + at start
        cleaned = v.strip()
        if not cleaned:
            raise ValueError('Phone number is required')
        # Must start with + or digit, contain only digits after
        if cleaned[0] == '+':
            digits = cleaned[1:]
        else:
            digits = cleaned
        if not digits.isdigit():
            raise ValueError('Phone number must contain only digits (optionally starting with +)')
        if len(digits) < 7 or len(digits) > 15:
            raise ValueError('Phone number must be 7-15 digits')
        return cleaned

class MessageTemplate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    content: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class MessageTemplateCreate(BaseModel):
    title: str
    content: str

class ScheduledMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    contact_id: str
    contact_name: str
    contact_phone: str
    message: str
    schedule_type: str  # "once" or "recurring"
    scheduled_time: Optional[datetime] = None  # For one-time
    cron_expression: Optional[str] = None  # For recurring
    cron_description: Optional[str] = None
    is_active: bool = True
    last_run: Optional[datetime] = None
    next_run: Optional[datetime] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class ScheduledMessageCreate(BaseModel):
    contact_id: str
    message: str
    schedule_type: str
    scheduled_time: Optional[datetime] = None
    cron_expression: Optional[str] = None
    cron_description: Optional[str] = None

class MessageLog(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    contact_id: str
    contact_name: str
    contact_phone: str
    message: str
    status: str  # "sent", "failed", "pending"
    error_message: Optional[str] = None
    scheduled_message_id: Optional[str] = None
    sent_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class Settings(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = "settings"
    telegram_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: bool = False
    timezone: Optional[str] = None  # If None, uses system timezone
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class SettingsUpdate(BaseModel):
    telegram_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: bool = False
    timezone: Optional[str] = None

# ============== WHATSAPP STATUS ==============

@api_router.get("/whatsapp/status")
async def get_whatsapp_status():
    """Get WhatsApp connection status"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp status error: {e}")
        return {"isReady": False, "isAuthenticated": False, "hasQrCode": False, "error": str(e)}

@api_router.get("/whatsapp/qr")
async def get_whatsapp_qr():
    """Get WhatsApp QR code for authentication"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/qr", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp QR error: {e}")
        return {"qrCode": None, "error": str(e)}

@api_router.post("/whatsapp/logout")
async def logout_whatsapp():
    """Logout from WhatsApp"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/logout", timeout=10.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp logout error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.post("/whatsapp/simulate-connect")
async def simulate_whatsapp_connect():
    """Simulate WhatsApp connection (for demo/testing)"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/simulate-connect", timeout=10.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp simulate connect error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ============== CONTACTS ==============

@api_router.get("/contacts", response_model=List[Contact])
async def get_contacts():
    """Get all contacts"""
    contacts = await db.contacts.find({}, {"_id": 0}).to_list(1000)
    for c in contacts:
        if isinstance(c.get('created_at'), str):
            c['created_at'] = datetime.fromisoformat(c['created_at'])
    return contacts

@api_router.post("/contacts", response_model=Contact)
async def create_contact(input: ContactCreate):
    """Create a new contact"""
    contact = Contact(**input.model_dump())
    doc = contact.model_dump()
    doc['created_at'] = doc['created_at'].isoformat()
    await db.contacts.insert_one(doc)
    return contact

@api_router.put("/contacts/{contact_id}", response_model=Contact)
async def update_contact(contact_id: str, input: ContactCreate):
    """Update a contact"""
    existing = await db.contacts.find_one({"id": contact_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    update_data = input.model_dump()
    await db.contacts.update_one({"id": contact_id}, {"$set": update_data})
    
    updated = await db.contacts.find_one({"id": contact_id}, {"_id": 0})
    if isinstance(updated.get('created_at'), str):
        updated['created_at'] = datetime.fromisoformat(updated['created_at'])
    return Contact(**updated)

@api_router.delete("/contacts/{contact_id}")
async def delete_contact(contact_id: str):
    """Delete a contact"""
    result = await db.contacts.delete_one({"id": contact_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"success": True}

# ============== MESSAGE TEMPLATES ==============

@api_router.get("/templates", response_model=List[MessageTemplate])
async def get_templates():
    """Get all message templates"""
    templates = await db.templates.find({}, {"_id": 0}).to_list(1000)
    for t in templates:
        if isinstance(t.get('created_at'), str):
            t['created_at'] = datetime.fromisoformat(t['created_at'])
    return templates

@api_router.post("/templates", response_model=MessageTemplate)
async def create_template(input: MessageTemplateCreate):
    """Create a new message template"""
    template = MessageTemplate(**input.model_dump())
    doc = template.model_dump()
    doc['created_at'] = doc['created_at'].isoformat()
    await db.templates.insert_one(doc)
    return template

@api_router.put("/templates/{template_id}", response_model=MessageTemplate)
async def update_template(template_id: str, input: MessageTemplateCreate):
    """Update a template"""
    existing = await db.templates.find_one({"id": template_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=404, detail="Template not found")
    
    update_data = input.model_dump()
    await db.templates.update_one({"id": template_id}, {"$set": update_data})
    
    updated = await db.templates.find_one({"id": template_id}, {"_id": 0})
    if isinstance(updated.get('created_at'), str):
        updated['created_at'] = datetime.fromisoformat(updated['created_at'])
    return MessageTemplate(**updated)

@api_router.delete("/templates/{template_id}")
async def delete_template(template_id: str):
    """Delete a template"""
    result = await db.templates.delete_one({"id": template_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Template not found")
    return {"success": True}

# ============== SCHEDULED MESSAGES ==============

async def send_whatsapp_message(phone: str, message: str):
    """Send a WhatsApp message via the WA service"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(
                f"{WA_SERVICE_URL}/send",
                json={"phone": phone, "message": message},
                timeout=30.0
            )
            return response.json()
    except Exception as e:
        logger.error(f"Send message error: {e}")
        return {"success": False, "error": str(e)}

async def execute_scheduled_message(schedule_id: str):
    """Execute a scheduled message"""
    schedule = await db.schedules.find_one({"id": schedule_id}, {"_id": 0})
    if not schedule or not schedule.get('is_active'):
        return
    
    # Send the message
    result = await send_whatsapp_message(schedule['contact_phone'], schedule['message'])
    
    # Log the message
    log = MessageLog(
        contact_id=schedule['contact_id'],
        contact_name=schedule['contact_name'],
        contact_phone=schedule['contact_phone'],
        message=schedule['message'],
        status="sent" if result.get('success') else "failed",
        error_message=result.get('error'),
        scheduled_message_id=schedule_id
    )
    log_doc = log.model_dump()
    log_doc['sent_at'] = log_doc['sent_at'].isoformat()
    await db.logs.insert_one(log_doc)
    
    # Update schedule last_run
    await db.schedules.update_one(
        {"id": schedule_id},
        {"$set": {"last_run": datetime.now(timezone.utc).isoformat()}}
    )
    
    # Send Telegram notification if enabled
    settings = await db.settings.find_one({"id": "settings"}, {"_id": 0})
    if settings and settings.get('telegram_enabled') and settings.get('telegram_token'):
        await send_telegram_notification(
            settings['telegram_token'],
            settings.get('telegram_chat_id'),
            f"📤 Message sent to {schedule['contact_name']}\n{'✅ Success' if result.get('success') else '❌ Failed: ' + str(result.get('error', 'Unknown error'))}"
        )

async def send_telegram_notification(token: str, chat_id: str, message: str):
    """Send a Telegram notification"""
    if not chat_id:
        return
    try:
        async with httpx.AsyncClient() as http_client:
            await http_client.post(
                f"https://api.telegram.org/bot{token}/sendMessage",
                json={"chat_id": chat_id, "text": message, "parse_mode": "HTML"},
                timeout=10.0
            )
    except Exception as e:
        logger.error(f"Telegram notification error: {e}")

@api_router.get("/schedules", response_model=List[ScheduledMessage])
async def get_schedules():
    """Get all scheduled messages"""
    schedules = await db.schedules.find({}, {"_id": 0}).to_list(1000)
    for s in schedules:
        for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
            if isinstance(s.get(field), str):
                s[field] = datetime.fromisoformat(s[field])
    return schedules

@api_router.post("/schedules", response_model=ScheduledMessage)
async def create_schedule(input: ScheduledMessageCreate):
    """Create a new scheduled message"""
    # Get contact info
    contact = await db.contacts.find_one({"id": input.contact_id}, {"_id": 0})
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    schedule = ScheduledMessage(
        contact_id=input.contact_id,
        contact_name=contact['name'],
        contact_phone=contact['phone'],
        message=input.message,
        schedule_type=input.schedule_type,
        scheduled_time=input.scheduled_time,
        cron_expression=input.cron_expression,
        cron_description=input.cron_description
    )
    
    doc = schedule.model_dump()
    for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
        if doc.get(field):
            doc[field] = doc[field].isoformat()
    
    await db.schedules.insert_one(doc)
    
    # Add to scheduler
    if input.schedule_type == "once" and input.scheduled_time:
        scheduler.add_job(
            execute_scheduled_message,
            DateTrigger(run_date=input.scheduled_time),
            args=[schedule.id],
            id=schedule.id,
            replace_existing=True
        )
    elif input.schedule_type == "recurring" and input.cron_expression:
        scheduler.add_job(
            execute_scheduled_message,
            CronTrigger.from_crontab(input.cron_expression),
            args=[schedule.id],
            id=schedule.id,
            replace_existing=True
        )
    
    return schedule

@api_router.put("/schedules/{schedule_id}/toggle")
async def toggle_schedule(schedule_id: str):
    """Toggle a schedule active/inactive"""
    schedule = await db.schedules.find_one({"id": schedule_id}, {"_id": 0})
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    new_status = not schedule.get('is_active', True)
    await db.schedules.update_one({"id": schedule_id}, {"$set": {"is_active": new_status}})
    
    # Update scheduler
    try:
        if new_status:
            if schedule['schedule_type'] == "once" and schedule.get('scheduled_time'):
                sched_time = schedule['scheduled_time']
                if isinstance(sched_time, str):
                    sched_time = datetime.fromisoformat(sched_time)
                scheduler.add_job(
                    execute_scheduled_message,
                    DateTrigger(run_date=sched_time),
                    args=[schedule_id],
                    id=schedule_id,
                    replace_existing=True
                )
            elif schedule['schedule_type'] == "recurring" and schedule.get('cron_expression'):
                scheduler.add_job(
                    execute_scheduled_message,
                    CronTrigger.from_crontab(schedule['cron_expression']),
                    args=[schedule_id],
                    id=schedule_id,
                    replace_existing=True
                )
        else:
            scheduler.remove_job(schedule_id)
    except Exception as e:
        logger.warning(f"Scheduler update warning: {e}")
    
    return {"success": True, "is_active": new_status}

@api_router.delete("/schedules/{schedule_id}")
async def delete_schedule(schedule_id: str):
    """Delete a scheduled message"""
    result = await db.schedules.delete_one({"id": schedule_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    try:
        scheduler.remove_job(schedule_id)
    except:
        pass
    
    return {"success": True}

# ============== SEND NOW ==============

@api_router.post("/send-now")
async def send_message_now(contact_id: str, message: str, background_tasks: BackgroundTasks):
    """Send a message immediately"""
    contact = await db.contacts.find_one({"id": contact_id}, {"_id": 0})
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    result = await send_whatsapp_message(contact['phone'], message)
    
    # Log the message
    log = MessageLog(
        contact_id=contact_id,
        contact_name=contact['name'],
        contact_phone=contact['phone'],
        message=message,
        status="sent" if result.get('success') else "failed",
        error_message=result.get('error')
    )
    log_doc = log.model_dump()
    log_doc['sent_at'] = log_doc['sent_at'].isoformat()
    await db.logs.insert_one(log_doc)
    
    return result

# ============== MESSAGE LOGS ==============

@api_router.get("/logs", response_model=List[MessageLog])
async def get_logs(limit: int = 100):
    """Get message logs"""
    logs = await db.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(limit)
    for l in logs:
        if isinstance(l.get('sent_at'), str):
            l['sent_at'] = datetime.fromisoformat(l['sent_at'])
    return logs

@api_router.delete("/logs")
async def clear_logs():
    """Clear all logs"""
    await db.logs.delete_many({})
    return {"success": True}

# ============== SETTINGS ==============

@api_router.get("/timezone")
async def get_timezone_info():
    """Get system timezone and available timezones"""
    try:
        system_tz = get_localzone_name()
    except:
        system_tz = "UTC"
    
    # Common timezones for dropdown
    common_timezones = [
        "UTC",
        "America/New_York",
        "America/Chicago", 
        "America/Denver",
        "America/Los_Angeles",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Asia/Kolkata",
        "Asia/Dubai",
        "Australia/Sydney",
        "Pacific/Auckland"
    ]
    
    return {
        "system_timezone": system_tz,
        "common_timezones": common_timezones,
        "all_timezones": pytz.common_timezones
    }

@api_router.get("/settings", response_model=Settings)
async def get_settings():
    """Get application settings"""
    settings = await db.settings.find_one({"id": "settings"}, {"_id": 0})
    if not settings:
        # Default to system timezone
        try:
            system_tz = get_localzone_name()
        except:
            system_tz = None
        default_settings = Settings(timezone=system_tz)
        settings = default_settings.model_dump()
        settings['updated_at'] = settings['updated_at'].isoformat()
        await db.settings.insert_one(settings)
        settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
    else:
        if isinstance(settings.get('updated_at'), str):
            settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
        # If timezone not set, use system timezone
        if not settings.get('timezone'):
            try:
                settings['timezone'] = get_localzone_name()
            except:
                settings['timezone'] = None
    return Settings(**settings)

@api_router.put("/settings", response_model=Settings)
async def update_settings(input: SettingsUpdate):
    """Update application settings"""
    global telegram_polling_task
    
    update_data = input.model_dump()
    update_data['updated_at'] = datetime.now(timezone.utc).isoformat()
    
    await db.settings.update_one(
        {"id": "settings"},
        {"$set": update_data},
        upsert=True
    )
    
    # Restart telegram polling if settings changed
    if input.telegram_enabled and input.telegram_token:
        await restart_telegram_polling()
    else:
        await stop_telegram_polling()
    
    settings = await db.settings.find_one({"id": "settings"}, {"_id": 0})
    if isinstance(settings.get('updated_at'), str):
        settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
    return Settings(**settings)

# ============== TELEGRAM BOT POLLING ==============

async def handle_telegram_message(token: str, message: dict):
    """Handle incoming Telegram message"""
    text = message.get('text', '')
    chat_id = str(message.get('chat', {}).get('id', ''))
    
    if not text or not chat_id:
        return
    
    # Auto-save chat_id
    await db.settings.update_one(
        {"id": "settings"},
        {"$set": {"telegram_chat_id": chat_id}}
    )
    
    response_text = None
    
    if text.startswith('/start'):
        response_text = """🤖 <b>WhatsApp Scheduler Bot</b>

<b>Commands:</b>
/status - Check WhatsApp connection
/contacts - List all contacts
/schedules - List active schedules
/send &lt;name&gt; &lt;message&gt; - Send message now
/help - Show this help"""
    
    elif text.startswith('/help'):
        response_text = """📋 <b>Available Commands:</b>

/status - Check if WhatsApp is connected
/contacts - Show all your contacts
/schedules - Show active scheduled messages
/send John Hello! - Send "Hello!" to contact named John
/help - Show this help message"""
    
    elif text.startswith('/status'):
        try:
            async with httpx.AsyncClient() as http_client:
                resp = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=5.0)
                wa_status = resp.json()
                if wa_status.get('isReady'):
                    name = wa_status.get('clientInfo', {}).get('pushname', 'Unknown')
                    response_text = f"✅ <b>WhatsApp Connected</b>\n👤 Logged in as: {name}"
                else:
                    response_text = "❌ <b>WhatsApp Not Connected</b>\n\nPlease scan the QR code in the web dashboard."
        except Exception as e:
            response_text = f"❌ Could not check WhatsApp status\nError: {str(e)}"
    
    elif text.startswith('/contacts'):
        contacts = await db.contacts.find({}, {"_id": 0}).to_list(20)
        if contacts:
            contact_list = "\n".join([f"• {c['name']} ({c['phone']})" for c in contacts])
            response_text = f"📇 <b>Contacts ({len(contacts)}):</b>\n\n{contact_list}"
        else:
            response_text = "📇 No contacts found.\n\nAdd contacts via the web dashboard."
    
    elif text.startswith('/schedules'):
        schedules = await db.schedules.find({"is_active": True}, {"_id": 0}).to_list(20)
        if schedules:
            schedule_list = "\n".join([f"• {s['contact_name']}: {s['message'][:30]}..." for s in schedules])
            response_text = f"📅 <b>Active Schedules ({len(schedules)}):</b>\n\n{schedule_list}"
        else:
            response_text = "📅 No active schedules.\n\nCreate schedules via the web dashboard."
    
    elif text.startswith('/send '):
        parts = text[6:].split(' ', 1)
        if len(parts) == 2:
            contact_name, msg = parts
            contact = await db.contacts.find_one(
                {"name": {"$regex": f"^{contact_name}", "$options": "i"}}, 
                {"_id": 0}
            )
            if contact:
                result = await send_whatsapp_message(contact['phone'], msg)
                if result.get('success'):
                    response_text = f"✅ <b>Message sent to {contact['name']}</b>\n\n📱 {contact['phone']}\n💬 {msg}"
                    
                    # Log the message
                    log = MessageLog(
                        contact_id=contact['id'],
                        contact_name=contact['name'],
                        contact_phone=contact['phone'],
                        message=msg,
                        status="sent"
                    )
                    log_doc = log.model_dump()
                    log_doc['sent_at'] = log_doc['sent_at'].isoformat()
                    await db.logs.insert_one(log_doc)
                else:
                    response_text = f"❌ <b>Failed to send message</b>\n\nError: {result.get('error', 'Unknown error')}"
            else:
                response_text = f"❌ Contact '<b>{contact_name}</b>' not found.\n\nUse /contacts to see available contacts."
        else:
            response_text = "❌ <b>Invalid format</b>\n\nUsage: /send &lt;contact_name&gt; &lt;message&gt;\nExample: /send John Hello, how are you?"
    
    else:
        response_text = "❓ Unknown command. Type /help to see available commands."
    
    # Send response
    if response_text:
        await send_telegram_notification(token, chat_id, response_text)

async def telegram_polling_loop():
    """Main polling loop for Telegram updates"""
    global telegram_last_update_id
    
    while True:
        try:
            settings = await db.settings.find_one({"id": "settings"}, {"_id": 0})
            if not settings or not settings.get('telegram_enabled') or not settings.get('telegram_token'):
                await asyncio.sleep(5)
                continue
            
            token = settings['telegram_token']
            
            async with httpx.AsyncClient() as http_client:
                url = f"https://api.telegram.org/bot{token}/getUpdates"
                params = {"offset": telegram_last_update_id + 1, "timeout": 30}
                
                response = await http_client.get(url, params=params, timeout=35.0)
                data = response.json()
                
                if data.get('ok') and data.get('result'):
                    for update in data['result']:
                        telegram_last_update_id = update['update_id']
                        
                        if 'message' in update:
                            await handle_telegram_message(token, update['message'])
        
        except asyncio.CancelledError:
            logger.info("Telegram polling cancelled")
            break
        except Exception as e:
            logger.error(f"Telegram polling error: {e}")
            await asyncio.sleep(5)

async def start_telegram_polling():
    """Start Telegram polling task"""
    global telegram_polling_task
    
    if telegram_polling_task is None or telegram_polling_task.done():
        telegram_polling_task = asyncio.create_task(telegram_polling_loop())
        logger.info("Telegram polling started")

async def stop_telegram_polling():
    """Stop Telegram polling task"""
    global telegram_polling_task
    
    if telegram_polling_task and not telegram_polling_task.done():
        telegram_polling_task.cancel()
        try:
            await telegram_polling_task
        except asyncio.CancelledError:
            pass
        logger.info("Telegram polling stopped")

async def restart_telegram_polling():
    """Restart Telegram polling"""
    await stop_telegram_polling()
    await start_telegram_polling()

# ============== DASHBOARD STATS ==============

@api_router.get("/dashboard/stats")
async def get_dashboard_stats():
    """Get dashboard statistics"""
    contacts_count = await db.contacts.count_documents({})
    templates_count = await db.templates.count_documents({})
    active_schedules = await db.schedules.count_documents({"is_active": True})
    total_messages = await db.logs.count_documents({})
    sent_messages = await db.logs.count_documents({"status": "sent"})
    failed_messages = await db.logs.count_documents({"status": "failed"})
    
    # Get recent logs
    recent_logs = await db.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(5)
    for l in recent_logs:
        if isinstance(l.get('sent_at'), str):
            l['sent_at'] = datetime.fromisoformat(l['sent_at'])
    
    # Get upcoming schedules
    upcoming = await db.schedules.find({"is_active": True}, {"_id": 0}).to_list(5)
    for s in upcoming:
        for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
            if isinstance(s.get(field), str):
                s[field] = datetime.fromisoformat(s[field])
    
    return {
        "contacts_count": contacts_count,
        "templates_count": templates_count,
        "active_schedules": active_schedules,
        "total_messages": total_messages,
        "sent_messages": sent_messages,
        "failed_messages": failed_messages,
        "recent_logs": recent_logs,
        "upcoming_schedules": upcoming
    }

# ============== ROOT ==============

@api_router.get("/")
async def root():
    return {"message": "WhatsApp Scheduler API"}

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    scheduler.start()
    logger.info("Scheduler started")
    
    # Start Telegram polling
    settings = await db.settings.find_one({"id": "settings"}, {"_id": 0})
    if settings and settings.get('telegram_enabled') and settings.get('telegram_token'):
        await start_telegram_polling()
    
    # Reload existing schedules
    schedules = await db.schedules.find({"is_active": True}, {"_id": 0}).to_list(1000)
    for schedule in schedules:
        try:
            if schedule['schedule_type'] == "once" and schedule.get('scheduled_time'):
                sched_time = schedule['scheduled_time']
                if isinstance(sched_time, str):
                    sched_time = datetime.fromisoformat(sched_time)
                if sched_time > datetime.now(timezone.utc):
                    scheduler.add_job(
                        execute_scheduled_message,
                        DateTrigger(run_date=sched_time),
                        args=[schedule['id']],
                        id=schedule['id'],
                        replace_existing=True
                    )
            elif schedule['schedule_type'] == "recurring" and schedule.get('cron_expression'):
                scheduler.add_job(
                    execute_scheduled_message,
                    CronTrigger.from_crontab(schedule['cron_expression']),
                    args=[schedule['id']],
                    id=schedule['id'],
                    replace_existing=True
                )
        except Exception as e:
            logger.warning(f"Failed to reload schedule {schedule['id']}: {e}")

@app.on_event("shutdown")
async def shutdown():
    await stop_telegram_polling()
    scheduler.shutdown()
    client.close()
