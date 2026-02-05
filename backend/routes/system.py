"""System management routes - Updates, Restarts, Health"""
import asyncio
import subprocess
import os
import json
from datetime import datetime, timezone
from pathlib import Path
from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from core.config import ROOT_DIR
from core.logging import logger

router = APIRouter(prefix="/system")

# Update state tracking (in-memory)
update_state = {
    "status": "idle",  # idle | checking | updating | restarting | complete | failed
    "started_at": None,
    "completed_at": None,
    "progress": [],
    "error": None,
    "result": None
}

PROJECT_ROOT = ROOT_DIR.parent


class UpdateStatus(BaseModel):
    status: str
    started_at: Optional[str]
    completed_at: Optional[str]
    progress: List[str]
    error: Optional[str]
    result: Optional[dict]


def add_progress(message: str):
    """Add a progress message"""
    timestamp = datetime.now(timezone.utc).strftime("%H:%M:%S")
    update_state["progress"].append(f"[{timestamp}] {message}")
    logger.info(f"[UPDATE] {message}")


async def run_command(cmd: list, cwd: str = None, timeout: int = 60) -> tuple:
    """Run a command asynchronously"""
    try:
        process = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=cwd or str(PROJECT_ROOT),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await asyncio.wait_for(
            process.communicate(), 
            timeout=timeout
        )
        return process.returncode, stdout.decode(), stderr.decode()
    except asyncio.TimeoutError:
        process.kill()
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)


async def perform_update():
    """Background task to perform the update"""
    global update_state
    
    try:
        update_state["status"] = "checking"
        add_progress("Starting update process...")
        
        # Step 1: Check git status
        add_progress("Checking for updates...")
        returncode, stdout, stderr = await run_command(
            ["git", "fetch", "origin", "main"],
            timeout=30
        )
        if returncode != 0:
            raise Exception(f"Git fetch failed: {stderr}")
        
        # Check if updates available
        returncode, local_hash, _ = await run_command(["git", "rev-parse", "HEAD"])
        returncode, remote_hash, _ = await run_command(["git", "rev-parse", "origin/main"])
        
        local_hash = local_hash.strip()
        remote_hash = remote_hash.strip()
        
        if local_hash == remote_hash:
            add_progress("Already up to date!")
            update_state["status"] = "complete"
            update_state["result"] = {
                "updated": False,
                "message": "Already up to date",
                "version": local_hash[:7]
            }
            return
        
        add_progress(f"Update available: {local_hash[:7]} → {remote_hash[:7]}")
        
        # Step 2: Create rollback point
        update_state["status"] = "updating"
        add_progress("Creating rollback snapshot...")
        snapshot_dir = PROJECT_ROOT / ".snapshots"
        snapshot_dir.mkdir(exist_ok=True)
        (snapshot_dir / "last-known-good").write_text(local_hash)
        
        # Step 3: Pull updates
        add_progress("Pulling latest code...")
        returncode, stdout, stderr = await run_command(
            ["git", "pull", "origin", "main", "--quiet"],
            timeout=60
        )
        if returncode != 0:
            raise Exception(f"Git pull failed: {stderr}")
        
        # Step 4: Check what changed
        add_progress("Analyzing changes...")
        returncode, diff_output, _ = await run_command(
            ["git", "diff", f"{local_hash}..{remote_hash}", "--name-only"]
        )
        changed_files = diff_output.strip().split('\n') if diff_output.strip() else []
        
        # Categorize changes
        backend_changed = any(f.startswith("backend/") for f in changed_files)
        frontend_changed = any(f.startswith("frontend/") for f in changed_files)
        whatsapp_changed = any(f.startswith("whatsapp-service/") for f in changed_files)
        package_json_changed = any("package.json" in f for f in changed_files)
        requirements_changed = any("requirements.txt" in f for f in changed_files)
        
        # Step 5: Install dependencies if needed
        if package_json_changed:
            add_progress("Installing npm packages (frontend)...")
            await run_command(
                ["npm", "install", "--legacy-peer-deps", "--silent"],
                cwd=str(PROJECT_ROOT / "frontend"),
                timeout=120
            )
            
            if whatsapp_changed:
                add_progress("Installing npm packages (whatsapp-service)...")
                await run_command(
                    ["npm", "install", "--silent"],
                    cwd=str(PROJECT_ROOT / "whatsapp-service"),
                    timeout=120
                )
        
        if requirements_changed:
            add_progress("Installing Python packages...")
            pip_cmd = str(PROJECT_ROOT / "backend" / "venv" / "bin" / "pip")
            if not os.path.exists(pip_cmd):
                pip_cmd = "pip3"
            await run_command(
                [pip_cmd, "install", "-q", "-r", "requirements.txt"],
                cwd=str(PROJECT_ROOT / "backend"),
                timeout=120
            )
        
        # Step 6: Trigger restarts
        needs_full_restart = whatsapp_changed or package_json_changed or requirements_changed
        
        if needs_full_restart:
            update_state["status"] = "restarting"
            add_progress("Triggering graceful restart...")
            
            # Check if PM2 is available
            returncode, _, _ = await run_command(["which", "pm2"])
            
            if returncode == 0:
                # Use PM2 graceful reload
                add_progress("Using PM2 graceful reload...")
                await run_command(["pm2", "reload", "ecosystem.config.js", "--update-env"], timeout=60)
            else:
                # Fallback: trigger via script
                add_progress("Using fallback restart method...")
                script_path = PROJECT_ROOT / "scripts" / "zero-touch-update.sh"
                if script_path.exists():
                    # Just signal - don't wait for full restart
                    subprocess.Popen(
                        ["bash", str(script_path)],
                        cwd=str(PROJECT_ROOT),
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        start_new_session=True
                    )
                    add_progress("Restart initiated (services will restart in background)")
        else:
            # Hot reload is sufficient
            if backend_changed:
                add_progress("Triggering backend hot reload...")
                (PROJECT_ROOT / "backend" / "server.py").touch()
            
            if frontend_changed:
                add_progress("Triggering frontend hot reload...")
                (PROJECT_ROOT / "frontend" / "src" / "index.js").touch()
        
        # Step 7: Get new version
        add_progress("Reading new version...")
        version_file = PROJECT_ROOT / "version.json"
        new_version = "unknown"
        if version_file.exists():
            try:
                version_data = json.loads(version_file.read_text())
                new_version = version_data.get("version", "unknown")
            except Exception:
                pass
        
        # Complete
        update_state["status"] = "complete"
        update_state["completed_at"] = datetime.now(timezone.utc).isoformat()
        update_state["result"] = {
            "updated": True,
            "old_version": local_hash[:7],
            "new_version": new_version,
            "files_changed": len(changed_files),
            "restart_required": needs_full_restart,
            "restart_initiated": needs_full_restart
        }
        add_progress(f"✓ Update complete! Version: {new_version}")
        
    except Exception as e:
        update_state["status"] = "failed"
        update_state["error"] = str(e)
        add_progress(f"✗ Update failed: {e}")
        logger.error(f"Update failed: {e}")


