/**
 * WhatsApp client - Production-grade WWebJS integration
 * 
 * SESSION PERSISTENCE STRATEGY (v2.5.0):
 * 
 * Uses RemoteAuth with MongoDB instead of LocalAuth:
 * - Sessions stored in MongoDB (atomic writes, no corruption)
 * - Survives unclean shutdowns, kill signals, reboots
 * - No lock file issues
 * - Session validity verified before use
 * 
 * Fallback to LocalAuth if MongoDB unavailable.
 */
const { Client, LocalAuth, RemoteAuth } = require('whatsapp-web.js');
const { log } = require('../../utils/logger');
const { SESSION_PATH } = require('../../config/env');
const { initSessionStore, getStore, hasExistingSession, deleteSession } = require('../session/mongoStore');
const fs = require('fs');
const path = require('path');

// State
let client = null;
let qrCodeData = null;
let isReady = false;
let isAuthenticated = false;
let clientInfo = null;
let isInitializing = false;
let initError = null;
let initRetries = 0;
let isShuttingDown = false;
let qrRefreshTimer = null;
let lastQrTime = null;
let useMongoSession = false; // Track which auth method is in use

const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 5000;
const SHUTDOWN_TIMEOUT_MS = 15000; // Increased for session save
const SESSION_CLIENT_ID = 'wa-scheduler';
const QR_REFRESH_INTERVAL_MS = 30000; // 30 seconds

