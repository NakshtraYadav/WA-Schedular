"""Custom exceptions for the application"""
from fastapi import HTTPException

class NotFoundException(HTTPException):
    def __init__(self, resource: str):
        super().__init__(status_code=404, detail=f"{resource} not found")

class ServiceUnavailableException(HTTPException):
    def __init__(self, service: str):
        super().__init__(status_code=503, detail=f"{service} unavailable")

class ValidationException(HTTPException):
    def __init__(self, message: str):
        super().__init__(status_code=400, detail=message)
