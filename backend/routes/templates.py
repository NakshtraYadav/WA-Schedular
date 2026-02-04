"""Templates routes"""
from fastapi import APIRouter, HTTPException
from typing import List
from models.template import MessageTemplate, MessageTemplateCreate
from services.templates import crud

router = APIRouter(prefix="/templates")


@router.get("", response_model=List[MessageTemplate])
async def get_templates():
    """Get all templates"""
    return await crud.get_all_templates()


@router.post("", response_model=MessageTemplate)
async def create_template(data: MessageTemplateCreate):
    """Create a new template"""
    return await crud.create_template(data)


@router.put("/{template_id}", response_model=MessageTemplate)
async def update_template(template_id: str, data: MessageTemplateCreate):
    """Update a template"""
    result = await crud.update_template(template_id, data)
    if not result:
        raise HTTPException(status_code=404, detail="Template not found")
    return result


@router.delete("/{template_id}")
async def delete_template(template_id: str):
    """Delete a template"""
    success = await crud.delete_template(template_id)
    if not success:
        raise HTTPException(status_code=404, detail="Template not found")
    return {"success": True}
