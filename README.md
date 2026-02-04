<div align="center">

# 📱 WA Scheduler

**Schedule and automate your WhatsApp messages**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green)](https://nodejs.org/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue)](https://python.org/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL-lightgrey)](https://ubuntu.com/)

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Documentation](#documentation)

</div>

---

## ✨ Features

- 📅 **Schedule Messages** - One-time or recurring (cron-based)
- ⚡ **Send Now** - Instant message sending
- 👥 **Contact Management** - Store and organize contacts
- 📝 **Message Templates** - Save and reuse templates
- 🤖 **Telegram Bot** - Control remotely via Telegram
- 📊 **Dashboard** - Real-time stats and message history
- 🔄 **Auto-Updates** - Stay updated automatically
- 🔧 **Diagnostics** - Monitor service health

## 🖥️ Screenshots

| Dashboard | Scheduler | Settings |
|-----------|-----------|----------|
| Real-time stats | Create schedules | Telegram & updates |

## 🚀 Installation

### Quick Start (Ubuntu/WSL)

```bash
# Clone the repository
git clone https://github.com/NakshtraYadav/WA-Schedular.git
cd WA-Schedular

# Run setup
chmod +x *.sh
./setup.sh

# Start all services
./start.sh
```

### Open in Browser

- **Dashboard:** http://localhost:3000
- **Connect WhatsApp:** http://localhost:3000/connect

📖 See [Installation Guide](docs/INSTALLATION.md) for detailed instructions.

## 📋 Usage

### Available Scripts

| Script | Description |
|--------|-------------|
| `./setup.sh` | Install all dependencies |
| `./start.sh` | Start all services |
| `./start.sh -a` | Start with auto-updater |
| `./stop.sh` | Stop all services |
| `./status.sh` | Check service status |
| `./update.sh` | Check and install updates |

### Connect WhatsApp

1. Start the services: `./start.sh`
2. Open http://localhost:3000/connect
3. Scan the QR code with your WhatsApp mobile app
4. You're connected! 🎉

### Schedule a Message

1. Go to **Contacts** → Add a contact
2. Go to **Scheduler** → Click "New Schedule"
3. Select contact, enter message, choose time
4. Done! The message will be sent automatically.

## 🤖 Telegram Bot

Control your scheduler remotely via Telegram!

```
/status    - Check WhatsApp connection
/contacts  - List all contacts
/schedules - List active schedules
/send John Hello!  - Send message now
```

📖 See [Telegram Setup Guide](docs/TELEGRAM.md)

## 🔄 Auto-Updates

WA Scheduler can automatically update itself from GitHub.

```bash
# Enable auto-updates (checks every 30 min)
./start.sh --auto-update

# Or manually check
./update.sh check

# Install update
./update.sh install
```

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

## 📁 Project Structure

```
WA-Schedular/
├── backend/              # FastAPI Python backend
│   ├── server.py         # Main API server
│   └── requirements.txt  # Python dependencies
├── frontend/             # React frontend
│   ├── src/
│   │   ├── pages/        # Page components
│   │   ├── components/   # UI components
│   │   └── lib/          # API client
│   └── package.json
├── whatsapp-service/     # WhatsApp automation
│   ├── index.js          # WhatsApp Web client
│   └── package.json
├── docs/                 # Documentation
├── logs/                 # Service logs
└── *.sh                  # Shell scripts
```

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [Telegram Bot Setup](docs/TELEGRAM.md)
- [API Reference](docs/API.md)

## ⚠️ Disclaimer

This tool uses WhatsApp Web automation via [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js).

**Please use responsibly:**
- Don't send spam or bulk unsolicited messages
- Respect WhatsApp's Terms of Service
- Excessive automation may result in account restrictions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) - WhatsApp Web API
- [FastAPI](https://fastapi.tiangolo.com/) - Backend framework
- [React](https://reactjs.org/) - Frontend framework
- [shadcn/ui](https://ui.shadcn.com/) - UI components

---

<div align="center">

Made with ❤️ by [Nakshtra Yadav](https://github.com/NakshtraYadav)

</div>
