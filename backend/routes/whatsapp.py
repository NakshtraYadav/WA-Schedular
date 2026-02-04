"""WhatsApp routes"""
from fastapi import APIRouter, HTTPException
import httpx
from core.config import WA_SERVICE_URL
from core.logging import logger

router = APIRouter(prefix="/whatsapp")


@router.get("/status")
async def get_whatsapp_status():
    """Get WhatsApp connection status"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp status error: {e}")
        return {"isReady": False, "isAuthenticated": False, "hasQrCode": False, "error": str(e)}


@router.get("/qr")
async def get_whatsapp_qr():
    """Get WhatsApp QR code for authentication"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/qr", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp QR error: {e}")
        return {"qrCode": None, "error": str(e)}


@router.post("/logout")
async def logout_whatsapp():
    """Logout from WhatsApp"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/logout", timeout=10.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp logout error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/retry")
async def retry_whatsapp_init():
    """Retry WhatsApp initialization"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/retry-init", timeout=5.0)
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/clear-session")
async def clear_whatsapp_session():
    """Clear WhatsApp session and restart"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/clear-session", timeout=10.0)
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/test-browser")
async def test_browser():
    """Test if browser can be launched"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/test-browser", timeout=30.0)
            return response.json()
    except Exception as e:
        return {"success": False, "error": str(e)}
