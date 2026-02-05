/**
 * Status routes - Extended with session persistence info
 */
const express = require('express');
const router = express.Router();
const { getState, getClient, validateSessionStorage, checkExistingSession, useMongoSession } = require('../services/whatsapp/client');
const { getSessionInfo: getLocalSessionInfo, cleanupOldBackups } = require('../services/session/manager');
const { getSessionInfo: getMongoSessionInfo, isConnected: isMongoConnected } = require('../services/session/mongoStore');
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
    sessionPath: state.sessionPath,
    sessionType: state.sessionType
  });
});

// GET /session-info - Detailed session persistence status
router.get('/session-info', async (req, res) => {
  const state = getState();
  const usingMongo = useMongoSession();
  
  let sessionInfo;
  let sessionStatus;
  
  if (usingMongo) {
    // Get MongoDB session info
    try {
      sessionInfo = await getMongoSessionInfo('wa-scheduler');
      sessionStatus = sessionInfo.exists ? 'valid' : 'none';
    } catch (e) {
      sessionInfo = { exists: false, error: e.message };
      sessionStatus = 'error';
    }
  } else {
    // Get filesystem session info
    sessionInfo = getLocalSessionInfo();
    sessionStatus = checkExistingSession();
  }
  
  res.json({
    storage: {
      type: usingMongo ? 'MongoDB (RemoteAuth)' : 'Filesystem (LocalAuth)',
      mongoConnected: isMongoConnected(),
      valid: usingMongo ? isMongoConnected() : validateSessionStorage()
    },
    session: {
      exists: sessionInfo.exists,
      status: sessionStatus,
      entries: sessionInfo.entries || sessionInfo.fileCount || 0
    },
    persistence: {
      willSurviveRestart: usingMongo ? isMongoConnected() : (validateSessionStorage() && sessionInfo.exists),
      recommendation: !sessionInfo.exists 
        ? 'Scan QR code to create persistent session' 
        : sessionStatus === 'valid' 
          ? `Session stored in ${usingMongo ? 'MongoDB' : 'filesystem'} - will persist` 
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
