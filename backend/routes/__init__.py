from fastapi import APIRouter
from .health import router as health_router
from .whatsapp import router as whatsapp_router
from .contacts import router as contacts_router
from .templates import router as templates_router
from .schedules import router as schedules_router
from .logs import router as logs_router
from .settings import router as settings_router
from .updates import router as updates_router
from .diagnostics import router as diagnostics_router
from .dashboard import router as dashboard_router
from .telegram import router as telegram_router

# Create the main API router
api_router = APIRouter(prefix="/api")

# Include all sub-routers
api_router.include_router(health_router, tags=["Health"])
api_router.include_router(whatsapp_router, tags=["WhatsApp"])
api_router.include_router(contacts_router, tags=["Contacts"])
api_router.include_router(templates_router, tags=["Templates"])
api_router.include_router(schedules_router, tags=["Schedules"])
api_router.include_router(logs_router, tags=["Logs"])
api_router.include_router(settings_router, tags=["Settings"])
api_router.include_router(updates_router, tags=["Updates"])
api_router.include_router(diagnostics_router, tags=["Diagnostics"])
api_router.include_router(dashboard_router, tags=["Dashboard"])
api_router.include_router(telegram_router, tags=["Telegram"])

__all__ = ['api_router']
