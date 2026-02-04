"""Contacts business logic"""
from .crud import create_contact, update_contact, delete_contact, get_all_contacts
from .sync import sync_from_whatsapp

__all__ = [
    'create_contact', 'update_contact', 'delete_contact', 'get_all_contacts',
    'sync_from_whatsapp'
]
