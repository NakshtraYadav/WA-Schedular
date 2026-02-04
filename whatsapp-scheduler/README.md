# WA Scheduler

A self-hosted WhatsApp message scheduler with Telegram bot integration. Schedule one-time or recurring messages, manage contacts, and control everything via Telegram.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-green.svg)
![Python](https://img.shields.io/badge/python-%3E%3D3.8-blue.svg)

## Features

- 📅 **Schedule Messages** - One-time or recurring (cron-based)
- 📱 **Send Now** - Instant message sending
- 👥 **Contact Management** - Store and organize contacts
- 📝 **Message Templates** - Save and reuse message templates
- 🤖 **Telegram Bot** - Control scheduler remotely via Telegram
- 📊 **Dashboard** - Real-time statistics and message history
- 🔧 **Diagnostics** - Monitor service health and view logs

## Architecture

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

## Quick Start (Ubuntu/WSL)

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/wa-scheduler.git
cd wa-scheduler
```

### 2. Run setup (installs everything)
```bash
chmod +x *.sh
./setup.sh
```

This installs:
- Node.js 20.x
- Python 3 + pip + venv
- Chromium browser + puppeteer dependencies
- MongoDB (optional - can use Atlas)
- All project dependencies

### 3. Start all services
```bash
./start.sh
```

### 4. Open in browser
- **Dashboard:** http://localhost:3000
- **Connect WhatsApp:** http://localhost:3000/connect
- **Diagnostics:** http://localhost:3000/diagnostics

### 5. Scan QR code
Open the Connect page and scan the QR code with your WhatsApp mobile app.

## Available Scripts

| Script | Description |
|--------|-------------|
| `./setup.sh` | Full installation from scratch |
| `./start.sh` | Start all services |
| `./start.sh -a` | Start with auto-updater enabled |
| `./stop.sh` | Stop all services |
| `./status.sh` | Check service status |
| `./logs.sh` | View service logs |
| `./update.sh` | Check and install updates |
| `./auto-updater.sh` | Control auto-update daemon |
| `./fix-whatsapp.sh` | Clear WhatsApp session and restart |

## Auto-Updates

WA Scheduler can automatically check for updates from GitHub every 30 minutes.

### Enable Auto-Updates

**Option 1:** Start with auto-updater
```bash
./start.sh --auto-update
```

**Option 2:** Start auto-updater separately
```bash
./auto-updater.sh start
```

### Manual Update
```bash
# Check for updates
./update.sh check

# Install update
./update.sh install

# Force update and restart
./update.sh force
```

### Control Auto-Updater
```bash
./auto-updater.sh start    # Start daemon
./auto-updater.sh stop     # Stop daemon
./auto-updater.sh status   # Check status
```

You can also control updates from the **Settings** page in the web dashboard.

## Telegram Bot Setup

1. Create a bot via [@BotFather](https://t.me/BotFather)
2. Copy the bot token
3. Go to Settings in the web dashboard
4. Paste the token and enable Telegram
5. Send `/start` to your bot

### Available Commands
- `/start` - Initialize bot and save chat ID
- `/status` - Check WhatsApp connection
- `/contacts` - List all contacts
- `/schedules` - List active schedules
- `/logs` - Recent message history
- `/send <name> <message>` - Send message immediately

## Configuration

### Environment Variables

**Backend** (`backend/.env`):
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
```

**Frontend** (`frontend/.env`):
```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

## API Endpoints

### WhatsApp
- `GET /api/whatsapp/status` - Connection status
- `GET /api/whatsapp/qr` - Get QR code
- `POST /api/whatsapp/logout` - Logout

### Contacts
- `GET /api/contacts` - List all
- `POST /api/contacts` - Create
- `PUT /api/contacts/:id` - Update
- `DELETE /api/contacts/:id` - Delete

### Schedules
- `GET /api/schedules` - List all
- `POST /api/schedules` - Create
- `PUT /api/schedules/:id/toggle` - Toggle active
- `DELETE /api/schedules/:id` - Delete

### Messages
- `POST /api/send-now` - Send immediately
- `GET /api/logs` - Message history

## Tech Stack

- **Frontend:** React, Tailwind CSS, shadcn/ui
- **Backend:** Python, FastAPI, APScheduler
- **WhatsApp:** whatsapp-web.js, Puppeteer
- **Database:** MongoDB
- **Bot:** Telegram Bot API

## Disclaimer

This tool uses WhatsApp Web automation via [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js). Use responsibly:

- Don't send spam or bulk unsolicited messages
- Respect WhatsApp's Terms of Service
- Excessive automation may result in account restrictions

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
