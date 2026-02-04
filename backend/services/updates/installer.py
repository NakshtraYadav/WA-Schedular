"""Update installation functionality"""
import subprocess
import os
from core.config import ROOT_DIR
from core.logging import logger


async def install_update() -> dict:
    """Trigger fast update installation"""
    start_script = ROOT_DIR.parent / "start.sh"
    
    if not start_script.exists():
        return {"success": False, "error": "start.sh not found"}
    
    is_git = (ROOT_DIR.parent / ".git").exists()
    
    try:
        # Run update directly (it's fast now, ~3 seconds)
        result = subprocess.run(
            ["bash", str(start_script), "update"],
            cwd=str(ROOT_DIR.parent),
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            return {
                "success": True,
                "method": "hot_reload",
                "message": "Updated! Changes applied via hot reload.",
                "estimated_time": "1-3 seconds"
            }
        else:
            return {
                "success": False,
                "error": result.stderr or "Update failed"
            }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Update timed out"}
    except Exception as e:
        logger.error(f"Failed to update: {e}")
        return {"success": False, "error": str(e)}
