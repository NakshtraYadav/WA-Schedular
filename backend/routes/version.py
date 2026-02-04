"""Version routes"""
from fastapi import APIRouter
from core.config import ROOT_DIR
from services.updates import get_version_info

router = APIRouter()


@router.get("/version")
async def get_app_version():
    """Get application version info"""
    version_info = get_version_info()
    
    git_sha_file = ROOT_DIR.parent / ".version"
    git_sha = "unknown"
    if git_sha_file.exists():
        git_sha = git_sha_file.read_text().strip()[:7]
    
    return {
        "version": version_info.get("version", "1.0.0"),
        "build": version_info.get("build", 1),
        "name": version_info.get("name", "WhatsApp Scheduler"),
        "app_name": version_info.get("name", "WhatsApp Scheduler"),
        "release_date": version_info.get("release_date", "unknown"),
        "git_sha": git_sha,
        "repository": version_info.get("repository"),
        "changelog": version_info.get("changelog", [])[:3]
    }
