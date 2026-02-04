"""Datetime utilities"""
from datetime import datetime, timezone


def format_datetime(dt: datetime) -> str:
    """Format datetime to ISO string"""
    if dt is None:
        return None
    return dt.isoformat()


def parse_datetime(dt_str: str) -> datetime:
    """Parse ISO datetime string"""
    if dt_str is None:
        return None
    return datetime.fromisoformat(dt_str)


def now_utc() -> datetime:
    """Get current UTC datetime"""
    return datetime.now(timezone.utc)
