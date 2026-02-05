"""Contact models"""
from pydantic import BaseModel, Field, ConfigDict, field_validator
from typing import Optional
from datetime import datetime, timezone
import uuid


class Contact(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    phone: str
    notes: Optional[str] = None
    is_verified: Optional[bool] = None  # True=on WhatsApp, False=not found, None=not checked
    whatsapp_id: Optional[str] = None   # WhatsApp ID if verified
    verified_at: Optional[str] = None   # ISO timestamp when verified
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
