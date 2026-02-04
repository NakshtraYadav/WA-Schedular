"""Diagnostics routes"""
from fastapi import APIRouter, HTTPException
from datetime import datetime, timezone
import platform
import httpx
from core.database import get_database
from core.config import WA_SERVICE_URL, ROOT_DIR

router = APIRouter(prefix="/diagnostics")


@router.get("")
async def get_diagnostics():
    """Get full system diagnostics"""
    import psutil
    
    diagnostics = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system": {
            "platform": platform.system(),
            "release": platform.release(),
            "python_version": platform.python_version(),
            "cpu_percent": psutil.cpu_percent(),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_percent": psutil.disk_usage('/').percent if platform.system() != 'Windows' else None
        },
        "services": {
            "backend": {"status": "running", "port": 8001},
            "whatsapp": {"status": "unknown", "port": 3001},
            "mongodb": {"status": "unknown", "port": 27017}
        },
        "logs": {}
    }
    
    # Check MongoDB
    try:
        database = await get_database()
        await database.command('ping')
        diagnostics["services"]["mongodb"]["status"] = "running"
    except:
        diagnostics["services"]["mongodb"]["status"] = "error"
    
    # Check WhatsApp
    try:
        async with httpx.AsyncClient() as http_client:
            response = await http_client.get(f"{WA_SERVICE_URL}/status", timeout=3.0)
            if response.status_code == 200:
                wa_status = response.json()
                diagnostics["services"]["whatsapp"]["status"] = "running"
                diagnostics["services"]["whatsapp"]["details"] = wa_status
            else:
                diagnostics["services"]["whatsapp"]["status"] = "error"
    except:
        diagnostics["services"]["whatsapp"]["status"] = "stopped"
    
    return diagnostics


@router.get("/logs/{service}")
async def get_service_logs(service: str, lines: int = 100):
    """Get logs for a specific service"""
    log_base = ROOT_DIR.parent / "logs"
    
    service_map = {
        "backend": "backend",
        "frontend": "frontend", 
        "whatsapp": "whatsapp",
        "system": "system"
    }
    
    if service not in service_map:
        raise HTTPException(status_code=400, detail=f"Invalid service: {service}")
    
    log_dir = log_base / service_map[service]
    
    if not log_dir.exists():
        return {"service": service, "logs": [], "message": "Log directory not found"}
    
    log_files = sorted(log_dir.glob("*.log"), key=lambda x: x.stat().st_mtime, reverse=True)
    
    if not log_files:
        return {"service": service, "logs": [], "message": "No log files found"}
    
    latest_log = log_files[0]
    
    try:
        with open(latest_log, 'r', encoding='utf-8', errors='ignore') as f:
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
        
        return {
            "service": service,
            "file": latest_log.name,
            "total_lines": len(all_lines),
            "logs": [line.strip() for line in recent_lines]
        }
    except Exception as e:
        return {"service": service, "logs": [], "error": str(e)}


@router.get("/logs")
async def get_all_logs_summary():
    """Get summary of all log files"""
    log_base = ROOT_DIR.parent / "logs"
    
    summary = {}
    
    for service in ["backend", "frontend", "whatsapp", "system"]:
        service_dir = log_base / service
        if service_dir.exists():
            log_files = list(service_dir.glob("*.log"))
            total_size = sum(f.stat().st_size for f in log_files)
            summary[service] = {
                "file_count": len(log_files),
                "total_size_mb": round(total_size / (1024 * 1024), 2),
                "latest_file": sorted(log_files, key=lambda x: x.stat().st_mtime, reverse=True)[0].name if log_files else None
            }
        else:
            summary[service] = {"file_count": 0, "total_size_mb": 0, "latest_file": None}
    
    return summary


@router.post("/clear-logs/{service}")
async def clear_service_logs(service: str):
    """Clear logs for a specific service"""
    log_base = ROOT_DIR.parent / "logs"
    
    if service not in ["backend", "frontend", "whatsapp", "system", "all"]:
        raise HTTPException(status_code=400, detail=f"Invalid service: {service}")
    
    cleared = []
    
    if service == "all":
        services = ["backend", "frontend", "whatsapp", "system"]
    else:
        services = [service]
    
    for svc in services:
        svc_dir = log_base / svc
        if svc_dir.exists():
            for log_file in svc_dir.glob("*.log"):
                try:
                    log_file.unlink()
                    cleared.append(str(log_file))
                except:
                    pass
    
    return {"success": True, "cleared": cleared}
