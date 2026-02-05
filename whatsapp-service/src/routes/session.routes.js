/**
 * Session routes - Production-grade session management
 */
const express = require('express');
const router = express.Router();
const { getClient, initWhatsApp, setState, gracefulShutdown } = require('../services/whatsapp/client');
const { clearSession, backupSession } = require('../services/session/manager');
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
    
    // Clear session with backup
    const result = await clearSession(true);
    
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
    const result = await backupSession();
    res.json(result);
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

module.exports = router;
