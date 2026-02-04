"""Message template models"""
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime, timezone
import uuid


class MessageTemplate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    content: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class MessageTemplateCreate(BaseModel):
    title: str
    content: str
