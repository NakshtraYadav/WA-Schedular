<div align="center">

# 📱 WA Scheduler

**Schedule and automate your WhatsApp messages**

[![Version](https://img.shields.io/badge/Version-2.1.2-brightgreen)](https://github.com/NakshtraYadav/WA-Schedular/releases)
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

# Run setup (installs all dependencies)
chmod +x start.sh
./start.sh setup

# Start all services
./start.sh
```

### Open in Browser

| Service | URL |
|---------|-----|
| **Dashboard** | http://localhost:3000 |
| **Connect WhatsApp** | http://localhost:3000/connect |
| **Backend API** | http://localhost:8001/api |

### Connect WhatsApp

1. Open http://localhost:3000/connect
2. Scan the QR code with WhatsApp on your phone
3. You're connected! 🎉

---

## 📋 Commands

All commands use a single script: `./start.sh`

| Command | Description |
|---------|-------------|
| `./start.sh` | Start all services |
| `./start.sh setup` | Install all dependencies (first time) |
| `./start.sh stop` | Stop all services |
| `./start.sh restart` | Full restart |
| `./start.sh update` | Pull latest from GitHub |
| `./start.sh status` | Check service status |
| `./start.sh logs` | View all logs |
| `./start.sh logs backend` | View backend logs |
| `./start.sh logs frontend` | View frontend logs |
| `./start.sh diagnose` | Debug startup issues |
| `./start.sh restart-frontend` | Restart frontend only |
| `./start.sh restart-backend` | Restart backend only |

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

---

## 📁 Project Structure (v2.0+)

The codebase is fully modularized for maintainability:

```
WA-Schedular/
├── backend/                    # FastAPI Python backend
│   ├── server.py               # Entry point (~80 lines)
│   ├── venv/                   # Python virtual environment
│   ├── core/                   # Config, database, scheduler, logging
│   ├── models/                 # Pydantic models
│   ├── routes/                 # API endpoints (13 modules)
│   ├── services/               # Business logic
│   │   ├── whatsapp/           # WhatsApp HTTP client
│   │   ├── telegram/           # Telegram bot + commands
│   │   ├── scheduler/          # Job execution
│   │   ├── contacts/           # Contact CRUD
│   │   ├── templates/          # Template CRUD
│   │   └── updates/            # Update system
│   ├── utils/                  # Helpers
│   └── requirements.txt
│
├── frontend/                   # React frontend
│   ├── src/
│   │   ├── App.js              # Entry point (~45 lines)
│   │   ├── api/                # API layer (11 modules)
│   │   ├── components/
│   │   │   ├── layout/         # Sidebar, Layout
│   │   │   ├── shared/         # Reusable components
│   │   │   └── ui/             # shadcn components
│   │   ├── context/            # React contexts
│   │   ├── hooks/              # Custom hooks
│   │   └── pages/              # Page components
│   └── package.json
│
├── whatsapp-service/           # WhatsApp Web automation
│   ├── index.js                # Entry point
│   └── src/
│       ├── routes/             # API routes
│       ├── services/           # WhatsApp client
│       └── utils/              # Helpers
│
├── logs/                       # Service logs
├── start.sh                    # Single control script
├── version.json                # Version info
└── README.md
```

---

## 🔧 Troubleshooting

### Backend won't start

```bash
# Check logs
./start.sh logs backend

# Run diagnostics
./start.sh diagnose

# Reinstall dependencies
./start.sh setup
```

### Port already in use

```bash
# Kill process on port
sudo kill -9 $(lsof -ti:8001)   # Backend
sudo kill -9 $(lsof -ti:3000)   # Frontend

# Restart
./start.sh restart
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

**v2.1.2** • Made with ❤️ by [Nakshtra Yadav](https://github.com/NakshtraYadav)

⭐ Star this repo if you find it useful!

</div>
