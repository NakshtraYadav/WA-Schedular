"""Contacts routes"""
from fastapi import APIRouter, HTTPException
from typing import List
from models.contact import Contact, ContactCreate
from services.contacts import crud, sync

router = APIRouter(prefix="/contacts")


@router.get("", response_model=List[Contact])
async def get_contacts():
    """Get all contacts"""
    return await crud.get_all_contacts()


@router.post("", response_model=Contact)
async def create_contact(data: ContactCreate):
    """Create a new contact"""
    return await crud.create_contact(data)


@router.put("/{contact_id}", response_model=Contact)
async def update_contact(contact_id: str, data: ContactCreate):
    """Update a contact"""
    result = await crud.update_contact(contact_id, data)
    if not result:
        raise HTTPException(status_code=404, detail="Contact not found")
    return result


@router.delete("/{contact_id}")
async def delete_contact(contact_id: str):
    """Delete a contact"""
    success = await crud.delete_contact(contact_id)
    if not success:
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"success": True}


@router.post("/sync-whatsapp")
async def sync_whatsapp_contacts():
    """Sync contacts from WhatsApp"""
    return await sync.sync_from_whatsapp()
