"""MongoDB database connection management"""
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from fastapi import HTTPException
from .config import settings
from .logging import logger

# MongoDB connection globals
client = None
db = None
_db_lock = asyncio.Lock()

async def get_database():
    """Get or create database connection with thread-safe locking"""
    global client, db
    async with _db_lock:
        if client is None:
            try:
                client = AsyncIOMotorClient(settings.MONGO_URL, serverSelectionTimeoutMS=5000)
                await client.admin.command('ping')
                db = client[settings.DB_NAME]
                logger.info(f"Connected to MongoDB: {settings.MONGO_URL}")
            except Exception as e:
                logger.error(f"MongoDB connection failed: {e}")
                raise HTTPException(status_code=503, detail=f"Database unavailable: {e}")
    return db

async def init_database():
    """Initialize database connection at startup"""
    global client, db
    try:
        client = AsyncIOMotorClient(settings.MONGO_URL, serverSelectionTimeoutMS=5000)
        await client.admin.command('ping')
        db = client[settings.DB_NAME]
        logger.info(f"Connected to MongoDB: {settings.MONGO_URL}")
        return True
    except Exception as e:
        logger.warning(f"MongoDB not available at startup: {e}")
        logger.warning("API will retry connection on first request")
        return False

def close_database():
    """Close database connection"""
    global client
    if client:
        client.close()
        logger.info("Database connection closed")
