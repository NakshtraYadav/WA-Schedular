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

# Load environment
ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection - with error handling
mongo_url = os.environ.get('MONGO_URL', 'mongodb://localhost:27017')
db_name = os.environ.get('DB_NAME', 'whatsapp_scheduler')

client = None
db = None

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
telegram_bot_running = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============== TELEGRAM BOT ==============

async def send_telegram_message(token: str, chat_id: str, text: str, parse_mode: str = "HTML"):
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

async def process_telegram_command(token: str, chat_id: str, text: str):
    """Process incoming Telegram commands"""
    text = text.strip()
    database = await get_database()
    
    if text == "/start":
        # Save chat_id to settings
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
        
    elif text == "/help":
        response = (
            "📱 <b>WA Scheduler Commands</b>\n\n"
            "/status - Check WhatsApp connection\n"
            "/contacts - List all contacts\n"
            "/schedules - List active schedules\n"
            "/send &lt;name&gt; &lt;message&gt; - Send WhatsApp message\n"
            "/logs - Recent message history\n"
            "/help - Show this help"
        )
        await send_telegram_message(token, chat_id, response)
        
    elif text == "/status":
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
        
    elif text == "/contacts":
        contacts = await database.contacts.find({}, {"_id": 0}).to_list(50)
        if contacts:
            lines = ["📋 <b>Contacts</b>\n"]
            for c in contacts:
                lines.append(f"• {c['name']}: {c['phone']}")
            response = "\n".join(lines)
        else:
            response = "📋 <b>No contacts found</b>\n\nAdd contacts via the web dashboard."
        await send_telegram_message(token, chat_id, response)
        
    elif text == "/schedules":
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
        
    elif text == "/logs":
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
        
    elif text.startswith("/send "):
        parts = text[6:].strip().split(" ", 1)
        if len(parts) < 2:
            await send_telegram_message(token, chat_id, "❌ Usage: /send &lt;contact_name&gt; &lt;message&gt;")
            return
            
        contact_name, message = parts[0], parts[1]
        
        # Find contact by name (case-insensitive partial match)
        contact = await database.contacts.find_one(
            {"name": {"$regex": contact_name, "$options": "i"}},
            {"_id": 0}
        )
        
        if not contact:
            await send_telegram_message(token, chat_id, f"❌ Contact '{contact_name}' not found")
            return
            
        # Send the message
        result = await send_whatsapp_message(contact['phone'], message)
        
        if result.get('success'):
            # Log the message
            log = MessageLog(
                contact_id=contact['id'],
                contact_name=contact['name'],
                contact_phone=contact['phone'],
                message=message,
                status="sent"
            )
            log_doc = log.model_dump()
            log_doc['sent_at'] = log_doc['sent_at'].isoformat()
            await database.logs.insert_one(log_doc)
            
            await send_telegram_message(token, chat_id, f"✅ Message sent to {contact['name']}")
        else:
            error = result.get('error', 'Unknown error')
            await send_telegram_message(token, chat_id, f"❌ Failed to send: {error}")
    else:
        await send_telegram_message(token, chat_id, "❓ Unknown command. Type /help for available commands.")

async def telegram_polling_loop():
    """Long-polling loop for Telegram updates"""
    global telegram_last_update_id, telegram_bot_running
    
    while telegram_bot_running:
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
                        "offset": telegram_last_update_id + 1,
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
                    telegram_last_update_id = update['update_id']
                    
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
    global telegram_polling_task, telegram_bot_running
    
    if telegram_polling_task and not telegram_polling_task.done():
        return
        
    telegram_bot_running = True
    telegram_polling_task = asyncio.create_task(telegram_polling_loop())
    logger.info("Telegram bot polling started")

async def stop_telegram_bot():
    """Stop the Telegram bot polling"""
    global telegram_polling_task, telegram_bot_running
    
    telegram_bot_running = False
    if telegram_polling_task:
        telegram_polling_task.cancel()
        try:
            await telegram_polling_task
        except asyncio.CancelledError:
            pass
    logger.info("Telegram bot polling stopped")

# ============== DATABASE CONNECTION ==============

