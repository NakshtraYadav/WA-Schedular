"""Messaging telegram commands: /send, /search"""
from core.database import get_database
from services.telegram.sender import send_telegram_message
from services.whatsapp.message_sender import send_whatsapp_message
from models.message_log import MessageLog


async def handle_send(token: str, chat_id: str, text: str):
    """Handle /send command"""
    parts = text[6:].strip().split(" ", 1)
    if len(parts) < 2:
        await send_telegram_message(token, chat_id, "❌ Usage: /send &lt;contact_name&gt; &lt;message&gt;")
        return
        
    contact_name, message = parts[0], parts[1]
    database = await get_database()
    
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


async def handle_search(token: str, chat_id: str, text: str):
    """Handle /search command"""
    query = text[8:].strip()
    if len(query) < 2:
        await send_telegram_message(token, chat_id, "❌ Search query too short. Use at least 2 characters.")
        return
    
    database = await get_database()
    contacts = await database.contacts.find(
        {"name": {"$regex": query, "$options": "i"}},
        {"_id": 0}
    ).to_list(20)
    
    if contacts:
        lines = [f"🔍 <b>Search results for '{query}':</b>\n"]
        for c in contacts:
            lines.append(f"• {c['name']} ({c['phone']})")
        lines.append(f"\nFound {len(contacts)} contact(s)")
        await send_telegram_message(token, chat_id, "\n".join(lines))
    else:
        await send_telegram_message(token, chat_id, f"❌ No contacts found matching '{query}'")
