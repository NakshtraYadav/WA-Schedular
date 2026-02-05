"""Update installation functionality"""
import subprocess
import asyncio
from pathlib import Path
from core.config import ROOT_DIR
from core.logging import logger


async def install_update() -> dict:
    """
    Smart update that works from the web UI.
    Pulls code, triggers hot reload, tells frontend to refresh.
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
        
        # Step 2: Check if dependencies changed
        diff_result = subprocess.run(
            ["git", "diff", "HEAD~1", "--name-only"],
            cwd=str(project_root),
            capture_output=True,
            text=True,
            timeout=10
        )
        
        changed_files = diff_result.stdout.strip().split('\n') if diff_result.stdout.strip() else []
        
        # Step 3: Install dependencies if needed (background, non-blocking)
        if any("package.json" in f for f in changed_files):
            logger.info("Installing npm packages...")
            subprocess.Popen(
                ["npm", "install", "--legacy-peer-deps", "--silent"],
                cwd=str(project_root / "frontend"),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        
        if any("requirements.txt" in f for f in changed_files):
            logger.info("Installing pip packages...")
            subprocess.Popen(
                ["pip", "install", "-q", "-r", "requirements.txt"],
                cwd=str(project_root / "backend"),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        
        # Step 4: Trigger hot reload by touching files
        backend_changed = any(f.startswith("backend/") for f in changed_files)
        frontend_changed = any(f.startswith("frontend/src/") for f in changed_files)
        
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
            "refresh_required": frontend_changed or any("package.json" in f for f in changed_files)
        }
        
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Update timed out"}
    except Exception as e:
        logger.error(f"Update failed: {e}")
        return {"success": False, "error": str(e)}
