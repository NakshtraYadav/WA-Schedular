"""WhatsApp message sending functionality"""
import httpx
from core.config import WA_SERVICE_URL
from core.logging import logger


async def send_whatsapp_message(phone: str, message: str) -> dict:
    """Send a WhatsApp message via the WA service"""
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.post(
                f"{WA_SERVICE_URL}/send",
                json={"phone": phone, "message": message},
                timeout=30.0
            )
            return response.json()
    except Exception as e:
        logger.error(f"Send message error: {e}")
        return {"success": False, "error": str(e)}
