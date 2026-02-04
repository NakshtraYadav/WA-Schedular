# WhatsApp Scheduler - PRD

## Version: 1.1.0 (Build 2)
Release Date: 2026-02-04

## What's New in v1.1.0

### Features Added
- **WhatsApp Contact Sync** - Import contacts directly from WhatsApp
- **Telegram Interactive Schedule Creation** - Create schedules via /create command
- **Custom Time for Recurring Schedules** - Pick any time, not just presets
- **Rollback Support** - `./update.sh rollback` to revert failed updates

### Bug Fixes
- Fixed version comparison (string vs numeric)
- Fixed auto-updater timeout issue
- Added lock file for concurrent update protection
- Telegram setup instructions auto-hide when configured

## Telegram Bot Commands (v1.1.0)

| Command | Description |
|---------|-------------|
| `/help` | Show all commands |
| `/status` | Check WhatsApp connection |
| `/contacts` | List all contacts |
| `/schedules` | List active schedules |
| `/send <name> <message>` | Send message now |
| `/create` | **NEW** Create schedule interactively |
| `/cancel` | Cancel current operation |
| `/logs` | Recent message history |

### Interactive Schedule Creation Flow
1. `/create` → Select contact (1-15)
2. Enter message text
3. Select schedule type (Daily, Weekdays, Weekly, Monthly, Once)
4. Enter time (HH:MM)
5. Confirm with "yes"

## Update System

### How Updates Work
1. Compares local `version.json` with GitHub's `version.json`
2. Uses semantic versioning (major.minor.patch) + build number
3. Falls back to git SHA comparison if no version.json

### Commands
- `./update.sh check` - Check for updates
- `./update.sh install` - Install with confirmation
- `./update.sh force` - Force update + restart
- `./update.sh rollback` - Revert to backup

### Robustness Features
- Lock file prevents concurrent updates
- Auto-backup before update
- Rollback on build failure
- Rate limit handling for GitHub API

## Files Reference
- `/app/version.json` - Version info (bump this to release)
- `/app/backend/server.py` - API + Telegram bot
- `/app/update.sh` - Update script
- `/app/.backup/` - Backup directory

## Next Features (Backlog)
- [ ] Message variables ({name}, {date})
- [ ] Bulk messaging to groups
- [ ] Delivery status tracking
- [ ] AI message suggestions
- [ ] Contact groups/tags