async def get_database():
    """Get or create database connection"""
    global client, db
    if client is None:
        try:
            client = AsyncIOMotorClient(mongo_url, serverSelectionTimeoutMS=5000)
            # Test connection
            await client.admin.command('ping')
            db = client[db_name]
            logger.info(f"Connected to MongoDB: {mongo_url}")
        except Exception as e:
            logger.error(f"MongoDB connection failed: {e}")
            raise HTTPException(status_code=503, detail=f"Database unavailable: {e}")
    return db

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
        cleaned = v.strip()
        if not cleaned:
            raise ValueError('Phone number is required')
        if cleaned[0] == '+':
            digits = cleaned[1:]
        else:
            digits = cleaned
        if not digits.replace(' ', '').replace('-', '').isdigit():
            raise ValueError('Phone number must contain only digits')
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
    schedule_type: str
    scheduled_time: Optional[datetime] = None
    cron_expression: Optional[str] = None
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
    status: str
    error_message: Optional[str] = None
    scheduled_message_id: Optional[str] = None
    sent_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class Settings(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = "settings"
    telegram_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: bool = False
    timezone: Optional[str] = None
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class SettingsUpdate(BaseModel):
    telegram_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: bool = False
    timezone: Optional[str] = None

# ============== HEALTH CHECK ==============

@api_router.get("/")
async def root():
    """API root - health check"""
    return {"message": "WhatsApp Scheduler API", "status": "running"}

@api_router.get("/health")
async def health_check():
    """Detailed health check"""
    health = {
        "status": "healthy",
        "api": True,
        "database": False,
        "whatsapp_service": False
    }
    
    # Check database
    try:
        database = await get_database()
        await database.command('ping')
        health["database"] = True
    except Exception as e:
        health["status"] = "degraded"
        health["database_error"] = str(e)
    
    # Check WhatsApp service
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/health", timeout=3.0)
            health["whatsapp_service"] = response.status_code == 200
    except:
        pass
    
    return health

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

# ============== CONTACTS ==============

@api_router.get("/contacts", response_model=List[Contact])
async def get_contacts():
    """Get all contacts"""
    database = await get_database()
    contacts = await database.contacts.find({}, {"_id": 0}).to_list(1000)
    for c in contacts:
        if isinstance(c.get('created_at'), str):
            c['created_at'] = datetime.fromisoformat(c['created_at'])
    return contacts

@api_router.post("/contacts", response_model=Contact)
async def create_contact(input: ContactCreate):
    """Create a new contact"""
    database = await get_database()
    contact = Contact(**input.model_dump())
    doc = contact.model_dump()
    doc['created_at'] = doc['created_at'].isoformat()
    await database.contacts.insert_one(doc)
    return contact

@api_router.put("/contacts/{contact_id}", response_model=Contact)
async def update_contact(contact_id: str, input: ContactCreate):
    """Update a contact"""
    database = await get_database()
    existing = await database.contacts.find_one({"id": contact_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    update_data = input.model_dump()
    await database.contacts.update_one({"id": contact_id}, {"$set": update_data})
    
    updated = await database.contacts.find_one({"id": contact_id}, {"_id": 0})
    if isinstance(updated.get('created_at'), str):
        updated['created_at'] = datetime.fromisoformat(updated['created_at'])
    return Contact(**updated)

@api_router.delete("/contacts/{contact_id}")
async def delete_contact(contact_id: str):
    """Delete a contact"""
    database = await get_database()
    result = await database.contacts.delete_one({"id": contact_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"success": True}

# ============== MESSAGE TEMPLATES ==============

@api_router.get("/templates", response_model=List[MessageTemplate])
async def get_templates():
    """Get all message templates"""
    database = await get_database()
    templates = await database.templates.find({}, {"_id": 0}).to_list(1000)
    for t in templates:
        if isinstance(t.get('created_at'), str):
            t['created_at'] = datetime.fromisoformat(t['created_at'])
    return templates

@api_router.post("/templates", response_model=MessageTemplate)
async def create_template(input: MessageTemplateCreate):
    """Create a new message template"""
    database = await get_database()
    template = MessageTemplate(**input.model_dump())
    doc = template.model_dump()
    doc['created_at'] = doc['created_at'].isoformat()
    await database.templates.insert_one(doc)
    return template

@api_router.put("/templates/{template_id}", response_model=MessageTemplate)
async def update_template(template_id: str, input: MessageTemplateCreate):
    """Update a template"""
    database = await get_database()
    existing = await database.templates.find_one({"id": template_id}, {"_id": 0})
    if not existing:
        raise HTTPException(status_code=404, detail="Template not found")
    
    update_data = input.model_dump()
    await database.templates.update_one({"id": template_id}, {"$set": update_data})
    
    updated = await database.templates.find_one({"id": template_id}, {"_id": 0})
    if isinstance(updated.get('created_at'), str):
        updated['created_at'] = datetime.fromisoformat(updated['created_at'])
    return MessageTemplate(**updated)

@api_router.delete("/templates/{template_id}")
async def delete_template(template_id: str):
    """Delete a template"""
    database = await get_database()
    result = await database.templates.delete_one({"id": template_id})
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
    try:
        database = await get_database()
        schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
        if not schedule or not schedule.get('is_active'):
            return
        
        result = await send_whatsapp_message(schedule['contact_phone'], schedule['message'])
        
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
        await database.logs.insert_one(log_doc)
        
        await database.schedules.update_one(
            {"id": schedule_id},
            {"$set": {"last_run": datetime.now(timezone.utc).isoformat()}}
        )
    except Exception as e:
        logger.error(f"Execute scheduled message error: {e}")

@api_router.get("/schedules", response_model=List[ScheduledMessage])
async def get_schedules():
    """Get all scheduled messages"""
    database = await get_database()
    schedules = await database.schedules.find({}, {"_id": 0}).to_list(1000)
    for s in schedules:
        for field in ['scheduled_time', 'last_run', 'next_run', 'created_at']:
            if isinstance(s.get(field), str):
                s[field] = datetime.fromisoformat(s[field])
    return schedules

@api_router.post("/schedules", response_model=ScheduledMessage)
async def create_schedule(input: ScheduledMessageCreate):
    """Create a new scheduled message"""
    database = await get_database()
    contact = await database.contacts.find_one({"id": input.contact_id}, {"_id": 0})
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
    
    await database.schedules.insert_one(doc)
    
    try:
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
    except Exception as e:
        logger.warning(f"Failed to add job to scheduler: {e}")
    
    return schedule

@api_router.put("/schedules/{schedule_id}/toggle")
async def toggle_schedule(schedule_id: str):
    """Toggle a schedule active/inactive"""
    database = await get_database()
    schedule = await database.schedules.find_one({"id": schedule_id}, {"_id": 0})
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    new_status = not schedule.get('is_active', True)
    await database.schedules.update_one({"id": schedule_id}, {"$set": {"is_active": new_status}})
    
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
            try:
                scheduler.remove_job(schedule_id)
            except:
                pass
    except Exception as e:
        logger.warning(f"Scheduler update warning: {e}")
    
    return {"success": True, "is_active": new_status}

@api_router.delete("/schedules/{schedule_id}")
async def delete_schedule(schedule_id: str):
    """Delete a scheduled message"""
    database = await get_database()
    result = await database.schedules.delete_one({"id": schedule_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Schedule not found")
    
    try:
        scheduler.remove_job(schedule_id)
    except:
        pass
    
    return {"success": True}

# ============== SEND NOW ==============

@api_router.post("/send-now")
async def send_message_now(contact_id: str, message: str):
    """Send a message immediately"""
    database = await get_database()
    contact = await database.contacts.find_one({"id": contact_id}, {"_id": 0})
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    result = await send_whatsapp_message(contact['phone'], message)
    
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
    await database.logs.insert_one(log_doc)
    
    return result

# ============== MESSAGE LOGS ==============

@api_router.get("/logs", response_model=List[MessageLog])
async def get_logs(limit: int = 100):
    """Get message logs"""
    database = await get_database()
    logs = await database.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(limit)
    for l in logs:
        if isinstance(l.get('sent_at'), str):
            l['sent_at'] = datetime.fromisoformat(l['sent_at'])
    return logs

@api_router.delete("/logs")
async def clear_logs():
    """Clear all logs"""
    database = await get_database()
    await database.logs.delete_many({})
    return {"success": True}

# ============== SETTINGS ==============

@api_router.get("/timezone")
async def get_timezone_info():
    """Get system timezone and available timezones"""
    try:
        from tzlocal import get_localzone_name
        system_tz = get_localzone_name()
    except:
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

@api_router.get("/settings", response_model=Settings)
async def get_settings():
    """Get application settings"""
    database = await get_database()
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    if not settings:
        try:
            from tzlocal import get_localzone_name
            system_tz = get_localzone_name()
        except:
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

@api_router.put("/settings", response_model=Settings)
async def update_settings(input: SettingsUpdate):
    """Update application settings"""
    database = await get_database()
    
    update_data = input.model_dump()
    update_data['updated_at'] = datetime.now(timezone.utc).isoformat()
    
    await database.settings.update_one(
        {"id": "settings"},
        {"$set": update_data},
        upsert=True
    )
    
    # Start or stop Telegram bot based on settings
    if input.telegram_enabled and input.telegram_token:
        await start_telegram_bot()
    else:
        await stop_telegram_bot()
    
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    if isinstance(settings.get('updated_at'), str):
        settings['updated_at'] = datetime.fromisoformat(settings['updated_at'])
    return Settings(**settings)

@api_router.post("/telegram/test")
async def test_telegram_bot():
    """Test Telegram bot connection"""
    database = await get_database()
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    
    if not settings or not settings.get('telegram_token'):
        return {"success": False, "error": "Telegram bot token not configured"}
    
    token = settings['telegram_token']
    
    try:
        async with httpx.AsyncClient() as http_client:
            # Test getMe endpoint
            response = await http_client.get(
                f"https://api.telegram.org/bot{token}/getMe",
                timeout=10.0
            )
            
            if response.status_code == 200:
                data = response.json()
                if data.get('ok'):
                    bot_info = data.get('result', {})
                    
                    # If chat_id exists, send a test message
                    chat_id = settings.get('telegram_chat_id')
                    if chat_id:
                        await send_telegram_message(
                            token, chat_id,
                            "✅ <b>Test successful!</b>\n\nYour WA Scheduler Telegram bot is working correctly."
                        )
                        return {
                            "success": True,
                            "bot_name": bot_info.get('first_name'),
                            "bot_username": bot_info.get('username'),
                            "message_sent": True
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
            else:
                return {"success": False, "error": f"HTTP {response.status_code}"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@api_router.get("/telegram/status")
async def get_telegram_status():
    """Get Telegram bot status"""
    global telegram_bot_running
    
    database = await get_database()
    settings = await database.settings.find_one({"id": "settings"}, {"_id": 0})
    
    return {
        "enabled": settings.get('telegram_enabled', False) if settings else False,
        "has_token": bool(settings.get('telegram_token')) if settings else False,
        "has_chat_id": bool(settings.get('telegram_chat_id')) if settings else False,
        "polling_active": telegram_bot_running
    }

# ============== DASHBOARD STATS ==============

@api_router.get("/dashboard/stats")
async def get_dashboard_stats():
    """Get dashboard statistics"""
    database = await get_database()
    
    contacts_count = await database.contacts.count_documents({})
    templates_count = await database.templates.count_documents({})
    active_schedules = await database.schedules.count_documents({"is_active": True})
    total_messages = await database.logs.count_documents({})
    sent_messages = await database.logs.count_documents({"status": "sent"})
    failed_messages = await database.logs.count_documents({"status": "failed"})
    
    recent_logs = await database.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(5)
    for l in recent_logs:
        if isinstance(l.get('sent_at'), str):
            l['sent_at'] = datetime.fromisoformat(l['sent_at'])
    
    upcoming = await database.schedules.find({"is_active": True}, {"_id": 0}).to_list(5)
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

# ============== SYSTEM DIAGNOSTICS ==============

@api_router.get("/diagnostics")
async def get_diagnostics():
    """Get full system diagnostics"""
    import platform
    import psutil
    
    diagnostics = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system": {
            "platform": platform.system(),
            "release": platform.release(),
            "python_version": platform.python_version(),
            "cpu_percent": psutil.cpu_percent(),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_percent": psutil.disk_usage('/').percent if platform.system() != 'Windows' else None
        },
        "services": {
            "backend": {"status": "running", "port": 8001},
            "whatsapp": {"status": "unknown", "port": 3001},
            "mongodb": {"status": "unknown", "port": 27017}
        },
        "logs": {}
    }
    
    # Check MongoDB
    try:
        database = await get_database()
        await database.command('ping')
        diagnostics["services"]["mongodb"]["status"] = "running"
    except:
        diagnostics["services"]["mongodb"]["status"] = "error"
    
    # Check WhatsApp
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=3.0)
            if response.status_code == 200:
                wa_status = response.json()
                diagnostics["services"]["whatsapp"]["status"] = "running"
                diagnostics["services"]["whatsapp"]["details"] = wa_status
            else:
                diagnostics["services"]["whatsapp"]["status"] = "error"
    except:
        diagnostics["services"]["whatsapp"]["status"] = "stopped"
    
    return diagnostics

@api_router.get("/diagnostics/logs/{service}")
async def get_service_logs(service: str, lines: int = 100):
    """Get logs for a specific service"""
    import glob
    
    # Determine log directory
    log_base = ROOT_DIR.parent / "logs"
    
    service_map = {
        "backend": "backend",
        "frontend": "frontend", 
        "whatsapp": "whatsapp",
        "system": "system"
    }
    
    if service not in service_map:
        raise HTTPException(status_code=400, detail=f"Invalid service: {service}")
    
    log_dir = log_base / service_map[service]
    
    if not log_dir.exists():
        return {"service": service, "logs": [], "message": "Log directory not found"}
    
    # Find most recent log file
    log_files = sorted(log_dir.glob("*.log"), key=lambda x: x.stat().st_mtime, reverse=True)
    
    if not log_files:
        return {"service": service, "logs": [], "message": "No log files found"}
    
    latest_log = log_files[0]
    
    try:
        with open(latest_log, 'r', encoding='utf-8', errors='ignore') as f:
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
        
        return {
            "service": service,
            "file": latest_log.name,
            "total_lines": len(all_lines),
            "logs": [line.strip() for line in recent_lines]
        }
    except Exception as e:
        return {"service": service, "logs": [], "error": str(e)}

@api_router.get("/diagnostics/logs")
async def get_all_logs_summary():
    """Get summary of all log files"""
    log_base = ROOT_DIR.parent / "logs"
    
    summary = {}
    
    for service in ["backend", "frontend", "whatsapp", "system"]:
        service_dir = log_base / service
        if service_dir.exists():
            log_files = list(service_dir.glob("*.log"))
            total_size = sum(f.stat().st_size for f in log_files)
            summary[service] = {
                "file_count": len(log_files),
                "total_size_mb": round(total_size / (1024 * 1024), 2),
                "latest_file": sorted(log_files, key=lambda x: x.stat().st_mtime, reverse=True)[0].name if log_files else None
            }
        else:
            summary[service] = {"file_count": 0, "total_size_mb": 0, "latest_file": None}
    
    return summary

@api_router.post("/diagnostics/clear-logs/{service}")
async def clear_service_logs(service: str):
    """Clear logs for a specific service"""
    import shutil
    
    log_base = ROOT_DIR.parent / "logs"
    
    if service not in ["backend", "frontend", "whatsapp", "system", "all"]:
        raise HTTPException(status_code=400, detail=f"Invalid service: {service}")
    
    cleared = []
    
    if service == "all":
        services = ["backend", "frontend", "whatsapp", "system"]
    else:
        services = [service]
    
    for svc in services:
        svc_dir = log_base / svc
        if svc_dir.exists():
            for log_file in svc_dir.glob("*.log"):
                try:
                    log_file.unlink()
                    cleared.append(str(log_file))
                except:
                    pass
    
    return {"success": True, "cleared": cleared}

@api_router.post("/whatsapp/retry")
async def retry_whatsapp_init():
    """Retry WhatsApp initialization"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/retry-init", timeout=5.0)
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@api_router.post("/whatsapp/clear-session")
async def clear_whatsapp_session():
    """Clear WhatsApp session and restart"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/clear-session", timeout=10.0)
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/whatsapp/test-browser")
async def test_browser():
    """Test if browser can be launched"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/test-browser", timeout=30.0)
            return response.json()
    except Exception as e:
        return {"success": False, "error": str(e)}

# ============== INCLUDE ROUTER ==============

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
    global client, db
    
    # Try to connect to MongoDB
    try:
        client = AsyncIOMotorClient(mongo_url, serverSelectionTimeoutMS=5000)
        await client.admin.command('ping')
        db = client[db_name]
        logger.info(f"Connected to MongoDB: {mongo_url}")
    except Exception as e:
        logger.warning(f"MongoDB not available at startup: {e}")
        logger.warning("API will retry connection on first request")
    
    # Start scheduler
    scheduler.start()
    logger.info("Scheduler started")
    
    # Reload existing schedules if DB is available
    if db is not None:
        try:
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
                    
            # Start Telegram bot if enabled
            settings = await db.settings.find_one({"id": "settings"}, {"_id": 0})
            if settings and settings.get('telegram_enabled') and settings.get('telegram_token'):
                await start_telegram_bot()
                
        except Exception as e:
            logger.warning(f"Could not reload schedules: {e}")

@app.on_event("shutdown")
async def shutdown():
    scheduler.shutdown()
    if client:
        client.close()
    logger.info("Server shutdown complete")
