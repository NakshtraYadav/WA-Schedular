"""Application configuration and environment variables"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment
ROOT_DIR = Path(__file__).parent.parent
load_dotenv(ROOT_DIR / '.env')

class Settings:
    """Application settings"""
    MONGO_URL: str = os.environ.get('MONGO_URL', 'mongodb://localhost:27017')
    DB_NAME: str = os.environ.get('DB_NAME', 'whatsapp_scheduler')
    WA_SERVICE_URL: str = os.environ.get('WA_SERVICE_URL', 'http://localhost:3001')
    
settings = Settings()

# Convenience exports
WA_SERVICE_URL = settings.WA_SERVICE_URL
