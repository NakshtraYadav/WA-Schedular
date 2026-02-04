"""Update checking functionality"""
import time
import httpx
from core.config import ROOT_DIR
from core.logging import logger
from .version import get_version_info, GITHUB_REPO, GITHUB_BRANCH


async def check_for_updates() -> dict:
    """Check GitHub for available updates by comparing version.json"""
    try:
        local_version = get_version_info()
        cache_buster = int(time.time())
        
        async with httpx.AsyncClient() as http_client:
            # Try to get version.json from GitHub
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
            
            # Get local git SHA
            git_sha_file = ROOT_DIR.parent / ".version"
            local_sha = "none"
            if git_sha_file.exists():
                local_sha = git_sha_file.read_text().strip()[:7]
            
            # Determine if update is available
            has_update = False
            update_type = None
            
            if remote_version_info:
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
            else:
                has_update = remote_sha != local_sha and local_sha != "none"
                update_type = "unknown"
            
            return {
                "has_update": has_update,
                "update_type": update_type,
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
