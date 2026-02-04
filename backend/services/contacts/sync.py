"""Contact sync from WhatsApp"""
from core.database import get_database
from core.logging import logger
from models.contact import Contact
from services.whatsapp.status import get_wa_contacts


async def sync_from_whatsapp() -> dict:
    """Sync contacts from WhatsApp"""
    try:
        result = await get_wa_contacts()
        
        if not result.get('success', True) and 'error' in result:
            return {"success": False, "error": result['error'], "imported": 0}
        
        wa_contacts = result.get("contacts", [])
        
        if not wa_contacts:
            return {"success": True, "message": "No contacts found in WhatsApp", "imported": 0}
        
        database = await get_database()
        imported = 0
        skipped = 0
        
        for wa_contact in wa_contacts:
            phone = wa_contact.get("number", "").replace("@c.us", "")
            name = wa_contact.get("name") or wa_contact.get("pushname") or phone
            
            if not phone:
                continue
            
            existing = await database.contacts.find_one({"phone": phone}, {"_id": 0})
            
            if existing:
                skipped += 1
                continue
            
            contact = Contact(
                name=name,
                phone=phone,
                notes="Synced from WhatsApp"
            )
            doc = contact.model_dump()
            doc['created_at'] = doc['created_at'].isoformat()
            await database.contacts.insert_one(doc)
            imported += 1
        
        return {
            "success": True,
            "imported": imported,
            "skipped": skipped,
            "total_found": len(wa_contacts),
            "message": f"Imported {imported} contacts, skipped {skipped} duplicates"
        }
    except Exception as e:
        logger.error(f"Contact sync error: {e}")
        return {"success": False, "error": str(e), "imported": 0}
