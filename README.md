# 📱 WA Scheduler

> **Production-grade WhatsApp message scheduling with Telegram remote control**

Schedule one-time or recurring WhatsApp messages with an elegant web interface. Control everything remotely via Telegram bot. Never forget a birthday or appointment reminder again.

![Version](https://img.shields.io/badge/version-3.2.2-blue)
![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-green)
![Python](https://img.shields.io/badge/python-%3E%3D3.9-yellow)
![License](https://img.shields.io/badge/license-MIT-purple)

---

## ✨ Features

- **📅 Smart Scheduling** - One-time or recurring (cron) message scheduling
- **👥 Contact Management** - Import, organize, and verify WhatsApp contacts
- **📝 Message Templates** - Save and reuse message templates with variables
- **🤖 Telegram Bot** - Full remote control via Telegram commands
- **🔄 Session Persistence** - Never scan QR again after initial setup
- **📊 Dashboard** - Real-time stats and message history
- **🌙 Dark Mode** - Beautiful dark theme UI
- **🔒 Secure** - Local-first, your data stays on your machine

---

## 🚀 Quick Start

### One-Line Install

```bash
git clone https://github.com/YourUsername/WA-Scheduler.git && cd WA-Scheduler && chmod +x setup.sh && ./setup.sh
```

### Start the Application

```bash
./start.sh
```

Then open **http://localhost:3000** in your browser.

---

## 📋 Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| Node.js | 18+ | Installed automatically by setup |
| Python | 3.9+ | Installed automatically by setup |
| MongoDB | 6.0+ | Installed automatically by setup |
| Chrome/Chromium | Latest | Required for WhatsApp Web |
| RAM | 4GB+ | 8GB recommended |

### Supported Platforms

- ✅ Ubuntu 20.04+ / Debian 11+
- ✅ Fedora 36+ / CentOS 8+ / RHEL 8+
- ✅ macOS 12+ (Intel & Apple Silicon)
- ✅ Windows 10/11 (via WSL2)

---

## 🛠️ Installation

### Automatic Setup (Recommended)

The setup script handles everything:

```bash
chmod +x setup.sh
./setup.sh
```

This will:
- ✅ Install Node.js 18 (if missing)
- ✅ Install Python 3.9+ (if missing)
- ✅ Install/Start MongoDB (if missing)
- ✅ Install Chromium (if missing)
- ✅ Create Python virtual environment
- ✅ Install all npm packages
- ✅ Install all pip packages
- ✅ Create .env configuration files

### Manual Setup

<details>
<summary>Click to expand manual setup instructions</summary>

```bash
# 1. Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt-get install -y nodejs

# 2. Install Python 3.9+
sudo apt-get install -y python3 python3-pip python3-venv

# 3. Install MongoDB
# See: https://www.mongodb.com/docs/manual/installation/

# 4. Install Chromium
sudo apt-get install -y chromium-browser

# 5. Setup Backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # Edit with your settings

# 6. Setup Frontend
cd ../frontend
npm install --legacy-peer-deps
cp .env.example .env

# 7. Setup WhatsApp Service
cd ../whatsapp-service
npm install
cp .env.example .env
```

</details>

---

## 🎮 Usage

### Starting Services

```bash
# Start all services
./start.sh

# Start in background
./start.sh &

# View status
./start.sh status

# Stop all services
./stop.sh
```

### First-Time Setup

1. Open **http://localhost:3000**
2. Go to **Connect** page
3. Click the QR placeholder to generate a QR code
4. Scan with WhatsApp on your phone
5. Start scheduling messages!

### Telegram Bot Setup (Optional)

1. Create a bot with [@BotFather](https://t.me/botfather)
2. Get your chat ID from [@userinfobot](https://t.me/userinfobot)
3. Go to **Settings** in the web UI
4. Enter your bot token and chat ID
5. Send `/start` to your bot

**Available Commands:**
- `/status` - Check connection status
- `/send <phone> <message>` - Send message now
- `/schedule` - View scheduled messages
- `/contacts` - List contacts
- `/help` - Show all commands

---

## 🔄 Updates

### Automatic Updates (Web UI)

Updates can be triggered directly from the web interface:

1. Go to **Settings**
2. Click **Check for Updates**
3. Click **Update Now** if available

Or via API:
```bash
curl -X POST http://localhost:8001/api/system/update
```

### Manual Updates

```bash
# Pull latest changes
git pull origin main

# Run zero-touch update
./scripts/zero-touch-update.sh
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend                              │
│                    React (Port 3000)                        │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        Backend                               │
│                  FastAPI (Port 8001)                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Contacts │  │Schedules │  │ Telegram │  │  System  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
┌─────────────────────┐     ┌─────────────────────────────────┐
│      MongoDB        │     │      WhatsApp Service           │
│    (Port 27017)     │     │      Node.js (Port 3001)        │
│                     │     │                                 │
│  • Contacts         │     │  • Session Management           │
│  • Schedules        │     │  • Message Sending              │
│  • Message Logs     │     │  • QR Code Generation           │
│  • Sessions         │     │  • Connection Monitoring        │
└─────────────────────┘     └─────────────────────────────────┘
```

---

## 📁 Project Structure

```
WA-Scheduler/
├── backend/                 # Python FastAPI backend
│   ├── core/               # Core modules (config, database, scheduler)
│   ├── routes/             # API endpoints
│   ├── services/           # Business logic
│   ├── models/             # Pydantic models
│   └── requirements.txt    # Python dependencies
├── frontend/               # React frontend
│   ├── src/
│   │   ├── pages/         # Page components
│   │   ├── components/    # Reusable components
│   │   └── api/           # API client
│   └── package.json
├── whatsapp-service/       # Node.js WhatsApp service
│   ├── src/
│   │   ├── services/      # WhatsApp client, session management
│   │   └── routes/        # HTTP endpoints
│   └── package.json
├── docs/                   # Documentation
├── scripts/                # Utility scripts
├── setup.sh               # One-click installer
├── start.sh               # Start all services
├── stop.sh                # Stop all services
└── ecosystem.config.js    # PM2 configuration
```

---

## ⚙️ Configuration

### Environment Variables

**Backend** (`backend/.env`):
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
```

**Frontend** (`frontend/.env`):
```env
REACT_APP_BACKEND_URL=http://localhost:8001
PORT=3000
```

**WhatsApp Service** (`whatsapp-service/.env`):
```env
PORT=3001
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
```

---

## 🔧 Troubleshooting

### WhatsApp Won't Connect

1. **Close all Chrome windows** and try again
2. Run the fix script: `./scripts/fix-whatsapp.bat` (Windows) or `./scripts/fix-whatsapp.sh` (Linux)
3. Check if Chromium is installed: `which chromium-browser`
4. Clear session and rescan: Settings → Clear Session

### MongoDB Connection Error

```bash
# Check if MongoDB is running
sudo systemctl status mongod

# Start MongoDB
sudo systemctl start mongod

# Or use Docker
docker run -d -p 27017:27017 --name mongodb mongo:7
```

### Port Already in Use

```bash
# Find process using port
lsof -i :3000  # Frontend
lsof -i :3001  # WhatsApp
lsof -i :8001  # Backend

# Kill process
kill -9 <PID>
```

### Session Lost After Restart

This shouldn't happen with v3.0+. If it does:
1. Check MongoDB is running
2. Check `whatsapp-service/.env` has correct MONGO_URL
3. View logs: `tail -f logs/whatsapp-*.log`

---

## 📊 API Reference

### System Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/system/health` | Full system status |
| POST | `/api/system/update` | Trigger update |
| POST | `/api/system/restart` | Graceful restart |
| GET | `/api/system/update-status` | Update progress |

### WhatsApp Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/whatsapp/status` | Connection status |
| GET | `/api/whatsapp/qr` | Get QR code |
| POST | `/api/whatsapp/logout` | Logout session |
| GET | `/api/whatsapp/session/health` | Session health |
| GET | `/api/whatsapp/session/observe` | Full observability |

### Scheduling Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/schedules` | List schedules |
| POST | `/api/schedules` | Create schedule |
| DELETE | `/api/schedules/{id}` | Delete schedule |
| POST | `/api/send-now` | Send immediately |

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) - WhatsApp Web API
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [React](https://reactjs.org/) - Frontend framework
- [Tailwind CSS](https://tailwindcss.com/) - Styling
- [shadcn/ui](https://ui.shadcn.com/) - UI components

---

<p align="center">
  Made with ❤️ for automating WhatsApp messaging
</p>