async def perform_restart():
    """Background task to perform graceful restart"""
    global update_state
    
    try:
        update_state["status"] = "restarting"
        add_progress("Initiating graceful restart...")
        
        # Check if PM2 is available
        returncode, _, _ = await run_command(["which", "pm2"])
        
        if returncode == 0:
            add_progress("Using PM2 graceful reload...")
            
            # Reload WhatsApp first (longest shutdown)
            add_progress("Reloading WhatsApp service (30s graceful shutdown)...")
            await run_command(["pm2", "reload", "wa-whatsapp", "--update-env"], timeout=60)
            
            add_progress("Reloading Backend service...")
            await run_command(["pm2", "reload", "wa-backend", "--update-env"], timeout=30)
            
            add_progress("Reloading Frontend service...")
            await run_command(["pm2", "reload", "wa-frontend", "--update-env"], timeout=30)
            
            add_progress("✓ PM2 graceful restart complete")
        else:
            add_progress("PM2 not available - using fallback restart...")
            
            # Use stop/start scripts
            stop_script = PROJECT_ROOT / "stop.sh"
            start_script = PROJECT_ROOT / "start.sh"
            
            if stop_script.exists():
                add_progress("Stopping services gracefully...")
                await run_command(["bash", str(stop_script)], timeout=45)
                await asyncio.sleep(3)
            
            if start_script.exists():
                add_progress("Starting services...")
                subprocess.Popen(
                    ["bash", str(start_script)],
                    cwd=str(PROJECT_ROOT),
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True
                )
                add_progress("✓ Services restart initiated")
        
        update_state["status"] = "complete"
        update_state["completed_at"] = datetime.now(timezone.utc).isoformat()
        update_state["result"] = {"restarted": True}
        
    except Exception as e:
        update_state["status"] = "failed"
        update_state["error"] = str(e)
        add_progress(f"✗ Restart failed: {e}")


