"""Shared HTTP client with connection pooling"""
import httpx
from .logging import logger

_client = None

async def get_http_client() -> httpx.AsyncClient:
    """Get or create shared HTTP client with connection pooling"""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=30.0,
            limits=httpx.Limits(max_connections=50, max_keepalive_connections=10)
        )
        logger.info("Shared HTTP client initialized")
    return _client

async def close_http_client():
    """Close shared HTTP client on shutdown"""
    global _client
    if _client:
        await _client.aclose()
        _client = None
        logger.info("Shared HTTP client closed")
