"""Update checking functionality"""
import time
import subprocess
import httpx
from core.config import ROOT_DIR
from core.logging import logger
from .version import get_version_info, GITHUB_REPO, GITHUB_BRANCH


def get_local_git_sha() -> str:
    """Get local git commit SHA"""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(ROOT_DIR.parent),
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()[:7]
    except:
        pass
    return "unknown"


def check_git_behind() -> tuple:
    """Check if local is behind remote using git"""
    try:
        # Fetch latest from remote (without merging)
        subprocess.run(
            ["git", "fetch", "origin", GITHUB_BRANCH, "--quiet"],
            cwd=str(ROOT_DIR.parent),
            capture_output=True,
            timeout=15
        )
        
        # Check how many commits behind
        result = subprocess.run(
            ["git", "rev-list", "--count", f"HEAD..origin/{GITHUB_BRANCH}"],
            cwd=str(ROOT_DIR.parent),
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            commits_behind = int(result.stdout.strip())
            return commits_behind > 0, commits_behind
    except Exception as e:
        logger.warning(f"Git check failed: {e}")
    
    return False, 0


async def check_for_updates() -> dict:
    """Check GitHub for available updates by comparing version.json AND git status"""
    try:
        local_version = get_version_info()
        local_sha = get_local_git_sha()
        cache_buster = int(time.time())
        
        # Method 1: Check git status (most reliable)
        git_has_update, commits_behind = check_git_behind()
        
        async with httpx.AsyncClient() as http_client:
            # Method 2: Check version.json from GitHub
            version_url = f"https://raw.githubusercontent.com/{GITHUB_REPO}/{GITHUB_BRANCH}/version.json?t={cache_buster}"
            logger.info(f"Checking for updates from: {version_url}")
            
            version_response = await http_client.get(version_url, timeout=10.0)
            
            remote_version_info = None
            if version_response.status_code == 200:
                try:
                    import json
                    remote_version_info = json.loads(version_response.text)
                    logger.info(f"Remote version: {remote_version_info.get('version')}, Local version: {local_version.get('version')}")
                except Exception as e:
                    logger.warning(f"Failed to parse remote version.json: {e}")
            else:
                logger.warning(f"Failed to fetch version.json: HTTP {version_response.status_code}")
            
            # Get latest commit info
            commit_response = await http_client.get(
                f"https://api.github.com/repos/{GITHUB_REPO}/commits/{GITHUB_BRANCH}",
                timeout=10.0
            )
            
            remote_sha = "unknown"
            remote_message = ""
            remote_date = ""
            
            if commit_response.status_code == 200:
                commit_data = commit_response.json()
                remote_sha = commit_data.get("sha", "")[:7]
                remote_message = commit_data.get("commit", {}).get("message", "").split("\n")[0]
                remote_date = commit_data.get("commit", {}).get("committer", {}).get("date", "")
            
            # Determine if update is available
            has_update = False
            update_type = None
            
            # Check 1: Git says we're behind
            if git_has_update:
                has_update = True
                update_type = "commits"
                logger.info(f"Git: {commits_behind} commits behind")
            
            # Check 2: Version comparison
            if remote_version_info and not has_update:
                def parse_version(v):
                    try:
                        parts = v.split('.')
                        return tuple(int(p) for p in parts[:3])
                    except:
                        return (0, 0, 0)
                
                local_ver = local_version.get("version", "0.0.0")
                remote_ver = remote_version_info.get("version", "0.0.0")
                local_build = local_version.get("build", 0)
                remote_build = remote_version_info.get("build", 0)
                
                local_tuple = parse_version(local_ver)
                remote_tuple = parse_version(remote_ver)
                
                if remote_tuple > local_tuple:
                    has_update = True
                    if remote_tuple[0] > local_tuple[0]:
                        update_type = "major"
                    elif remote_tuple[1] > local_tuple[1]:
                        update_type = "minor"
                    else:
                        update_type = "patch"
                elif remote_tuple == local_tuple and remote_build > local_build:
                    has_update = True
                    update_type = "patch"
            
            # Check 3: SHA comparison as fallback
            if not has_update and local_sha != "unknown" and remote_sha != "unknown":
                if local_sha != remote_sha:
                    has_update = True
                    update_type = "unknown"
            
            return {
                "has_update": has_update,
                "update_type": update_type,
                "commits_behind": commits_behind if git_has_update else 0,
                "local": {
                    "version": local_version.get("version", "1.0.0"),
                    "build": local_version.get("build", 1),
                    "sha": local_sha
                },
                "remote": {
                    "version": remote_version_info.get("version") if remote_version_info else remote_sha,
                    "build": remote_version_info.get("build") if remote_version_info else None,
                    "sha": remote_sha,
                    "release_date": remote_version_info.get("release_date") if remote_version_info else remote_date,
                    "changelog": remote_version_info.get("changelog", [])[:1] if remote_version_info else []
                },
                "commit_message": remote_message,
                "repo": GITHUB_REPO
            }
    except Exception as e:
        logger.error(f"Update check failed: {e}")
        return {"error": str(e)}
