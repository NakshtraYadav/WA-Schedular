"""Scheduled message models"""
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime, timezone
import uuid


class ScheduledMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    contact_id: str
    contact_name: str
    contact_phone: str
    message: str
    schedule_type: str
    scheduled_time: Optional[datetime] = None
    cron_expression: Optional[str] = None
    cron_description: Optional[str] = None
    is_active: bool = True
    last_run: Optional[datetime] = None
    next_run: Optional[datetime] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ScheduledMessageCreate(BaseModel):
    contact_id: str
    message: str
    schedule_type: str
    scheduled_time: Optional[datetime] = None
    cron_expression: Optional[str] = None
    cron_description: Optional[str] = None
