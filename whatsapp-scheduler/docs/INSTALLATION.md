# Installation Guide

## Prerequisites

- **Ubuntu/WSL** (tested on Ubuntu 22.04)
- **Internet connection** for downloading dependencies

## Quick Install

```bash
# Clone the repository
git clone https://github.com/NakshtraYadav/WA-Schedular.git
cd WA-Schedular

# Make scripts executable
chmod +x *.sh

# Run setup (installs everything)
./setup.sh
```

## What Gets Installed

The setup script automatically installs:

| Component | Version | Purpose |
|-----------|---------|---------|
| Node.js | 20.x LTS | Frontend & WhatsApp service |
| Python | 3.x | Backend API |
| Chromium | Latest | WhatsApp automation |
| MongoDB | 7.0 | Database (optional) |

## Manual Installation

If you prefer to install components manually:

### 1. Node.js
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### 2. Python
```bash
sudo apt install -y python3 python3-pip python3-venv
```

### 3. Chromium Dependencies
```bash
sudo apt install -y chromium-browser ca-certificates fonts-liberation \
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdbus-1-3 \
    libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 libxcomposite1 \
    libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 xdg-utils
```

### 4. MongoDB (Optional)
```bash
# Add MongoDB repo
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
    https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt update && sudo apt install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod
```

Or use [MongoDB Atlas](https://www.mongodb.com/atlas) cloud database.

### 5. Install Project Dependencies

```bash
# Backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# WhatsApp Service
cd ../whatsapp-service
npm install

# Frontend
cd ../frontend
npm install --legacy-peer-deps
```

## Configuration

### Backend (`backend/.env`)
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=whatsapp_scheduler
WA_SERVICE_URL=http://localhost:3001
HOST=0.0.0.0
PORT=8001
```

### Frontend (`frontend/.env`)
```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

## Troubleshooting

### Puppeteer/Chromium Issues
```bash
# Install missing dependencies
sudo apt install -y libgbm-dev libxshmfence1 libglu1-mesa

# Or use system Chrome
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

### Port Already in Use
```bash
# Find and kill process on port
lsof -i :3000  # or :8001, :3001
kill -9 <PID>
```

### MongoDB Connection Failed
```bash
# Check if MongoDB is running
sudo systemctl status mongod

# Start MongoDB
sudo systemctl start mongod
```
