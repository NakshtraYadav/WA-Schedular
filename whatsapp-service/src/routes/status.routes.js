/**
 * Status routes
 */
const express = require('express');
const router = express.Router();
const { getState, getClient } = require('../services/whatsapp/client');
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
    clientInfo: state.clientInfo
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
  
  try {
    const browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
      executablePath: '/usr/bin/chromium'
    });
    await browser.close();
    res.json({ success: true, message: 'Browser launched successfully' });
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

module.exports = router;
