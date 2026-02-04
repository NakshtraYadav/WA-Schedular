"""Template CRUD operations"""
from datetime import datetime
from core.database import get_database
from models.template import MessageTemplate, MessageTemplateCreate


async def get_all_templates() -> list:
    """Get all templates"""
    database = await get_database()
    templates = await database.templates.find({}, {"_id": 0}).to_list(1000)
    for t in templates:
        if isinstance(t.get('created_at'), str):
            t['created_at'] = datetime.fromisoformat(t['created_at'])
    return templates


async def create_template(data: MessageTemplateCreate) -> MessageTemplate:
    """Create a new template"""
    database = await get_database()
    template = MessageTemplate(**data.model_dump())
    doc = template.model_dump()
    doc['created_at'] = doc['created_at'].isoformat()
    await database.templates.insert_one(doc)
    return template


async def update_template(template_id: str, data: MessageTemplateCreate) -> MessageTemplate:
    """Update a template"""
    database = await get_database()
    existing = await database.templates.find_one({"id": template_id}, {"_id": 0})
    if not existing:
        return None
    
    update_data = data.model_dump()
    await database.templates.update_one({"id": template_id}, {"$set": update_data})
    
    updated = await database.templates.find_one({"id": template_id}, {"_id": 0})
    if isinstance(updated.get('created_at'), str):
        updated['created_at'] = datetime.fromisoformat(updated['created_at'])
    return MessageTemplate(**updated)


async def delete_template(template_id: str) -> bool:
    """Delete a template"""
    database = await get_database()
    result = await database.templates.delete_one({"id": template_id})
    return result.deleted_count > 0
