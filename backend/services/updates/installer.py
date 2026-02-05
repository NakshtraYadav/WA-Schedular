"""Update installation functionality"""
import subprocess
import asyncio
from pathlib import Path
from core.config import ROOT_DIR
from core.logging import logger


async def install_update() -> dict:
    """
    Smart update that works from the web UI.
    Determines what kind of restart is needed:
    - none: Just config changes
    - frontend_refresh: Frontend code changed, browser refresh needed
    - backend_restart: Backend code changed, server will auto-restart via hot reload
    - full_restart: Dependencies or WhatsApp service changed, need full restart
    """
    project_root = ROOT_DIR.parent
    
    if not (project_root / ".git").exists():
        return {"success": False, "error": "Not a git repository"}
    
    try:
        # Step 1: Git pull
        logger.info("Starting update: git pull...")
        
        pull_result = subprocess.run(
            ["git", "pull", "origin", "main", "--quiet"],
            cwd=str(project_root),
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if pull_result.returncode != 0:
            return {"success": False, "error": f"Git pull failed: {pull_result.stderr}"}
        
        # Step 2: Check what changed
        diff_result = subprocess.run(
            ["git", "diff", "HEAD~1", "--name-only"],
            cwd=str(project_root),
            capture_output=True,
            text=True,
            timeout=10
        )
        
        changed_files = diff_result.stdout.strip().split('\n') if diff_result.stdout.strip() else []
        
        # Categorize changes
        backend_changed = any(f.startswith("backend/") and not f.endswith(".txt") for f in changed_files)
        frontend_changed = any(f.startswith("frontend/src/") for f in changed_files)
        whatsapp_changed = any(f.startswith("whatsapp-service/") for f in changed_files)
        package_json_changed = any("package.json" in f for f in changed_files)
        requirements_changed = any("requirements.txt" in f for f in changed_files)
        config_only = all(f.endswith(('.json', '.md', '.env.example', '.gitignore')) for f in changed_files)
        
        # Determine restart type
        if requirements_changed or package_json_changed or whatsapp_changed:
            restart_type = "full_restart"
            restart_message = "Full restart required (./stop.sh && ./start.sh)"
        elif backend_changed and frontend_changed:
            restart_type = "both"
            restart_message = "Backend will auto-restart, refresh browser for frontend"
        elif backend_changed:
            restart_type = "backend_only"
            restart_message = "Backend will auto-restart (hot reload)"
        elif frontend_changed:
            restart_type = "frontend_refresh"
            restart_message = "Refresh your browser to see frontend changes"
        elif config_only:
            restart_type = "none"
            restart_message = "No restart needed"
        else:
            restart_type = "unknown"
            restart_message = "Restart recommended to be safe"
        
        # Step 3: Install dependencies if needed (background, non-blocking)
        if package_json_changed:
            logger.info("Installing npm packages...")
            subprocess.Popen(
                ["npm", "install", "--legacy-peer-deps", "--silent"],
                cwd=str(project_root / "frontend"),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        
        if requirements_changed:
            logger.info("Installing pip packages...")
            subprocess.Popen(
                ["pip", "install", "-q", "-r", "requirements.txt"],
                cwd=str(project_root / "backend"),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        
        # Step 4: Trigger hot reload by touching files
        if backend_changed:
            (project_root / "backend" / "server.py").touch()
            logger.info("Backend hot reload triggered")
        
        if frontend_changed:
            # Touch index.js to trigger webpack rebuild
            (project_root / "frontend" / "src" / "index.js").touch()
            logger.info("Frontend hot reload triggered")
        
        # Step 5: Get new version
        from services.updates.version import get_version_info
        new_version = get_version_info()
        
        return {
            "success": True,
            "message": "Update complete!",
            "new_version": new_version.get("version", "unknown"),
            "files_changed": len(changed_files),
            "changed_files": changed_files[:10],  # First 10 for display
            "restart_type": restart_type,
            "restart_message": restart_message,
            "refresh_required": frontend_changed or package_json_changed,
            "full_restart_required": requirements_changed or package_json_changed or whatsapp_changed
        }
        
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Update timed out"}
    except Exception as e:
        logger.error(f"Update failed: {e}")
        return {"success": False, "error": str(e)}
