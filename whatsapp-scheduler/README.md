# WhatsApp Scheduler - Windows Production Guide

A fully automated, self-healing WhatsApp messaging scheduler with Telegram remote control, optimized for Windows 10/11.

## Features

- **Zero Manual Intervention**: Automatic setup, health checks, and recovery
- **Self-Healing**: Watchdog monitors and restarts crashed services
- **Production-Grade Logging**: Timestamped, rotated logs by service
- **Windows Optimized**: PowerShell 5.1 compatible, Task Scheduler integration
- **Bulletproof**: Handles crashes, port conflicts, and partial failures

## Quick Start

### Prerequisites

| Software | Required Version | Download |
|----------|-----------------|----------|
| Node.js | 16+ LTS | [nodejs.org](https://nodejs.org/) |
| Python | 3.8+ | [python.org](https://www.python.org/downloads/) |
| MongoDB | 6.0+ | [mongodb.com](https://www.mongodb.com/try/download/community) |
| Google Chrome | Latest | [google.com/chrome](https://www.google.com/chrome/) |

### One-Command Setup

```batch
setup.bat
```

### One-Command Start

```batch
start.bat
```

### One-Command Stop

```batch
stop.bat
```

## All Available Commands

| Script | Description |
|--------|-------------|
| `setup.bat` | Install all dependencies and configure environment |
| `start.bat` | Start all services with health monitoring |
| `stop.bat` | Gracefully stop all services |
| `restart.bat` | Stop and restart all services |
| `health-check.bat` | Run full system diagnostics |
| `watchdog.bat` | Run self-healing background monitor |

### Advanced Scripts (in `scripts/` folder)

| Script | Description |
|--------|-------------|
| `install-task.bat` | Enable auto-start on Windows login |
| `uninstall-task.bat` | Disable auto-start |
| `rotate-logs.bat` | Clean up old log files |
| `diagnose.bat` | Generate detailed diagnostic report |
| `reset-whatsapp-session.bat` | Clear WhatsApp auth (re-scan QR) |
| `setup.ps1` | PowerShell advanced setup |
| `watchdog.ps1` | PowerShell advanced watchdog |

## Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WhatsApp Scheduler                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Frontend   │    │   Backend   │    │  WhatsApp   │         │
│  │   React     │───▶│   FastAPI   │───▶│   Service   │         │
│  │  :3000      │    │   :8001     │    │   :3001     │         │
│  └─────────────┘    └──────┬──────┘    └─────────────┘         │
│                            │                                    │
│                     ┌──────▼──────┐                            │
│                     │   MongoDB   │                            │
│                     │   :27017    │                            │
│                     └─────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
whatsapp-scheduler/
├── backend/                 # Python FastAPI backend
│   ├── server.py           # Main API server
│   ├── .env                # Backend configuration
│   ├── requirements.txt    # Python dependencies
│   └── venv/               # Python virtual environment
├── frontend/               # React dashboard
│   ├── src/                # Source code
│   ├── .env                # Frontend configuration
│   └── node_modules/       # Node dependencies
├── whatsapp-service/       # WhatsApp Web automation
│   ├── index.js            # WhatsApp service
│   ├── .wwebjs_auth/       # WhatsApp session data
│   └── node_modules/       # Node dependencies
├── logs/                   # Structured logs
│   ├── backend/            # API logs
│   ├── frontend/           # React logs
│   ├── whatsapp/           # WhatsApp service logs
│   └── system/             # Setup/watchdog logs
├── scripts/                # Utility scripts
│   ├── setup.ps1           # PowerShell setup
│   ├── watchdog.ps1        # PowerShell watchdog
│   ├── install-task.bat    # Task Scheduler setup
│   ├── uninstall-task.bat  # Remove scheduled task
│   ├── rotate-logs.bat     # Log cleanup
│   ├── diagnose.bat        # System diagnostics
│   └── reset-whatsapp-session.bat
├── setup.bat               # ONE-COMMAND SETUP
├── start.bat               # ONE-COMMAND START
├── stop.bat                # ONE-COMMAND STOP
├── restart.bat             # Restart all services
├── health-check.bat        # System health check
├── watchdog.bat            # Self-healing monitor
└── README.md               # This file
```

## Configuration

### Backend (.env)

```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
HOST=0.0.0.0
PORT=8001
```

### Frontend (.env)

```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

## Port Reference

| Service | Port | Purpose |
|---------|------|--------|
| Frontend | 3000 | React dashboard |
| Backend | 8001 | FastAPI REST API |
| WhatsApp | 3001 | WhatsApp Web automation |
| MongoDB | 27017 | Database |

## Watchdog Features

The watchdog (`watchdog.bat` or `scripts/watchdog.ps1`) provides:

- **Health Monitoring**: Checks all services every 30 seconds
- **Auto-Restart**: Restarts failed services after 3 consecutive failures
- **Resource Monitoring**: Warns on low memory (<200MB) or high CPU (>95%)
- **Logging**: All events logged to `logs/system/watchdog.log`

## Auto-Start on Boot

To automatically start WhatsApp Scheduler when you log into Windows:

```batch
# Run as Administrator
scripts\install-task.bat
```

To disable auto-start:

```batch
scripts\uninstall-task.bat
```

## Troubleshooting

### Quick Diagnostics

```batch
health-check.bat
```

### Generate Full Report

```batch
scripts\diagnose.bat
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Port in use" | Run `stop.bat`, wait 10 seconds, then `start.bat` |
| "MongoDB not found" | Install MongoDB or configure Atlas in `backend/.env` |
| "Node modules missing" | Run `setup.bat` again |
| "WhatsApp QR not showing" | Check Chrome is installed, run `scripts/reset-whatsapp-session.bat` |
| "Backend crashes" | Check `logs/backend/` for errors, verify MongoDB is running |
| "Frontend won't load" | Wait 1-2 minutes for initial compile, check `logs/frontend/` |

### Manual Service Recovery

If a service crashes and watchdog isn't running:

```batch
# Full restart
restart.bat

# Or start watchdog to auto-recover
watchdog.bat
```

### Reset WhatsApp Session

If you need to re-authenticate WhatsApp:

```batch
scripts\reset-whatsapp-session.bat
```

## Log Management

Logs are automatically organized by service:

```
logs/
├── backend/      # api_YYYYMMDD_HHMMSS.log
├── frontend/     # react_YYYYMMDD_HHMMSS.log
├── whatsapp/     # service_YYYYMMDD_HHMMSS.log
└── system/       # setup/stop/watchdog logs
```

To clean up old logs (keeps last 7 days):

```batch
scripts\rotate-logs.bat
```

## Telegram Bot Setup

1. Open Telegram and search for **@BotFather**
2. Send `/newbot` and follow the prompts
3. Copy the bot token
4. In the dashboard, go to **Settings**
5. Paste your bot token and enable the bot
6. Send `/start` to your bot

### Telegram Commands

| Command | Description |
|---------|-------------|
| `/start` | Initialize bot |
| `/status` | Check WhatsApp connection |
| `/contacts` | List all contacts |
| `/schedules` | List active schedules |
| `/send John Hello!` | Send message to John |
| `/help` | Show help |

## Security Notes

⚠️ **Important:**

- Keep your Telegram bot token private
- Don't share your WhatsApp session folder (`.wwebjs_auth`)
- Use responsibly - WhatsApp may restrict automated accounts
- Add reasonable delays between bulk messages
- This is a local application - don't expose ports to the internet

## Development

### PowerShell Scripts

For advanced users, PowerShell versions are available:

```powershell
# Advanced setup with options
.\scripts\setup.ps1 -Force -Verbose

# Configurable watchdog
.\scripts\watchdog.ps1 -CheckInterval 60 -MaxFailures 5
```

## Support

If you encounter issues:

1. Run `health-check.bat` to identify problems
2. Check logs in the `logs/` folder
3. Run `scripts/diagnose.bat` for a full report
4. Try `restart.bat` for a clean restart
5. Run `setup.bat` to reinstall dependencies

---

**Version 2.0** - Production-Grade Windows Automation