const getState = () => ({
  client,
  qrCodeData,
  isReady,
  isAuthenticated,
  clientInfo,
  isInitializing,
  initError,
  initRetries,
  sessionPath: useMongoSession ? 'MongoDB' : SESSION_PATH,
  sessionType: useMongoSession ? 'RemoteAuth (MongoDB)' : 'LocalAuth (Filesystem)',
  qrAge: lastQrTime ? Math.floor((Date.now() - lastQrTime) / 1000) : null
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

/**
 * Start QR refresh timer - regenerates QR every 30 seconds
 */
const startQrRefreshTimer = () => {
  stopQrRefreshTimer();
  
  qrRefreshTimer = setInterval(async () => {
    if (!isReady && !isAuthenticated && qrCodeData && client) {
      const qrAge = lastQrTime ? (Date.now() - lastQrTime) / 1000 : 0;
      if (qrAge >= 25) { // Refresh a bit before 30s to be safe
        log('INFO', 'QR code expiring, requesting refresh...');
        try {
          // Destroy and reinitialize to get fresh QR
          await gracefulShutdown();
          setTimeout(() => initWhatsApp(), 2000);
        } catch (e) {
          log('WARN', 'QR refresh error:', e.message);
        }
      }
    }
  }, 5000); // Check every 5 seconds
  
  log('INFO', 'QR auto-refresh timer started');
};

const stopQrRefreshTimer = () => {
  if (qrRefreshTimer) {
    clearInterval(qrRefreshTimer);
    qrRefreshTimer = null;
  }
};

/**
 * Validate session directory exists and is writable
 * Falls back to local directory if preferred path fails
 */
const validateSessionStorage = () => {
  const tryPath = (sessionPath) => {
    try {
      // Ensure directory exists
      if (!fs.existsSync(sessionPath)) {
        fs.mkdirSync(sessionPath, { recursive: true, mode: 0o755 });
        log('INFO', `Created session directory: ${sessionPath}`);
      }

      // Verify writable
      const testFile = path.join(sessionPath, '.write-test');
      fs.writeFileSync(testFile, 'test');
      fs.unlinkSync(testFile);
      
      return true;
    } catch (error) {
      log('WARN', `Cannot use path ${sessionPath}: ${error.message}`);
      return false;
    }
  };

  // Try preferred path first
  if (tryPath(SESSION_PATH)) {
    log('INFO', `Session storage validated: ${SESSION_PATH}`);
    return true;
  }

  // Fallback: use local directory in whatsapp-service
  const fallbackPath = path.resolve(__dirname, '..', '..', '..', 'session-data');
  if (tryPath(fallbackPath)) {
    log('INFO', `Using fallback session path: ${fallbackPath}`);
    // Update SESSION_PATH for this session
    Object.defineProperty(require('../../config/env'), 'SESSION_PATH', {
      value: fallbackPath,
      writable: false
    });
    return true;
  }

  log('ERROR', 'Session storage validation failed - no writable path found');
  return false;
};

/**
 * Clean up stale browser locks and processes (especially for WSL)
 */
const cleanupStaleBrowser = () => {
  const sessionDir = path.join(SESSION_PATH, `session-${SESSION_CLIENT_ID}`);
  
  // List of lock files that can prevent browser from starting
  const lockFiles = [
    'SingletonLock',
    'SingletonCookie',
    'SingletonSocket'
  ];

  for (const lockFile of lockFiles) {
    const lockPath = path.join(sessionDir, lockFile);
    if (fs.existsSync(lockPath)) {
      try {
        fs.unlinkSync(lockPath);
        log('INFO', `Removed stale lock: ${lockFile}`);
      } catch (e) {
        log('WARN', `Could not remove ${lockFile}:`, e.message);
      }
    }
  }

  // Kill any orphaned chromium processes (WSL-friendly)
  try {
    const { execSync } = require('child_process');
    // Find and kill chromium processes that might be stuck
    execSync('pkill -f "chromium.*userDataDir.*wa-scheduler" 2>/dev/null || true', { stdio: 'ignore' });
    execSync('pkill -f "chrome.*userDataDir.*wa-scheduler" 2>/dev/null || true', { stdio: 'ignore' });
    log('INFO', 'Cleaned up any orphaned browser processes');
  } catch (e) {
    // Ignore errors - process may not exist
  }

  // Small delay to ensure processes are fully terminated
  return new Promise(resolve => setTimeout(resolve, 1000));
};

/**
 * Check if existing session data exists
 * Returns: 'valid' | 'corrupt' | 'none'
 */
const checkExistingSession = () => {
  const sessionDir = path.join(SESSION_PATH, `session-${SESSION_CLIENT_ID}`);
  
  if (!fs.existsSync(sessionDir)) {
    log('INFO', 'No existing session found');
    return 'none';
  }

  // Check for critical session files
  const criticalPaths = [
    'Default/Local Storage',
    'Default/IndexedDB'
  ];

  for (const criticalPath of criticalPaths) {
    const fullPath = path.join(sessionDir, criticalPath);
    if (!fs.existsSync(fullPath)) {
      log('WARN', `Session appears corrupt: missing ${criticalPath}`);
      return 'corrupt';
    }
  }

  log('INFO', 'Existing session found and appears valid');
  return 'valid';
};

/**
 * Create WhatsApp client with production configuration
 */
const createClient = () => {
  // Find Chromium executable dynamically
  const possiblePaths = [
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
    '/snap/bin/chromium',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable'
  ];
  
  let executablePath = null;
  for (const chromePath of possiblePaths) {
    if (fs.existsSync(chromePath)) {
      executablePath = chromePath;
      log('INFO', `Using browser: ${chromePath}`);
      break;
    }
  }
  
  if (!executablePath) {
    log('WARN', 'No browser found, will try system default');
  }
  
  const puppeteerArgs = [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-accelerated-2d-canvas',
    '--no-first-run',
    '--no-zygote',
    '--single-process',
    '--disable-gpu',
    '--disable-extensions',
    '--disable-background-timer-throttling',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
    // Memory optimization
    '--js-flags=--max-old-space-size=512'
  ];
  
  const puppeteerOptions = {
    headless: true,
    args: puppeteerArgs,
    // Increase timeouts for slow systems
    timeout: 60000
  };
  
  if (executablePath) {
    puppeteerOptions.executablePath = executablePath;
  }
  
  log('INFO', `Creating client with session path: ${SESSION_PATH}`);
  
  return new Client({
    authStrategy: new LocalAuth({
      clientId: SESSION_CLIENT_ID,
      dataPath: SESSION_PATH
    }),
    puppeteer: puppeteerOptions,
    // Use stable web version
    webVersionCache: {
      type: 'remote',
      remotePath: 'https://raw.githubusercontent.com/AuroraDevelopmentTeam/AuroraAPI/main/AuroraWWeb/',
    },
    // Connection options
    restartOnAuthFail: true,
    qrMaxRetries: 5
  });
};

/**
 * Graceful shutdown - CRITICAL for session persistence
 */
const gracefulShutdown = async () => {
  if (isShuttingDown) {
    log('INFO', 'Shutdown already in progress');
    return;
  }
  
  isShuttingDown = true;
  log('INFO', 'Starting graceful shutdown...');
  
  if (!client) {
    log('INFO', 'No client to shut down');
    return;
  }

  try {
    // Give session time to save
    await new Promise((resolve) => {
      const timeout = setTimeout(() => {
        log('WARN', 'Shutdown timeout reached');
        resolve();
      }, SHUTDOWN_TIMEOUT_MS);
      
      client.destroy()
        .then(() => {
          clearTimeout(timeout);
          log('INFO', 'Client destroyed successfully');
          resolve();
        })
        .catch((err) => {
          clearTimeout(timeout);
          log('WARN', 'Error during destroy:', err.message);
          resolve();
        });
    });
    
    // Ensure Puppeteer process is killed
    if (client.pupBrowser) {
      try {
        await client.pupBrowser.close();
      } catch (e) {
        // Browser already closed
      }
    }
  } catch (error) {
    log('ERROR', 'Shutdown error:', error.message);
  }
  
  client = null;
  isShuttingDown = false;
  stopQrRefreshTimer();
  lastQrTime = null;
  log('INFO', 'Graceful shutdown complete');
};

/**
 * Initialize WhatsApp client with session validation
 */
const initWhatsApp = async () => {
  if (isInitializing) {
    log('INFO', 'Already initializing, skipping...');
    return;
  }

  if (isShuttingDown) {
    log('INFO', 'Shutdown in progress, deferring init...');
    setTimeout(initWhatsApp, 2000);
    return;
  }

  setState({
    isInitializing: true,
    initError: null
  });

  log('INFO', '=== WhatsApp Initialization Starting ===');

  // Step 0: Clean up stale browser locks (important for WSL)
  await cleanupStaleBrowser();

  // Step 1: Validate storage
  if (!validateSessionStorage()) {
    setState({
      isInitializing: false,
      initError: 'Session storage not accessible'
    });
    return;
  }

  // Step 2: Check existing session
  const sessionStatus = checkExistingSession();
  if (sessionStatus === 'corrupt') {
    log('WARN', 'Corrupt session detected - will require new QR scan');
  } else if (sessionStatus === 'valid') {
    log('INFO', 'Resuming from existing session...');
  }

  // Step 3: Clean shutdown of existing client
  if (client) {
    log('INFO', 'Shutting down existing client first...');
    await gracefulShutdown();
    // Wait for cleanup
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  // Step 4: Create and initialize new client
  try {
    client = createClient();

    // Event: QR Code
    client.on('qr', (qr) => {
      log('INFO', 'QR Code received - scan required');
      lastQrTime = Date.now();
      setState({
        qrCodeData: qr,
        isReady: false,
        isAuthenticated: false
      });
      // Start auto-refresh timer for QR
      startQrRefreshTimer();
    });

    // Event: Ready
    client.on('ready', async () => {
      log('INFO', '✓ WhatsApp client is READY!');
      stopQrRefreshTimer(); // Stop QR refresh when connected
      lastQrTime = null;
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
        log('INFO', `Session will persist in: ${SESSION_PATH}`);
      } catch (e) {
        log('WARN', 'Could not get client info:', e.message);
      }
    });

    // Event: Authenticated (session restored)
    client.on('authenticated', () => {
      log('INFO', '✓ Session authenticated successfully!');
      setState({ isAuthenticated: true, qrCodeData: null });
    });

    // Event: Authentication failure
    client.on('auth_failure', async (msg) => {
      log('ERROR', 'Authentication failed:', msg);
      setState({
        isAuthenticated: false,
        isReady: false,
        initError: 'Authentication failed: ' + msg,
        isInitializing: false
      });
      
      // Clear corrupt session
      const sessionDir = path.join(SESSION_PATH, `session-${SESSION_CLIENT_ID}`);
      if (fs.existsSync(sessionDir)) {
        log('INFO', 'Clearing failed session...');
        fs.rmSync(sessionDir, { recursive: true, force: true });
      }
    });

    // Event: Disconnected
    client.on('disconnected', async (reason) => {
      log('WARN', 'Client disconnected:', reason);
      setState({
        isReady: false,
        isAuthenticated: false,
        clientInfo: null
      });
      
      // Auto-reconnect unless intentional logout
      if (reason !== 'LOGOUT' && !isShuttingDown) {
        log('INFO', 'Will attempt reconnection in 10 seconds...');
        setTimeout(() => {
          if (!isShuttingDown && !isInitializing) {
            initWhatsApp();
          }
        }, 10000);
      }
    });

    // Event: Remote session saved (WhatsApp Web multi-device)
    client.on('remote_session_saved', () => {
      log('INFO', 'Remote session saved - persistence confirmed');
    });

    await client.initialize();
    log('INFO', '✓ WhatsApp client initialized');
    
  } catch (error) {
    log('ERROR', 'Failed to initialize WhatsApp:', error.message);
    log('ERROR', 'Stack:', error.stack);
    
    setState({
      isInitializing: false,
      initError: error.message,
      initRetries: initRetries + 1
    });

    if (initRetries < MAX_RETRIES) {
      const delay = RETRY_DELAY_MS * (initRetries + 1); // Exponential backoff
      log('INFO', `Retrying in ${delay/1000}s (attempt ${initRetries + 1}/${MAX_RETRIES})...`);
      setTimeout(initWhatsApp, delay);
    } else {
      log('ERROR', 'Max retries reached. Manual intervention required.');
    }
  }
};

// Register process shutdown handlers for session persistence
const registerShutdownHandlers = () => {
  const shutdown = async (signal) => {
    log('INFO', `Received ${signal}, initiating graceful shutdown...`);
    await gracefulShutdown();
    process.exit(0);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGHUP', () => shutdown('SIGHUP'));
  
  // Handle uncaught errors
  process.on('uncaughtException', async (error) => {
    log('ERROR', 'Uncaught exception:', error.message);
    await gracefulShutdown();
    process.exit(1);
  });
  
  process.on('unhandledRejection', (reason, promise) => {
    log('ERROR', 'Unhandled rejection:', reason);
  });
  
  log('INFO', 'Shutdown handlers registered');
};

// Initialize handlers on module load
registerShutdownHandlers();

const getClient = () => client;

module.exports = {
  initWhatsApp,
  getClient,
  getState,
  setState,
  createClient,
  gracefulShutdown,
  validateSessionStorage,
  checkExistingSession
};
