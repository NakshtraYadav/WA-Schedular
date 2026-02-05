/**
 * Express application setup
 */
const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./middleware/errorHandler');
const routes = require('./routes');
const { log } = require('./utils/logger');
const { initWhatsApp } = require('./services/whatsapp/client');
const { initSessionStore, hasExistingSession } = require('./services/session/mongoStore');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/', routes);

// Error handler
app.use(errorHandler);

/**
 * Auto-initialize WhatsApp if there's a valid existing session
 * This restores the connection after service restart without requiring new QR scan
 */
const autoInitIfSessionExists = async () => {
  try {
    log('INFO', 'Checking for existing WhatsApp session...');
    
    // Try to connect to MongoDB first
    let hasSession = false;
    try {
      await initSessionStore();
      hasSession = await hasExistingSession('wa-scheduler');
      log('INFO', `MongoDB session check: ${hasSession ? 'Session found' : 'No session'}`);
    } catch (mongoError) {
      log('INFO', 'MongoDB not available, checking filesystem session...');
      // Check filesystem session
      const fs = require('fs');
      const path = require('path');
      const { SESSION_PATH } = require('./config/env');
      const sessionDir = path.join(SESSION_PATH, 'session-wa-scheduler');
      hasSession = fs.existsSync(sessionDir) && fs.existsSync(path.join(sessionDir, 'Default'));
      log('INFO', `Filesystem session check: ${hasSession ? 'Session found' : 'No session'}`);
    }
    
    if (hasSession) {
      log('INFO', '✓ Found existing session - auto-initializing WhatsApp...');
      // Delay slightly to let the server fully start
      setTimeout(() => {
        initWhatsApp();
      }, 2000);
    } else {
      log('INFO', 'No existing session found - waiting for user to request QR code');
    }
  } catch (error) {
    log('WARN', `Auto-init check failed: ${error.message}`);
    log('INFO', 'WhatsApp service ready - QR will be generated on demand');
  }
};

// Check for existing session after a brief delay (let MongoDB connect first)
setTimeout(autoInitIfSessionExists, 1000);

module.exports = app;
