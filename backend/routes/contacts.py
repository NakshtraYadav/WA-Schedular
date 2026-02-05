"""Contacts routes"""
from fastapi import APIRouter, HTTPException, Body
from typing import List
from pydantic import BaseModel
from datetime import datetime, timezone
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
async def verify_bulk_numbers(phones: List[str] = Body(...), update_db: bool = True):
    """Check multiple phone numbers at once. Send as JSON array: ["phone1", "phone2"]"""
    if not phones:
        return {"success": False, "error": "No phone numbers provided"}
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{WA_SERVICE_URL}/verify",
                json={"phones": phones},
                timeout=180.0  # 3 minutes for bulk verification (~1-2s per number)
            )
            result = response.json()
            
            # Update contacts in database with verification status
            if update_db and result.get("success") and result.get("results"):
                from core.database import get_database
                database = await get_database()
                for r in result["results"]:
                    # Update by both original phone and clean number
                    await database.contacts.update_many(
                        {"$or": [{"phone": r["phone"]}, {"phone": r.get("cleanNumber", "")}]},
                        {"$set": {
                            "is_verified": r["isRegistered"],
                            "whatsapp_id": r.get("whatsappId"),
                            "verified_at": datetime.now(timezone.utc).isoformat() if r["isRegistered"] else None
                        }}
                    )
            
            return result
    except httpx.TimeoutException:
        return {"success": False, "error": f"Verification timed out. Try with fewer contacts (you sent {len(phones)})."}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.post("/verify-single/{phone}")
async def verify_single_number(phone: str):
    """Verify a single phone number and update database"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{WA_SERVICE_URL}/verify",
                json={"phones": [phone]},
                timeout=30.0
            )
            result = response.json()
            
            if result.get("success") and result.get("results"):
                from core.database import get_database
                database = await get_database()
                r = result["results"][0]
                
                # Update contact in database
                update_result = await database.contacts.update_many(
                    {"$or": [{"phone": r["phone"]}, {"phone": r.get("cleanNumber", "")}]},
                    {"$set": {
                        "is_verified": r["isRegistered"],
                        "whatsapp_id": r.get("whatsappId"),
                        "verified_at": datetime.now(timezone.utc).isoformat() if r["isRegistered"] else None
                    }}
                )
                
                return {
                    "success": True,
                    "phone": phone,
                    "isRegistered": r["isRegistered"],
                    "whatsappId": r.get("whatsappId"),
                    "updated": update_result.modified_count
                }
            
            return result
    except Exception as e:
        return {"success": False, "phone": phone, "error": str(e)}


@router.delete("/unverified")
async def delete_unverified_contacts():
    """Delete all contacts that are not verified on WhatsApp"""
    try:
        from core.database import get_database
        database = await get_database()
        result = await database.contacts.delete_many({"is_verified": False})
        return {
            "success": True,
            "deleted_count": result.deleted_count,
            "message": f"Removed {result.deleted_count} unverified contacts"
        }
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
