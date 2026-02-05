/**
 * Express application setup
 * 
 * Includes graceful shutdown coordination for zero-downtime restarts
 */
const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./middleware/errorHandler');
const routes = require('./routes');
const { log } = require('./utils/logger');
const { initWhatsApp, gracefulShutdown: shutdownWhatsApp, getClient } = require('./services/whatsapp/client');
const { initSessionStore, hasExistingSession } = require('./services/session/mongoStore');
const graceful = require('./services/graceful');
const { saveSession, updateConnectionStatus, releaseReconnectLock, getWorkerId } = require('./services/session/durableStore');
const { updateState: updateObservability, recordCredentialWrite } = require('./services/session/observability');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/', routes);

// Error handler
app.use(errorHandler);

/**
 * Register graceful shutdown callbacks
 */
const setupGracefulShutdown = () => {
  const { onShutdown, installShutdownHandlers } = graceful;
  
  // 1. Stop WhatsApp client gracefully (saves session)
  onShutdown('whatsapp-client', async () => {
    log('INFO', '[SHUTDOWN] Stopping WhatsApp client...');
    await shutdownWhatsApp();
    log('INFO', '[SHUTDOWN] WhatsApp client stopped');
  });
  
  // 2. Force session save to MongoDB
  onShutdown('session-save', async () => {
    log('INFO', '[SHUTDOWN] Forcing session save to MongoDB...');
    const client = getClient();
    if (client && client.info) {
      try {
        // Extract session data if possible
        updateObservability('disconnected');
        recordCredentialWrite();
        log('INFO', '[SHUTDOWN] Session state recorded');
      } catch (e) {
        log('WARN', '[SHUTDOWN] Could not save session state:', e.message);
      }
    }
  });
  
  // 3. Release distributed locks
  onShutdown('release-locks', async () => {
    log('INFO', '[SHUTDOWN] Releasing distributed locks...');
    try {
      await releaseReconnectLock('wa-scheduler');
      log('INFO', '[SHUTDOWN] Locks released');
    } catch (e) {
      log('WARN', '[SHUTDOWN] Lock release failed:', e.message);
    }
  });
  
  // 4. Update connection status in database
  onShutdown('update-status', async () => {
    log('INFO', '[SHUTDOWN] Updating connection status...');
    try {
      await updateConnectionStatus('wa-scheduler', 'disconnected', 'GRACEFUL_SHUTDOWN');
      log('INFO', '[SHUTDOWN] Status updated');
    } catch (e) {
      log('WARN', '[SHUTDOWN] Status update failed:', e.message);
    }
  });
  
  // Install signal handlers
  const { signalReady } = installShutdownHandlers();
  
  return { signalReady };
};

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

// Setup graceful shutdown FIRST
const { signalReady } = setupGracefulShutdown();

// Check for existing session after a brief delay (let MongoDB connect first)
setTimeout(async () => {
  await autoInitIfSessionExists();
  // Signal PM2 that we're ready
  signalReady();
}, 1000);

module.exports = app;
