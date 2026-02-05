/**
 * Session routes - Production-grade session management
 */
const express = require('express');
const router = express.Router();
const { getClient, initWhatsApp, setState, gracefulShutdown, useMongoSession } = require('../services/whatsapp/client');
const { clearSession: clearLocalSession, backupSession } = require('../services/session/manager');
const { deleteSession: deleteMongoSession } = require('../services/session/mongoStore');
const { log } = require('../utils/logger');

// POST /logout
router.post('/logout', async (req, res) => {
  const client = getClient();
  
  try {
    if (client) {
      await client.logout();
    }
    setState({
      isReady: false,
      isAuthenticated: false,
      clientInfo: null,
      qrCodeData: null
    });
    res.json({ success: true, message: 'Logged out successfully' });
  } catch (error) {
    log('ERROR', 'Logout error:', error.message);
    res.json({ success: false, error: error.message });
  }
});

// POST /retry-init
router.post('/retry-init', async (req, res) => {
  log('INFO', 'Retry initialization requested');
  initWhatsApp();
  res.json({ success: true, message: 'Reinitialization started' });
});

// POST /clear-session
router.post('/clear-session', async (req, res) => {
  try {
    // Graceful shutdown first
    log('INFO', 'Clear session requested - initiating graceful shutdown');
    await gracefulShutdown();
    
    // Wait for cleanup
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Clear session based on storage type
    let result;
    if (useMongoSession()) {
      log('INFO', 'Clearing MongoDB session...');
      result = await deleteMongoSession('wa-scheduler');
    } else {
      log('INFO', 'Clearing filesystem session...');
      result = await clearLocalSession(true);
    }
    
    if (result.success) {
      // Reinitialize after delay
      setTimeout(() => initWhatsApp(), 1000);
    }

    res.json(result);
  } catch (error) {
    log('ERROR', 'Clear session error:', error.message);
    res.json({ success: false, error: error.message });
  }
});

// POST /backup-session
router.post('/backup-session', async (req, res) => {
  try {
    if (useMongoSession()) {
      res.json({ success: true, message: 'MongoDB sessions are automatically backed up' });
    } else {
      const result = await backupSession();
      res.json(result);
    }
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

module.exports = router;
