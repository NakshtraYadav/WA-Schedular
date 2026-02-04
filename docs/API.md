# API Reference

Base URL: `http://localhost:8001/api`

## WhatsApp

### Get Status
```http
GET /whatsapp/status
```

Response:
```json
{
  "isReady": true,
  "isAuthenticated": true,
  "hasQrCode": false,
  "clientInfo": {
    "pushname": "John",
    "phone": "1234567890"
  }
}
```

### Get QR Code
```http
GET /whatsapp/qr
```

Response:
```json
{
  "qrCode": "data:image/png;base64,..."
}
```

### Logout
```http
POST /whatsapp/logout
```

---

## Contacts

### List Contacts
```http
GET /contacts
```

### Create Contact
```http
POST /contacts
Content-Type: application/json

{
  "name": "John Doe",
  "phone": "+1234567890"
}
```

### Update Contact
```http
PUT /contacts/{id}
Content-Type: application/json

{
  "name": "John Smith",
  "phone": "+1234567890"
}
```

### Delete Contact
```http
DELETE /contacts/{id}
```

---

## Templates

### List Templates
```http
GET /templates
```

### Create Template
```http
POST /templates
Content-Type: application/json

{
  "title": "Meeting Reminder",
  "content": "Hi! Just a reminder about our meeting tomorrow at {time}."
}
```

### Update Template
```http
PUT /templates/{id}
```

### Delete Template
```http
DELETE /templates/{id}
```

---

## Schedules

### List Schedules
```http
GET /schedules
```

### Create Schedule (One-time)
```http
POST /schedules
Content-Type: application/json

{
  "contact_id": "abc123",
  "message": "Hello!",
  "schedule_type": "once",
  "scheduled_time": "2024-12-25T09:00:00Z"
}
```

### Create Schedule (Recurring)
```http
POST /schedules
Content-Type: application/json

{
  "contact_id": "abc123",
  "message": "Good morning!",
  "schedule_type": "recurring",
  "cron_expression": "0 9 * * *",
  "cron_description": "Daily at 9 AM"
}
```

### Toggle Schedule
```http
PUT /schedules/{id}/toggle
```

### Delete Schedule
```http
DELETE /schedules/{id}
```

---

## Send Message Now

```http
POST /send-now?contact_id={id}&message={text}
```

---

## Message Logs

### Get Logs
```http
GET /logs?limit=100
```

### Clear Logs
```http
DELETE /logs
```

---

## Settings

### Get Settings
```http
GET /settings
```

### Update Settings
```http
PUT /settings
Content-Type: application/json

{
  "telegram_token": "123:ABC...",
  "telegram_chat_id": "123456789",
  "telegram_enabled": true,
  "timezone": "America/New_York"
}
```

---

## Updates

### Check for Updates
```http
GET /updates/check
```

Response:
```json
{
  "has_update": true,
  "local_version": "abc1234",
  "remote_version": "def5678",
  "remote_message": "Added new feature",
  "repo": "NakshtraYadav/WA-Schedular"
}
```

### Install Update
```http
POST /updates/install
```

### Auto-Updater Status
```http
GET /updates/auto-updater/status
```

### Control Auto-Updater
```http
POST /updates/auto-updater/start
POST /updates/auto-updater/stop
```

---

## Diagnostics

### System Diagnostics
```http
GET /diagnostics
```

### Service Logs
```http
GET /diagnostics/logs/{service}?lines=100
```
Services: `backend`, `frontend`, `whatsapp`, `system`

### Clear Logs
```http
POST /diagnostics/clear-logs/{service}
```

---

## Health Check

```http
GET /health
```

Response:
```json
{
  "status": "healthy",
  "database": "connected"
}
```
