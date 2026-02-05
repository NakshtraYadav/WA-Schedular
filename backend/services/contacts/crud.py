"""Contact CRUD operations"""
from datetime import datetime
from core.database import get_database
from models.contact import Contact, ContactCreate


async def get_all_contacts() -> list:
    """Get all contacts sorted by name A-Z"""
    database = await get_database()
    contacts = await database.contacts.find({}, {"_id": 0}).sort("name", 1).to_list(1000)
    for c in contacts:
        if isinstance(c.get('created_at'), str):
            c['created_at'] = datetime.fromisoformat(c['created_at'])
    return contacts


async def create_contact(data: ContactCreate) -> Contact:
    """Create a new contact"""
    database = await get_database()
    contact = Contact(**data.model_dump())
    doc = contact.model_dump()
    doc['created_at'] = doc['created_at'].isoformat()
    await database.contacts.insert_one(doc)
    return contact


async def update_contact(contact_id: str, data: ContactCreate) -> Contact:
    """Update a contact"""
    database = await get_database()
    existing = await database.contacts.find_one({"id": contact_id}, {"_id": 0})
    if not existing:
        return None
    
    update_data = data.model_dump()
    await database.contacts.update_one({"id": contact_id}, {"$set": update_data})
    
    updated = await database.contacts.find_one({"id": contact_id}, {"_id": 0})
    if isinstance(updated.get('created_at'), str):
        updated['created_at'] = datetime.fromisoformat(updated['created_at'])
    return Contact(**updated)


async def delete_contact(contact_id: str) -> bool:
    """Delete a contact"""
    database = await get_database()
    result = await database.contacts.delete_one({"id": contact_id})
    return result.deleted_count > 0
