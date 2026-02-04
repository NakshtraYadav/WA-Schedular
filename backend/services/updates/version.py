"""Version info management"""
import json
from core.config import ROOT_DIR
from core.logging import logger


def get_version_info() -> dict:
    """Load version info from version.json"""
    version_file = ROOT_DIR.parent / "version.json"
    default_info = {
        "version": "1.0.0",
        "name": "WhatsApp Scheduler",
        "build": 1,
        "release_date": "unknown",
        "changelog": []
    }
    
    if version_file.exists():
        try:
            with open(version_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Failed to load version.json: {e}")
    return default_info


VERSION_INFO = get_version_info()
GITHUB_REPO = VERSION_INFO.get("repository", "NakshtraYadav/WA-Schedular")
GITHUB_BRANCH = VERSION_INFO.get("branch", "main")
