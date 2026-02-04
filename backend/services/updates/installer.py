"""Update installation functionality"""
import subprocess
import os
from core.config import ROOT_DIR
from core.logging import logger


async def install_update() -> dict:
    """Trigger fast update installation"""
    update_script = ROOT_DIR.parent / "update.sh"
    
    if not update_script.exists():
        return {"success": False, "error": "update.sh not found"}
    
    is_git = (ROOT_DIR.parent / ".git").exists()
    
    try:
        wrapper_script = ROOT_DIR.parent / ".update_runner.sh"
        
        with open(wrapper_script, 'w') as f:
            f.write(f"""#!/bin/bash
# Auto-generated update wrapper
sleep 2  # Wait for API response
cd "{ROOT_DIR.parent}"
./update.sh fast >> logs/system/update.log 2>&1
rm -f "{wrapper_script}"
""")
        
        os.chmod(wrapper_script, 0o755)
        
        subprocess.Popen(
            ["nohup", "bash", str(wrapper_script)],
            cwd=str(ROOT_DIR.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True
        )
        
        return {
            "success": True,
            "method": "git_pull" if is_git else "zip_download",
            "message": "Update starting..." + (" (fast mode)" if is_git else " (this may take a few minutes)"),
            "estimated_time": "10-30 seconds" if is_git else "2-3 minutes"
        }
    except Exception as e:
        logger.error(f"Failed to start update: {e}")
        return {"success": False, "error": str(e)}
