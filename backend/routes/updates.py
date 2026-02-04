"""Updates routes"""
from fastapi import APIRouter
import os
import subprocess
from core.config import ROOT_DIR
from core.logging import logger
from services.updates import check_for_updates, install_update, get_version_info, GITHUB_REPO, GITHUB_BRANCH

router = APIRouter(prefix="/updates")


@router.get("/check")
async def check_updates():
    """Check GitHub for available updates"""
    return await check_for_updates()


@router.post("/install")
async def do_install_update():
    """Trigger update installation"""
    return await install_update()


@router.get("/auto-updater/status")
async def get_auto_updater_status():
    """Check if auto-updater daemon is running"""
    pid_file = ROOT_DIR.parent / ".auto-updater.pid"
    log_file = ROOT_DIR.parent / "logs" / "system" / "auto-update.log"
    
    is_running = False
    pid = None
    recent_logs = []
    
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            try:
                os.kill(pid, 0)
                is_running = True
            except OSError:
                is_running = False
        except:
            pass
    
    if log_file.exists():
        try:
            with open(log_file, 'r') as f:
                lines = f.readlines()
                recent_logs = [l.strip() for l in lines[-10:]]
        except:
            pass
    
    return {
        "is_running": is_running,
        "pid": pid if is_running else None,
        "recent_logs": recent_logs
    }


@router.post("/auto-updater/{action}")
async def control_auto_updater(action: str):
    """Start or stop the auto-updater daemon"""
    if action not in ["start", "stop", "restart"]:
        return {"success": False, "error": "Invalid action. Use: start, stop, restart"}
    
    script = ROOT_DIR.parent / "auto-updater.sh"
    
    if not script.exists():
        return {"success": False, "error": "auto-updater.sh not found"}
    
    try:
        if action == "start":
            process = subprocess.Popen(
                ["nohup", "bash", str(script), "start"],
                cwd=str(ROOT_DIR.parent),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            return {
                "success": True,
                "output": "Auto-updater starting in background...",
                "pid": process.pid
            }
        else:
            result = subprocess.run(
                ["bash", str(script), action],
                cwd=str(ROOT_DIR.parent),
                capture_output=True,
                text=True,
                timeout=5
            )
            return {
                "success": result.returncode == 0,
                "output": result.stdout.strip() or f"Auto-updater {action}ped",
                "error": result.stderr.strip() if result.returncode != 0 else None
            }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "Command timed out"}
    except Exception as e:
        return {"success": False, "error": str(e)}


@router.get("/debug")
async def debug_updates():
    """Debug endpoint for update checking"""
    import time
    import httpx
    
    cache_buster = int(time.time())
    local_version = get_version_info()
    local_file = ROOT_DIR.parent / "version.json"
    
    result = {
        "local": {
            "version": local_version.get("version"),
            "build": local_version.get("build"),
            "file_exists": local_file.exists(),
            "file_path": str(local_file)
        },
        "remote": {},
        "comparison": {}
    }
    
    try:
        async with httpx.AsyncClient() as http_client:
            url = f"https://raw.githubusercontent.com/{GITHUB_REPO}/{GITHUB_BRANCH}/version.json?t={cache_buster}"
            response = await http_client.get(url, timeout=10.0)
            
            result["remote"]["url"] = url
            result["remote"]["status_code"] = response.status_code
            
            if response.status_code == 200:
                import json
                remote = json.loads(response.text)
                result["remote"]["version"] = remote.get("version")
                result["remote"]["build"] = remote.get("build")
                
                def parse_version(v):
                    try:
                        return tuple(int(p) for p in v.split('.')[:3])
                    except:
                        return (0, 0, 0)
                
                local_tuple = parse_version(local_version.get("version", "0.0.0"))
                remote_tuple = parse_version(remote.get("version", "0.0.0"))
                
                result["comparison"] = {
                    "local_tuple": local_tuple,
                    "remote_tuple": remote_tuple,
                    "remote_greater": remote_tuple > local_tuple,
                    "should_update": remote_tuple > local_tuple or (remote_tuple == local_tuple and remote.get("build", 0) > local_version.get("build", 0))
                }
            else:
                result["remote"]["error"] = response.text[:200]
    except Exception as e:
        result["remote"]["error"] = str(e)
    
    return result
