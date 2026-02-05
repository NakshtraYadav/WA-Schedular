"""
WhatsApp Scheduler API - Modular Backend
Main entry point - just imports and startup
"""
import sys
from pathlib import Path

# Add backend to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware

# Core imports
from core.config import settings
from core.database import init_database, close_database, db
from core.scheduler import scheduler, start_scheduler, shutdown_scheduler
from core.logging import logger

# Routes
from routes import api_router
from routes.version import router as version_router

# Services
from services.telegram import start_telegram_bot, stop_telegram_bot
from services.scheduler.job_manager import reload_schedules

# Create the main app
app = FastAPI(title="WhatsApp Scheduler API")

# Include routers
app.include_router(api_router)
app.include_router(version_router, prefix="/api", tags=["Version"])


# Root route for http://localhost:8001/
@app.get("/")
async def root():
    """Root endpoint - service info"""
    return {
        "service": "WhatsApp Scheduler API",
        "version": "2.7.2",
        "status": "running",
        "docs": "/docs",
        "api": "/api/",
        "health": "/api/health"
    }

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Also add send-now at root level for backwards compatibility
from routes.schedules import send_message_now
app.add_api_route("/api/send-now", send_message_now, methods=["POST"], tags=["Send"])


@app.on_event("startup")
async def startup():
    """Application startup handler"""
    logger.info("Starting WhatsApp Scheduler API...")
    
    # Initialize database
    await init_database()
    
    # Start scheduler
    start_scheduler()
    logger.info("Scheduler started")
    
    # Reload existing schedules
    await reload_schedules()
    
    # Start Telegram bot if enabled
    if db is not None:
        try:
            settings_doc = await db.settings.find_one({"id": "settings"}, {"_id": 0})
            if settings_doc and settings_doc.get('telegram_enabled') and settings_doc.get('telegram_token'):
                await start_telegram_bot()
        except Exception as e:
            logger.warning(f"Could not start Telegram bot: {e}")
    
    logger.info("WhatsApp Scheduler API started successfully")


@app.on_event("shutdown")
async def shutdown():
    """Application shutdown handler"""
    logger.info("Shutting down...")
    await stop_telegram_bot()
    shutdown_scheduler()
    close_database()
    logger.info("Server shutdown complete")
