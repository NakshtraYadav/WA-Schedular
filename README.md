<div align="center">

# 📱 WA Scheduler

**Schedule and automate your WhatsApp messages**

[![Version](https://img.shields.io/badge/Version-2.2.0-brightgreen)](https://github.com/NakshtraYadav/WA-Schedular/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green)](https://nodejs.org/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue)](https://python.org/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL-lightgrey)](https://ubuntu.com/)

[Features](#-features) • [Quick Start](#-quick-start) • [Commands](#-commands) • [Telegram](#-telegram-bot) • [Architecture](#-architecture)

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📅 **Schedule Messages** | One-time or recurring (cron-based) |
| ⚡ **Send Now** | Instant message sending |
| 👥 **Contact Management** | Store and organize contacts |
| 📝 **Message Templates** | Save and reuse templates |
| 🤖 **Telegram Bot** | Control remotely via Telegram |
| 📊 **Dashboard** | Real-time stats and message history |
| 🔄 **One-Click Updates** | Update from UI in ~3 seconds |
| 🔧 **Diagnostics** | Monitor service health |
| ♻️ **Hot Reload** | Code changes apply instantly |
| 💾 **Session Persistence** | WhatsApp stays connected across restarts |

---

## 🚀 Quick Start

### Prerequisites

- **Node.js** 18+ 
- **Python** 3.8+
- **MongoDB** (local or remote)
- **Git**

### Installation (Ubuntu/Debian/WSL)

```bash
# Clone the repository
git clone https://github.com/NakshtraYadav/WA-Schedular.git
cd WA-Schedular

# Full system setup (installs Node, Python, Chromium, MongoDB)
chmod +x *.sh
./setup.sh

# OR quick setup (dependencies only, if system tools already installed)
./start.sh setup

# Start all services
./start.sh
```

### Open in Browser

| Service | URL |
|---------|-----|
| **Dashboard** | http://localhost:3000 |
| **Connect WhatsApp** | http://localhost:3000/connect |
| **Settings** | http://localhost:3000/settings |
| **Diagnostics** | http://localhost:3000/diagnostics |
| **Backend API** | http://localhost:8001/api |

### Connect WhatsApp

1. Open http://localhost:3000/connect
2. Scan the QR code with WhatsApp on your phone
3. You're connected! 🎉
4. Session persists across restarts (no rescan needed)

---

## 📋 Commands

### Main Script: `./start.sh`

This is the **primary control script** for everything:

```bash
./start.sh [command]
```

| Command | Shortcut | Description |
|---------|----------|-------------|
| `./start.sh` | | Start all services |
| `./start.sh setup` | `install` | Install dependencies (first time) |
| `./start.sh stop` | | Stop all services |
| `./start.sh restart` | `r` | Full restart |
| `./start.sh restart-frontend` | `rf` | Restart frontend only |
| `./start.sh restart-backend` | `rb` | Restart backend only |
| `./start.sh update` | `u`, `pull` | Pull latest from GitHub |
| `./start.sh status` | `s` | Check service status |
| `./start.sh logs` | `l` | View all logs |
| `./start.sh logs backend` | `l b` | View backend logs only |
| `./start.sh logs frontend` | `l f` | View frontend logs only |
| `./start.sh logs whatsapp` | `l w` | View WhatsApp logs only |
| `./start.sh diagnose` | `d`, `diag` | Debug startup issues |

### Additional Scripts (Optional)

These scripts provide extra functionality or interactive modes:

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `./setup.sh` | Full system setup | Fresh Ubuntu/WSL install (installs Node, Python, Chromium, MongoDB) |
| `./stop.sh` | Forceful stop | When `./start.sh stop` doesn't fully stop services |
| `./status.sh` | Detailed status | More detailed than `./start.sh status` (includes WhatsApp details) |
| `./logs.sh` | Interactive log viewer | Browse logs with menu selection |
| `./fix-whatsapp.sh` | Reset WhatsApp session | When WhatsApp won't connect (clears session, requires new QR scan) |

### Quick Reference

```bash
# Daily usage
./start.sh              # Start everything
./start.sh stop         # Stop everything
./start.sh status       # Check if running

# Updates
./start.sh update       # Pull latest code from GitHub

# Troubleshooting
./start.sh diagnose     # System diagnostics
./start.sh logs         # View recent logs
./start.sh restart      # Full restart

# First time setup
./setup.sh              # Full system setup (recommended)
# OR
./start.sh setup        # Just install dependencies
```

---

## 🔄 Updates

### From the Web UI (Recommended)

1. Go to **Settings** page
2. See "Update Available" notification
3. Click **Install Update**
4. Page auto-refreshes with new version (~3 seconds)

### From Terminal

```bash
./start.sh update
```

### How It Works

- Uses **hot reload** - no full restart needed
- Backend: ~1 second to apply
- Frontend: ~2-3 seconds to apply
- Dependencies auto-install if changed

---

## 🤖 Telegram Bot

Control your scheduler remotely via Telegram!

### Setup

1. Create a bot with [@BotFather](https://t.me/BotFather)
2. Copy the bot token
3. Go to **Settings** → Paste token → Enable
4. Send `/start` to your bot

### Commands

| Command | Description |
|---------|-------------|
| `/status` | Check WhatsApp connection |
| `/contacts` | List all contacts |
| `/search <name>` | Search contacts |
| `/schedules` | List active schedules |
| `/send <name> <msg>` | Send message now |
| `/create` | Create new schedule (wizard) |
| `/logs` | Recent message history |
| `/help` | Show all commands |

---

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Frontend     │────▶│    Backend      │────▶│    WhatsApp     │
│   React:3000    │     │  FastAPI:8001   │     │  Service:3001   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │    MongoDB      │
                        │     :27017      │
                        └─────────────────┘
```

### Session Persistence (v2.2.0+)

WhatsApp sessions are now stored persistently:
- **Location:** `/app/data/whatsapp-sessions/`
- **Survives:** Server restart, system reboot, days offline
- **No more QR rescans** after initial connection

---

## 📁 Project Structure

```
WA-Schedular/
├── backend/                    # FastAPI Python backend
│   ├── server.py               # Entry point
│   ├── venv/                   # Python virtual environment
│   ├── core/                   # Config, database, scheduler
│   ├── models/                 # Pydantic models
│   ├── routes/                 # API endpoints
│   └── services/               # Business logic
│       ├── whatsapp/           # WhatsApp HTTP client
│       ├── telegram/           # Telegram bot
│       ├── scheduler/          # Job execution
│       └── updates/            # Update system
│
├── frontend/                   # React frontend
│   └── src/
│       ├── api/                # API layer
│       ├── components/         # UI components
│       ├── context/            # React contexts
│       ├── hooks/              # Custom hooks
│       └── pages/              # Page components
│
├── whatsapp-service/           # WhatsApp Web automation
│   └── src/
│       ├── routes/             # API routes
│       └── services/           # WhatsApp client
│
├── data/                       # Persistent data
│   └── whatsapp-sessions/      # WhatsApp session storage
│
├── logs/                       # Service logs
│
├── start.sh                    # Main control script ⭐
├── setup.sh                    # Full system setup
├── stop.sh                     # Force stop services
├── status.sh                   # Detailed status
├── logs.sh                     # Interactive log viewer
├── fix-whatsapp.sh             # Reset WhatsApp session
│
├── version.json                # Version info
└── README.md
```

---

## 🔧 Troubleshooting

### Backend won't start

```bash
./start.sh diagnose     # Check system status
./start.sh logs backend # Check error logs
./start.sh setup        # Reinstall dependencies
```

### WhatsApp won't connect

```bash
./fix-whatsapp.sh       # Clear session and restart (requires new QR scan)
```

### Port already in use

```bash
./stop.sh               # Force stop all services
./start.sh              # Start fresh
```

### Frontend stuck

```bash
./start.sh restart-frontend
```

### Python "externally-managed-environment" error

The script automatically creates a virtual environment. If issues persist:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate
cd ..
./start.sh
```

### Check what's running

```bash
./status.sh             # Detailed service status
# OR
./start.sh status       # Quick status check
```

---

## 🛠️ Development

### Hot Reload

Both backend and frontend have hot reload enabled:
- **Backend**: Edit Python files → Auto-reloads in ~1 second
- **Frontend**: Edit React files → Auto-reloads in ~2-3 seconds

### Adding Features

1. **Backend route**: Add to `backend/routes/`
2. **Backend service**: Add to `backend/services/`
3. **Frontend API**: Add to `frontend/src/api/`
4. **Frontend page**: Add to `frontend/src/pages/`

---

## ⚠️ Disclaimer

This tool uses WhatsApp Web automation via [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js).

**Please use responsibly:**
- Don't send spam or bulk unsolicited messages
- Respect WhatsApp's Terms of Service
- Excessive automation may result in account restrictions

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) - WhatsApp Web API
- [FastAPI](https://fastapi.tiangolo.com/) - Backend framework
- [React](https://reactjs.org/) - Frontend framework
- [shadcn/ui](https://ui.shadcn.com/) - UI components
- [Tailwind CSS](https://tailwindcss.com/) - Styling

---

<div align="center">

**v2.2.0** • Made with ❤️ by [Nakshtra Yadav](https://github.com/NakshtraYadav)

⭐ Star this repo if you find it useful!

</div>
