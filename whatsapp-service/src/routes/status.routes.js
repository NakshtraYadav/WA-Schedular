/**
 * Status routes - Extended with session persistence info
 */
const express = require('express');
const router = express.Router();
const { getState, getClient, validateSessionStorage, checkExistingSession } = require('../services/whatsapp/client');
const { getSessionInfo, cleanupOldBackups } = require('../services/session/manager');
const qrcode = require('qrcode');

// GET /status
router.get('/status', (req, res) => {
  const state = getState();
  
  res.json({
    isReady: state.isReady,
    isAuthenticated: state.isAuthenticated,
    hasQrCode: !!state.qrCodeData,
    isInitializing: state.isInitializing,
    error: state.initError,
    clientInfo: state.clientInfo,
    sessionPath: state.sessionPath
  });
});

// GET /session-info - Detailed session persistence status
router.get('/session-info', (req, res) => {
  const sessionInfo = getSessionInfo();
  const sessionStatus = checkExistingSession();
  const storageValid = validateSessionStorage();
  
  res.json({
    storage: {
      valid: storageValid,
      path: sessionInfo.path
    },
    session: {
      exists: sessionInfo.exists,
      status: sessionStatus,
      created: sessionInfo.created,
      modified: sessionInfo.modified,
      fileCount: sessionInfo.fileCount
    },
    persistence: {
      willSurviveRestart: storageValid && sessionInfo.exists,
      recommendation: !sessionInfo.exists 
        ? 'Scan QR code to create persistent session' 
        : sessionStatus === 'valid' 
          ? 'Session will persist across restarts' 
          : 'Session may be corrupt, consider rescanning'
    }
  });
});

// GET /qr
router.get('/qr', async (req, res) => {
  const state = getState();
  
  if (!state.qrCodeData) {
    return res.json({ qrCode: null, message: 'No QR code available' });
  }

  try {
    const qrDataUrl = await qrcode.toDataURL(state.qrCodeData, { width: 256 });
    res.json({ qrCode: qrDataUrl });
  } catch (error) {
    res.json({ qrCode: null, error: error.message });
  }
});

// GET /test-browser
router.get('/test-browser', async (req, res) => {
  const puppeteer = require('puppeteer');
  const fs = require('fs');
  
  // Find browser
  const possiblePaths = [
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
    '/snap/bin/chromium',
    '/usr/bin/google-chrome'
  ];
  
  let executablePath = null;
  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      executablePath = p;
      break;
    }
  }
  
  try {
    const launchOptions = {
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    };
    
    if (executablePath) {
      launchOptions.executablePath = executablePath;
    }
    
    const browser = await puppeteer.launch(launchOptions);
    const version = await browser.version();
    await browser.close();
    
    res.json({ 
      success: true, 
      message: 'Browser launched successfully',
      browserVersion: version,
      executablePath: executablePath || 'system default'
    });
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

// POST /cleanup-backups
router.post('/cleanup-backups', (req, res) => {
  const result = cleanupOldBackups();
  res.json({ success: true, ...result });
});

module.exports = router;