@router.get("/update-status", response_model=UpdateStatus)
async def get_update_status():
    """Get current update/restart status"""
    return UpdateStatus(**update_state)


@router.post("/update")
async def trigger_update(background_tasks: BackgroundTasks):
    """
    Trigger a system update from GitHub.
    
    This will:
    1. Pull latest code from GitHub
    2. Install any new dependencies
    3. Gracefully restart services if needed
    4. Restore WhatsApp session automatically
    
    Returns immediately - check /api/system/update-status for progress.
    """
    global update_state
    
    if update_state["status"] in ["checking", "updating", "restarting"]:
        raise HTTPException(
            status_code=409, 
            detail=f"Update already in progress: {update_state['status']}"
        )
    
    # Reset state
    update_state = {
        "status": "checking",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": None,
        "progress": [],
        "error": None,
        "result": None
    }
    
    background_tasks.add_task(perform_update)
    
    return {
        "message": "Update started",
        "status_url": "/api/system/update-status"
    }


@router.post("/restart")
async def trigger_restart(background_tasks: BackgroundTasks):
    """
    Trigger a graceful restart of all services.
    
    This will:
    1. Pause scheduler job claims
    2. Wait for in-flight messages to complete
    3. Save WhatsApp session to MongoDB
    4. Release distributed locks
    5. Restart all services
    6. Restore WhatsApp session automatically
    
    Returns immediately - check /api/system/update-status for progress.
    """
    global update_state
    
    if update_state["status"] in ["checking", "updating", "restarting"]:
        raise HTTPException(
            status_code=409, 
            detail=f"Operation already in progress: {update_state['status']}"
        )
    
    # Reset state
    update_state = {
        "status": "restarting",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "completed_at": None,
        "progress": [],
        "error": None,
        "result": None
    }
    
    background_tasks.add_task(perform_restart)
    
    return {
        "message": "Restart initiated",
        "status_url": "/api/system/update-status"
    }


@router.post("/rollback")
async def trigger_rollback():
    """
    Rollback to the last known good version.
    
    Uses the snapshot created during the last update.
    """
    snapshot_file = PROJECT_ROOT / ".snapshots" / "last-known-good"
    
    if not snapshot_file.exists():
        raise HTTPException(
            status_code=404,
            detail="No rollback snapshot available"
        )
    
    rollback_hash = snapshot_file.read_text().strip()
    
    try:
        # Reset to snapshot
        returncode, _, stderr = await run_command(
            ["git", "reset", "--hard", rollback_hash],
            timeout=30
        )
        
        if returncode != 0:
            raise Exception(f"Git reset failed: {stderr}")
        
        return {
            "message": f"Rolled back to {rollback_hash[:7]}",
            "note": "Restart services to apply: POST /api/system/restart"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def system_health():
    """Get overall system health"""
    import httpx
    from core.database import get_database
    from core.http_client import get_http_client
    
    health = {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "services": {}
    }
    
    # Check MongoDB
    try:
        db = await get_database()
        await db.command("ping")
        health["services"]["mongodb"] = {"status": "up"}
    except Exception as e:
        health["services"]["mongodb"] = {"status": "down", "error": str(e)}
        health["status"] = "degraded"
    
    # Check WhatsApp service
    try:
        http_client = await get_http_client()
        response = await http_client.get("http://localhost:3001/session/health", timeout=3.0)
        wa_health = response.json()
        health["services"]["whatsapp"] = {
            "status": "up" if wa_health.get("connected") else "disconnected",
            "session_status": wa_health.get("status", "unknown")
        }
    except Exception as e:
        health["services"]["whatsapp"] = {"status": "down", "error": str(e)}
        health["status"] = "degraded"
    
    # Check Frontend
    try:
        http_client = await get_http_client()
        response = await http_client.get("http://localhost:3000", timeout=3.0)
        health["services"]["frontend"] = {"status": "up"}
    except Exception as e:
        health["services"]["frontend"] = {"status": "down", "error": str(e)}
    
    return health
