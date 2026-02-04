"""WhatsApp HTTP client for communicating with WA service"""
import httpx
from core.config import WA_SERVICE_URL


async def whatsapp_http_client():
    """Get an HTTP client for WhatsApp service requests"""
    return httpx.AsyncClient(base_url=WA_SERVICE_URL)
