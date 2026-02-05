"""Contacts routes"""
from fastapi import APIRouter, HTTPException, Body
from typing import List
from pydantic import BaseModel
import httpx
from models.contact import Contact, ContactCreate
from services.contacts import crud, sync
from core.config import WA_SERVICE_URL

router = APIRouter(prefix="/contacts")


class PhoneList(BaseModel):
    phones: List[str]


@router.get("", response_model=List[Contact])
async def get_contacts():
    """Get all contacts"""
    return await crud.get_all_contacts()


@router.post("", response_model=Contact)
async def create_contact(data: ContactCreate, verify: bool = True):
    """Create a new contact. Set verify=false to skip WhatsApp verification."""
    if verify:
        # Verify the number is on WhatsApp first
        verification = await verify_whatsapp_number(data.phone)
        if not verification.get("isRegistered"):
            raise HTTPException(
                status_code=400, 
                detail=f"Phone number {data.phone} is not registered on WhatsApp"
            )
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


@router.get("/verify/{phone}")
async def verify_contact_number(phone: str):
    """Check if a phone number is registered on WhatsApp"""
    return await verify_whatsapp_number(phone)


@router.post("/verify-bulk")
async def verify_bulk_numbers(phones: List[str] = Body(...)):
    """Check multiple phone numbers at once. Send as JSON array: ["phone1", "phone2"]"""
    if not phones:
        return {"success": False, "error": "No phone numbers provided"}
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{WA_SERVICE_URL}/verify",
                json={"phones": phones},
                timeout=60.0  # Longer timeout for bulk
            )
            return response.json()
    except Exception as e:
        return {"success": False, "error": str(e)}


async def verify_whatsapp_number(phone: str) -> dict:
    """Helper to verify a single number"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{WA_SERVICE_URL}/verify/{phone}",
                timeout=10.0
            )
            return response.json()
    except Exception as e:
        return {"success": False, "error": str(e), "isRegistered": False}
