# WhatsApp Scheduler - Windows Setup Guide

A local WhatsApp messaging scheduler with Telegram remote control.

## Prerequisites

Before running the setup, install these:

### 1. Node.js (Required)
- Download: https://nodejs.org/
- Install the **LTS version** (e.g., 20.x.x)
- During installation, check "Add to PATH"

### 2. Python 3.10+ (Required)
- Download: https://www.python.org/downloads/
- **IMPORTANT**: Check "Add Python to PATH" during installation

### 3. MongoDB (Required - choose one option)

**Option A: Local Installation (Recommended for offline use)**
- Download: https://www.mongodb.com/try/download/community
- Install MongoDB Community Server
- During installation, select "Install MongoDB as a Service"

**Option B: MongoDB Atlas (Cloud - easier setup)**
- Sign up: https://www.mongodb.com/cloud/atlas
- Create a free cluster
- Get your connection string
- Update `backend\.env` with your connection string

### 4. Google Chrome (Required for WhatsApp)
- Download: https://www.google.com/chrome/
- WhatsApp Web automation requires Chrome

## Quick Start

### Step 1: Run Setup
```batch
setup.bat
```
This installs all dependencies and creates config files.

### Step 2: Start the Application
```batch
start.bat
```
This starts all services and opens the dashboard.

### Step 3: Connect WhatsApp
1. Open http://localhost:3000/connect
2. Scan the QR code with your phone
3. Done! You can now schedule messages.

## File Structure

```
whatsapp-scheduler/
├── backend/              # Python FastAPI backend
│   ├── server.py         # Main API server
│   ├── .env              # Backend config
│   └── venv/             # Python virtual environment
├── frontend/             # React dashboard
│   ├── src/              # Source code
│   └── .env              # Frontend config
├── whatsapp-service/     # Node.js WhatsApp service
│   └── index.js          # WhatsApp Web automation
├── logs/                 # Service logs
├── setup.bat             # Setup script
├── start.bat             # Start all services
├── stop.bat              # Stop all services
└── README.md             # This file
```

## Configuration

### Backend (.env)
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
```

### Frontend (.env)
```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

## Telegram Bot Setup

1. Open Telegram and search for **@BotFather**
2. Send `/newbot` and follow the prompts
3. Copy the bot token (looks like: `123456789:ABC...XYZ`)
4. In the dashboard, go to **Settings**
5. Paste your bot token and enable the bot
6. Send `/start` to your bot to initialize

### Telegram Commands
- `/start` - Initialize bot
- `/status` - Check WhatsApp connection
- `/contacts` - List all contacts
- `/schedules` - List active schedules
- `/send John Hello!` - Send message to John
- `/help` - Show help

## Ports Used

| Service | Port | URL |
|---------|------|-----|
| Frontend | 3000 | http://localhost:3000 |
| Backend API | 8001 | http://localhost:8001/api |
| WhatsApp Service | 3001 | http://localhost:3001 |
| MongoDB | 27017 | mongodb://localhost:27017 |

## Troubleshooting

### "MongoDB not found"
- Make sure MongoDB is installed and running
- Or use MongoDB Atlas cloud service

### "WhatsApp QR not appearing"
- Check if Chrome is installed
- Look at `logs/whatsapp.log` for errors
- Try restarting the WhatsApp service

### "Cannot connect to backend"
- Check `logs/backend.log` for errors
- Make sure MongoDB is running
- Verify MONGO_URL in `backend/.env`

### "Telegram bot not responding"
- Verify your bot token is correct
- Make sure "Enable Telegram Bot" is ON in Settings
- Send `/start` to your bot first
- Check backend logs for Telegram errors

### Firewall Issues
- Allow Node.js through Windows Firewall
- Allow Python through Windows Firewall

## Stopping the Application

**Option 1:** Press any key in the start.bat window

**Option 2:** Run `stop.bat`

**Option 3:** Close all terminal windows

## Data Storage

All data is stored in MongoDB:
- **contacts** - Your contact list
- **templates** - Message templates
- **schedules** - Scheduled messages
- **logs** - Message history
- **settings** - App settings (Telegram config)

WhatsApp session is stored in:
- `whatsapp-service/.wwebjs_auth/`

## Security Notes

⚠️ **Important:**
- Keep your Telegram bot token private
- Don't share your WhatsApp session folder
- Use responsibly - WhatsApp may restrict automated accounts
- Add reasonable delays between bulk messages

## Support

If you encounter issues:
1. Check the logs in the `logs/` folder
2. Restart all services with `stop.bat` then `start.bat`
3. Delete `whatsapp-service/.wwebjs_auth/` to reset WhatsApp session
