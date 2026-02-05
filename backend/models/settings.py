"""Settings models"""
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Literal
from datetime import datetime, timezone


class Settings(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = "settings"
    telegram_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: bool = False
    timezone: Optional[str] = None
    # AI Settings
    openai_api_key: Optional[str] = None
    openai_model: Literal["gpt-4o-mini", "gpt-4o"] = "gpt-4o-mini"
    ai_enabled: bool = False
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class SettingsUpdate(BaseModel):
    telegram_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: bool = False
    timezone: Optional[str] = None
    # AI Settings
    openai_api_key: Optional[str] = None
    openai_model: Optional[Literal["gpt-4o-mini", "gpt-4o"]] = None
    ai_enabled: Optional[bool] = None
