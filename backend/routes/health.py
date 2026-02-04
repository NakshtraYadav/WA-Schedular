"""Health check routes"""
from fastapi import APIRouter
import httpx
from core.database import get_database
from core.config import WA_SERVICE_URL

router = APIRouter()


@router.get("/")
async def root():
    """API root - health check"""
    return {"message": "WhatsApp Scheduler API", "status": "running"}


@router.get("/health")
async def health_check():
    """Detailed health check"""
    health = {
        "status": "healthy",
        "api": True,
        "database": False,
        "whatsapp_service": False
    }
    
    # Check database
    try:
        database = await get_database()
        await database.command('ping')
        health["database"] = True
    except Exception as e:
        health["status"] = "degraded"
        health["database_error"] = str(e)
    
    # Check WhatsApp service
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/health", timeout=3.0)
            health["whatsapp_service"] = response.status_code == 200
    except:
        pass
    
    return health
