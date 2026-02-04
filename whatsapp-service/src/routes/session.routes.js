/**
 * Session routes
 */
const express = require('express');
const router = express.Router();
const { getClient, initWhatsApp, setState } = require('../services/whatsapp/client');
const { clearSession } = require('../services/session/manager');
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
  const client = getClient();
  
  try {
    if (client) {
      try {
        await client.destroy();
      } catch (e) {
        log('WARN', 'Error destroying client:', e.message);
      }
    }

    const result = await clearSession();
    
    if (result.success) {
      setTimeout(() => initWhatsApp(), 1000);
    }

    res.json(result);
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

module.exports = router;
