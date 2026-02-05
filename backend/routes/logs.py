"""Message and System Logs routes - Comprehensive logging"""
from fastapi import APIRouter, Query
from fastapi.responses import PlainTextResponse
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from pathlib import Path
from core.database import get_database
from core.scheduler import scheduler
from models.message_log import MessageLog

router = APIRouter(prefix="/logs")

# Log file paths
ROOT_DIR = Path(__file__).parent.parent.parent
LOG_PATHS = {
    "backend": [
        "/var/log/supervisor/backend.err.log",
        "/var/log/supervisor/backend.out.log",
        ROOT_DIR / "logs" / "backend.log"
    ],
    "whatsapp": [
        ROOT_DIR / "logs" / "whatsapp.log",
        ROOT_DIR.parent / "logs" / "whatsapp.log",
        ROOT_DIR.parent / "whatsapp-service" / "logs" / "service.log"
    ],
    "frontend": [
        ROOT_DIR.parent / "logs" / "frontend.log",
        "/var/log/supervisor/frontend.err.log"
    ]
}


def read_log_file(path, lines: int = 100) -> List[str]:
    """Read last N lines from a log file"""
    try:
        path = Path(path)
        if path.exists():
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                all_lines = f.readlines()
                return all_lines[-lines:] if len(all_lines) > lines else all_lines
    except Exception as e:
        return [f"Error reading {path}: {e}"]
    return []


def find_log_file(paths: List) -> Optional[Path]:
    """Find the first existing log file from a list"""
    for p in paths:
        path = Path(p)
        if path.exists():
            return path
    return None


# Message logs (from database)
@router.get("", response_model=List[MessageLog])
async def get_logs(limit: int = 100):
    """Get message logs"""
    database = await get_database()
    logs = await database.logs.find({}, {"_id": 0}).sort("sent_at", -1).to_list(limit)
    for log_entry in logs:
        if isinstance(log_entry.get('sent_at'), str):
            log_entry['sent_at'] = datetime.fromisoformat(log_entry['sent_at'])
    return logs


@router.delete("")
async def clear_logs():
    """Clear all logs"""
    database = await get_database()
    await database.logs.delete_many({})
    return {"success": True}


# System logs endpoints
@router.get("/backend", response_class=PlainTextResponse)
async def get_backend_logs(lines: int = Query(100, ge=10, le=1000)):
    """Get backend/API logs"""
    log_path = find_log_file(LOG_PATHS["backend"])
    if not log_path:
        return "No backend log file found"
    
    log_lines = read_log_file(log_path, lines)
    return f"=== Backend Logs ({log_path}) - Last {lines} lines ===\n\n" + "".join(log_lines)


@router.get("/whatsapp", response_class=PlainTextResponse)
async def get_whatsapp_logs(lines: int = Query(100, ge=10, le=1000)):
    """Get WhatsApp service logs"""
    log_path = find_log_file(LOG_PATHS["whatsapp"])
    if not log_path:
        return "No WhatsApp log file found. Check logs/ folder or start.sh output."
    
    log_lines = read_log_file(log_path, lines)
    return f"=== WhatsApp Service Logs ({log_path}) - Last {lines} lines ===\n\n" + "".join(log_lines)


@router.get("/scheduler")
async def get_scheduler_logs(lines: int = Query(100, ge=10, le=500)):
    """Get scheduler-related logs from backend"""
    log_path = find_log_file(LOG_PATHS["backend"])
    if not log_path:
        return {"error": "No backend log file found", "logs": []}
    
    all_lines = read_log_file(log_path, lines * 5)  # Read more to filter
    
    # Filter for scheduler-related entries
    keywords = ["schedul", "job", "execute", "cron", "trigger", "📅", "🔄", "✅", "❌"]
    filtered = [l.strip() for l in all_lines if any(k.lower() in l.lower() for k in keywords)]
    
    return {
        "source": str(log_path),
        "total_lines": len(filtered),
        "logs": filtered[-lines:] if len(filtered) > lines else filtered
    }


@router.get("/errors")
async def get_error_logs(lines: int = Query(100, ge=10, le=500)):
    """Get only error logs from all sources"""
    errors = []
    
    for source, paths in LOG_PATHS.items():
        log_path = find_log_file(paths)
        if log_path:
            all_lines = read_log_file(log_path, lines * 3)
            # Filter for errors
            source_errors = [
                {"source": source, "line": l.strip(), "level": "error"} 
                for l in all_lines 
                if any(e in l.lower() for e in ["error", "exception", "failed", "critical", "❌"])
            ]
            errors.extend(source_errors[-50:])  # Max 50 per source
    
    return {
        "total": len(errors),
        "errors": errors[-lines:]
    }


@router.get("/all", response_class=PlainTextResponse)
async def get_all_logs(lines: int = Query(50, ge=10, le=200)):
    """Get combined logs from all sources"""
    output = []
    output.append(f"{'='*70}")
    output.append(f"COMBINED SYSTEM LOGS - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    output.append(f"{'='*70}\n")
    
    for source, paths in LOG_PATHS.items():
        log_path = find_log_file(paths)
        output.append(f"\n{'='*50}")
        output.append(f" {source.upper()} LOGS")
        output.append(f"{'='*50}")
        
        if log_path:
            output.append(f"Source: {log_path}\n")
            log_lines = read_log_file(log_path, lines)
            for line in log_lines:
                output.append(line.rstrip())
        else:
            output.append(f"No {source} log file found\n")
    
    return "\n".join(output)


@router.get("/summary")
async def get_log_summary():
    """Get a summary of system health based on logs"""
    database = await get_database()
    
    # Get recent message stats
    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(days=1)
    
    try:
        recent_logs = await database.logs.find(
            {"sent_at": {"$gte": day_ago.isoformat()}},
            {"_id": 0, "status": 1}
        ).to_list(1000)
    except:
        recent_logs = []
    
    sent = len([l for l in recent_logs if l.get("status") == "sent"])
    failed = len([l for l in recent_logs if l.get("status") == "failed"])
    
    # Get scheduler info
    scheduler_jobs = scheduler.get_jobs()
    job_list = [{
        "id": j.id,
        "next_run": j.next_run_time.isoformat() if j.next_run_time else None
    } for j in scheduler_jobs]
    
    # Check for recent errors
    error_count = 0
    for paths in LOG_PATHS.values():
        log_path = find_log_file(paths)
        if log_path:
            lines = read_log_file(log_path, 100)
            error_count += len([l for line in lines if "error" in line.lower()])
    
    return {
        "timestamp": now.isoformat(),
        "messages_24h": {
            "sent": sent,
            "failed": failed,
            "total": sent + failed,
            "success_rate": f"{(sent/(sent+failed)*100):.1f}%" if (sent+failed) > 0 else "N/A"
        },
        "scheduler": {
            "running": scheduler.running,
            "active_jobs": len(job_list),
            "jobs": job_list[:10]  # First 10 jobs
        },
        "errors_in_recent_logs": error_count,
        "log_files": {
            source: str(find_log_file(paths)) if find_log_file(paths) else "Not found"
            for source, paths in LOG_PATHS.items()
        }
    }

