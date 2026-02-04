from .checker import check_for_updates
from .version import get_version_info, VERSION_INFO, GITHUB_REPO, GITHUB_BRANCH
from .installer import install_update

__all__ = [
    'check_for_updates',
    'get_version_info', 'VERSION_INFO', 'GITHUB_REPO', 'GITHUB_BRANCH',
    'install_update'
]
