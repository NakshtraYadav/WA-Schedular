# WhatsApp Scheduler - PRD

## Version: 1.0.0 (Build 1)
Release Date: 2026-02-04

## Overview
Local WhatsApp message scheduling application with Telegram remote control, auto-update system, and centralized version management.

## Architecture
- **Frontend**: React 19 + Tailwind CSS + shadcn/ui
- **Backend**: FastAPI + MongoDB
- **WhatsApp**: Puppeteer-based WhatsApp Web automation
- **Updates**: GitHub-based version checking with version.json

## What's Been Implemented

### Core Features (v1.0.0)
- WhatsApp Web integration via QR code
- Contact management (CRUD)
- Message templates
- One-time and recurring schedules (cron-based)
- Telegram bot remote control
- Message history logging
- System diagnostics

### Version System (v1.0.0)
- Centralized `version.json` at project root
- `/api/version` endpoint with full version info + changelog
- `/api/updates/check` compares local vs GitHub version.json
- Semantic versioning (major.minor.patch) + build numbers
- Sidebar version badge with update notification
- Settings page with:
  - Current vs Latest version comparison
  - Build numbers and git SHA
  - Changelog preview for updates
  - Auto-updater daemon controls

## Version.json Schema
```json
{
  "version": "1.0.0",
  "build": 1,
  "name": "WhatsApp Scheduler",
  "release_date": "2026-02-04",
  "changelog": [
    {
      "version": "1.0.0",
      "date": "2026-02-04",
      "changes": ["Feature 1", "Feature 2"]
    }
  ],
  "repository": "user/repo",
  "branch": "main"
}
```

---

## 🚀 FUTURE ROADMAP

### Phase 2: Enhanced Messaging (v1.1.0)
- [ ] **Message personalization** - Variables like {name}, {date} in templates
- [ ] **Media messages** - Send images, documents, voice notes
- [ ] **Bulk messaging** - Send to contact groups
- [ ] **Message status tracking** - Delivered, read receipts
- [ ] **Reply detection** - Log and notify on replies

### Phase 3: AI Integration (v1.2.0)
- [ ] **AI message generation** - GPT-powered template suggestions
- [ ] **Smart scheduling** - AI recommends optimal send times
- [ ] **Sentiment analysis** - Analyze conversation tone
- [ ] **Auto-replies** - AI-powered response suggestions

### Phase 4: Business Features (v2.0.0)
- [ ] **Multi-account support** - Manage multiple WhatsApp numbers
- [ ] **Team collaboration** - User roles and permissions
- [ ] **Analytics dashboard** - Message stats, engagement metrics
- [ ] **API access** - REST API for external integrations
- [ ] **Webhook support** - Trigger actions on message events

### Phase 5: Platform Expansion (v2.5.0)
- [ ] **Desktop app** - Electron wrapper for Windows/Mac/Linux
- [ ] **Mobile companion** - React Native app for on-the-go control
- [ ] **Cloud hosting option** - SaaS version with managed WhatsApp
- [ ] **CRM integrations** - Sync with HubSpot, Salesforce, etc.

### Monetization Ideas
1. **Freemium model**: Free for personal use, paid for business features
2. **Usage-based**: Free tier with message limits
3. **Enterprise**: Self-hosted license with premium support
4. **API access**: Pay-per-use API for developers

### Technical Improvements
- [ ] End-to-end encryption for stored messages
- [ ] Backup/restore functionality
- [ ] Message queuing with retry logic
- [ ] Rate limiting to prevent WhatsApp bans
- [ ] Health monitoring and alerting
- [ ] Docker compose for easy deployment

---

## How to Bump Version

1. Edit `/app/version.json`:
   - Increment `version` (semver)
   - Increment `build` number
   - Update `release_date`
   - Add changelog entry

2. Commit and push to GitHub

3. Users will see update notification on next check

---

## Files Reference
- `/app/version.json` - Centralized version info
- `/app/backend/server.py` - API endpoints
- `/app/frontend/src/App.js` - Version context provider
- `/app/frontend/src/pages/Settings.jsx` - Updates UI
