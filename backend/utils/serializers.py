"""MongoDB serialization utilities"""
from datetime import datetime


def serialize_mongodb_doc(doc: dict, exclude_id: bool = True) -> dict:
    """Serialize MongoDB document for JSON response"""
    if doc is None:
        return None
    
    result = {}
    for key, value in doc.items():
        if exclude_id and key == '_id':
            continue
        if isinstance(value, datetime):
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result
