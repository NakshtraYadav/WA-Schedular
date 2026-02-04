/**
 * WhatsApp client - Core WWebJS integration
 */
const { Client, LocalAuth } = require('whatsapp-web.js');
const { log } = require('../../utils/logger');
const { SESSION_PATH } = require('../../config/env');

// State
let client = null;
let qrCodeData = null;
let isReady = false;
let isAuthenticated = false;
let clientInfo = null;
let isInitializing = false;
let initError = null;
let initRetries = 0;
const MAX_RETRIES = 3;

const getState = () => ({
  client,
  qrCodeData,
  isReady,
  isAuthenticated,
  clientInfo,
  isInitializing,
  initError,
  initRetries
});

const setState = (updates) => {
  if (updates.qrCodeData !== undefined) qrCodeData = updates.qrCodeData;
  if (updates.isReady !== undefined) isReady = updates.isReady;
  if (updates.isAuthenticated !== undefined) isAuthenticated = updates.isAuthenticated;
  if (updates.clientInfo !== undefined) clientInfo = updates.clientInfo;
  if (updates.isInitializing !== undefined) isInitializing = updates.isInitializing;
  if (updates.initError !== undefined) initError = updates.initError;
  if (updates.initRetries !== undefined) initRetries = updates.initRetries;
};

const createClient = () => {
  return new Client({
    authStrategy: new LocalAuth({ dataPath: SESSION_PATH }),
    puppeteer: {
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--single-process',
        '--disable-gpu'
      ],
      executablePath: '/usr/bin/chromium'
    },
    webVersionCache: {
      type: 'remote',
      remotePath: 'https://raw.githubusercontent.com/AuroraDevelopmentTeam/AuroraAPI/main/AuroraWWeb/',
    }
  });
};

const initWhatsApp = async () => {
  if (isInitializing) {
    log('INFO', 'Already initializing, skipping...');
    return;
  }

  setState({
    isInitializing: true,
    initError: null
  });

  log('INFO', 'Initializing WhatsApp client...');

  try {
    if (client) {
      try {
        await client.destroy();
      } catch (e) {
        log('WARN', 'Error destroying old client:', e.message);
      }
    }

    client = createClient();

    // Event: QR Code
    client.on('qr', (qr) => {
      log('INFO', 'QR Code received');
      setState({
        qrCodeData: qr,
        isReady: false,
        isAuthenticated: false
      });
    });

    // Event: Ready
    client.on('ready', async () => {
      log('INFO', 'WhatsApp client is ready!');
      setState({
        isReady: true,
        isAuthenticated: true,
        qrCodeData: null,
        initRetries: 0,
        isInitializing: false
      });

      try {
        const info = client.info;
        setState({
          clientInfo: {
            pushname: info.pushname,
            phone: info.wid.user,
            platform: info.platform
          }
        });
        log('INFO', `Connected as ${info.pushname} (${info.wid.user})`);
      } catch (e) {
        log('WARN', 'Could not get client info:', e.message);
      }
    });

    // Event: Authenticated
    client.on('authenticated', () => {
      log('INFO', 'WhatsApp authenticated');
      setState({ isAuthenticated: true, qrCodeData: null });
    });

    // Event: Authentication failure
    client.on('auth_failure', (msg) => {
      log('ERROR', 'Authentication failed:', msg);
      setState({
        isAuthenticated: false,
        isReady: false,
        initError: 'Authentication failed: ' + msg,
        isInitializing: false
      });
    });

    // Event: Disconnected
    client.on('disconnected', (reason) => {
      log('WARN', 'Client disconnected:', reason);
      setState({
        isReady: false,
        isAuthenticated: false,
        clientInfo: null
      });
    });

    await client.initialize();
    log('INFO', 'WhatsApp client initialized successfully');
  } catch (error) {
    log('ERROR', 'Failed to initialize WhatsApp:', error.message);
    setState({
      isInitializing: false,
      initError: error.message,
      initRetries: initRetries + 1
    });

    if (initRetries < MAX_RETRIES) {
      log('INFO', `Retrying in 5 seconds (attempt ${initRetries + 1}/${MAX_RETRIES})...`);
      setTimeout(initWhatsApp, 5000);
    }
  }
};

const getClient = () => client;

module.exports = {
  initWhatsApp,
  getClient,
  getState,
  setState,
  createClient
};
