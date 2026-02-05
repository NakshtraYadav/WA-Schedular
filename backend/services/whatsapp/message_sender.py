"""WhatsApp message sending functionality"""
import asyncio
from core.config import WA_SERVICE_URL
from core.logging import logger
from core.http_client import get_http_client


async def send_whatsapp_message(phone: str, message: str, max_retries: int = 3) -> dict:
    """Send a WhatsApp message via the WA service with retry logic
    
    DURABILITY FEATURES:
    - Retries up to 3 times with exponential backoff
    - Handles transient network failures
    - Does NOT retry if WhatsApp explicitly rejects (invalid number)
    """
    http_client = await get_http_client()
    last_error = None
    
    for attempt in range(max_retries):
        try:
            response = await http_client.post(
                f"{WA_SERVICE_URL}/send",
                json={"phone": phone, "message": message},
                timeout=30.0
            )
            result = response.json()
            
            if result.get('success'):
                if attempt > 0:
                    logger.info(f"✅ Message sent on retry {attempt + 1}")
                return result
            
            last_error = result.get('error', 'Unknown error')
            
            # Don't retry for permanent failures
            permanent_failures = [
                'not registered',
                'invalid number', 
                'not on whatsapp',
                'blocked'
            ]
            if any(pf in last_error.lower() for pf in permanent_failures):
                logger.warning(f"Permanent failure, not retrying: {last_error}")
                return result
                
        except Exception as e:
            last_error = str(e)
        
        # Retry with exponential backoff (1s, 2s, 4s)
        if attempt < max_retries - 1:
            delay = 2 ** attempt
            logger.warning(f"📡 Send attempt {attempt + 1} failed, retrying in {delay}s: {last_error}")
            await asyncio.sleep(delay)
    
    logger.error(f"❌ Send failed after {max_retries} attempts: {last_error}")
    return {"success": False, "error": f"Failed after {max_retries} attempts: {last_error}"}
