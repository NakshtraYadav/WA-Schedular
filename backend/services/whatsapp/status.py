"""WhatsApp status checking functionality"""
import httpx
from core.config import WA_SERVICE_URL
from core.logging import logger


async def get_wa_status() -> dict:
    """Get WhatsApp connection status"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp status error: {e}")
        return {"isReady": False, "isAuthenticated": False, "hasQrCode": False, "error": str(e)}


async def get_wa_qr() -> dict:
    """Get WhatsApp QR code for authentication"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/qr", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp QR error: {e}")
        return {"qrCode": None, "error": str(e)}


async def logout_wa() -> dict:
    """Logout from WhatsApp"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/logout", timeout=10.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp logout error: {e}")
        return {"success": False, "error": str(e)}


async def retry_wa_init() -> dict:
    """Retry WhatsApp initialization"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/retry-init", timeout=5.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp retry error: {e}")
        return {"success": False, "error": str(e)}


async def clear_wa_session() -> dict:
    """Clear WhatsApp session"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(f"{WA_SERVICE_URL}/clear-session", timeout=10.0)
            return response.json()
    except Exception as e:
        logger.error(f"WhatsApp clear session error: {e}")
        return {"success": False, "error": str(e)}


async def test_wa_browser() -> dict:
    """Test browser launch for WhatsApp"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/test-browser", timeout=30.0)
            return response.json()
    except Exception as e:
        return {"success": False, "error": str(e)}


async def get_wa_contacts() -> dict:
    """Get contacts from WhatsApp"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/contacts", timeout=30.0)
            return response.json()
    except httpx.TimeoutException:
        return {"success": False, "error": "WhatsApp service timeout", "contacts": []}
    except Exception as e:
        logger.error(f"WhatsApp contacts error: {e}")
        return {"success": False, "error": str(e), "contacts": []}
