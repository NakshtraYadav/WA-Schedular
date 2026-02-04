const express = require('express');
const cors = require('cors');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

// State
let qrCodeDataUrl = null;
let isReady = false;
let isAuthenticated = false;
let clientInfo = null;
let initError = null;
let client = null;
let isInitializing = false;
let initAttempts = 0;
const MAX_INIT_ATTEMPTS = 3;

// Verbose logging
const log = (level, ...args) => {
    const timestamp = new Date().toISOString().substr(11, 8);
    console.log(`[${timestamp}] [${level}]`, ...args);
};

log('INFO', '================================================');
log('INFO', '  WhatsApp Web Service v2.2 (Debug Mode)');
log('INFO', '================================================');
log('INFO', '');
log('INFO', 'Platform:', process.platform);
log('INFO', 'Node:', process.version);
log('INFO', 'CWD:', process.cwd());
log('INFO', '');

// Paths
const SESSION_PATH = path.join(__dirname, '.wwebjs_auth');
const CACHE_PATH = path.join(__dirname, '.wwebjs_cache');

// Clear session
function clearSession() {
    log('INFO', 'Clearing session data...');
    try {
        if (fs.existsSync(SESSION_PATH)) {
            fs.rmSync(SESSION_PATH, { recursive: true, force: true });
            log('INFO', 'Cleared:', SESSION_PATH);
        }
        if (fs.existsSync(CACHE_PATH)) {
            fs.rmSync(CACHE_PATH, { recursive: true, force: true });
            log('INFO', 'Cleared:', CACHE_PATH);
        }
        return true;
    } catch (err) {
        log('ERROR', 'Clear failed:', err.message);
        return false;
    }
}

// Find Chrome
function findChrome() {
    log('INFO', 'Searching for Chrome/Edge...');
    
    const paths = [
        process.env.CHROME_PATH,
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        path.join(process.env.LOCALAPPDATA || '', 'Google\\Chrome\\Application\\chrome.exe'),
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
        // Linux/Mac
        '/usr/bin/google-chrome',
        '/usr/bin/chromium-browser',
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    ].filter(Boolean);

    for (const p of paths) {
        if (fs.existsSync(p)) {
            log('INFO', 'Found browser:', p);
            return p;
        }
    }
    
    log('WARN', 'No system browser found, using bundled Chromium');
    return null;
}

// Create client
function createClient() {
    log('INFO', 'Creating WhatsApp client...');
    
    const chromePath = findChrome();
    
    const puppeteerConfig = {
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu',
            '--disable-extensions',
            '--disable-software-rasterizer',
            '--disable-features=site-per-process',
            '--disable-web-security',
            '--disable-features=IsolateOrigins',
            '--disable-site-isolation-trials',
            '--ignore-certificate-errors',
            '--disable-blink-features=AutomationControlled',
            '--window-size=1280,800',
            '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ],
        defaultViewport: { width: 1280, height: 800 },
        ignoreHTTPSErrors: true,
        timeout: 60000,
    };

    if (chromePath) {
        puppeteerConfig.executablePath = chromePath;
        log('INFO', 'Using system browser');
    } else {
        log('INFO', 'Using bundled Chromium');
    }

    const clientConfig = {
        authStrategy: new LocalAuth({
            dataPath: SESSION_PATH
        }),
        puppeteer: puppeteerConfig,
        qrMaxRetries: 5,
        takeoverOnConflict: true,
        takeoverTimeoutMs: 10000,
    };

    log('INFO', 'Client config ready');
    return new Client(clientConfig);
}

function setupClientEvents(clientInstance) {
    log('INFO', 'Setting up event handlers...');

    clientInstance.on('qr', async (qr) => {
        log('INFO', '');
        log('INFO', '================================================');
        log('INFO', '  QR CODE RECEIVED!');
        log('INFO', '================================================');
        log('INFO', '');
        log('INFO', 'Open http://localhost:3000/connect to scan');
        log('INFO', '');
        
        try {
            qrCodeDataUrl = await qrcode.toDataURL(qr);
            isAuthenticated = false;
            isReady = false;
            initError = null;
            isInitializing = false;
        } catch (err) {
            log('ERROR', 'QR generation failed:', err.message);
        }
    });

    clientInstance.on('loading_screen', (percent, message) => {
        log('INFO', `Loading: ${percent}% - ${message}`);
    });

    clientInstance.on('ready', () => {
        log('INFO', '');
        log('INFO', '================================================');
        log('INFO', '  WHATSAPP CONNECTED!');
        log('INFO', '================================================');
        
        isReady = true;
        isAuthenticated = true;
        isInitializing = false;
        initAttempts = 0;
        qrCodeDataUrl = null;
        initError = null;
        clientInfo = clientInstance.info;
        
        if (clientInfo) {
            log('INFO', 'Logged in as:', clientInfo.pushname);
            log('INFO', 'Phone:', clientInfo.wid?.user);
        }
        log('INFO', '');
    });

    clientInstance.on('authenticated', () => {
        log('INFO', 'Authenticated successfully');
        isAuthenticated = true;
        initError = null;
    });

    clientInstance.on('auth_failure', async (msg) => {
        log('ERROR', 'Auth failed:', msg);
        isAuthenticated = false;
        isReady = false;
        isInitializing = false;
        initError = 'Authentication failed: ' + msg;
        clearSession();
        
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            log('INFO', 'Retrying in 5s...');
            setTimeout(() => initializeClient(), 5000);
        }
    });

    clientInstance.on('disconnected', async (reason) => {
        log('WARN', 'Disconnected:', reason);
        isReady = false;
        isAuthenticated = false;
        qrCodeDataUrl = null;
        clientInfo = null;
        
        if (['NAVIGATION', 'LOGOUT', 'CONFLICT'].includes(reason)) {
            log('INFO', 'Auto-reconnecting in 10s...');
            setTimeout(() => initializeClient(), 10000);
        }
    });

    clientInstance.on('change_state', (state) => {
        log('INFO', 'State changed:', state);
    });

    clientInstance.on('message', (msg) => {
        if (!msg.isStatus) {
            log('MSG', `From ${msg.from}: ${msg.body?.substring(0, 30) || '(media)'}...`);
        }
    });

    log('INFO', 'Event handlers ready');
}

async function initializeClient() {
    if (isInitializing) {
        log('WARN', 'Already initializing, skipping');
        return;
    }
    
    isInitializing = true;
    initAttempts++;
    initError = null;
    
    log('INFO', '');
    log('INFO', `=== Initialization Attempt ${initAttempts}/${MAX_INIT_ATTEMPTS} ===`);
    log('INFO', '');
    
    try {
        // Destroy old client
        if (client) {
            log('INFO', 'Destroying old client...');
            try { 
                await client.destroy(); 
            } catch (e) {
                log('WARN', 'Destroy error (ignored):', e.message);
            }
            client = null;
            await new Promise(r => setTimeout(r, 2000));
        }
        
        // Create new client
        client = createClient();
        setupClientEvents(client);
        
        log('INFO', 'Starting initialization...');
        log('INFO', 'This may take 30-90 seconds...');
        log('INFO', '');
        
        // Initialize with timeout
        const initPromise = client.initialize();
        const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout after 120 seconds')), 120000)
        );
        
        await Promise.race([initPromise, timeoutPromise]);
        
        log('INFO', 'Initialization completed successfully');
        
    } catch (err) {
        log('ERROR', '');
        log('ERROR', '================================================');
        log('ERROR', '  INITIALIZATION FAILED');
        log('ERROR', '================================================');
        log('ERROR', 'Error:', err.message);
        log('ERROR', 'Stack:', err.stack?.split('\n').slice(0, 3).join('\n'));
        log('ERROR', '');
        
        isInitializing = false;
        
        // Check if recoverable
        const errorMsg = err.message.toLowerCase();
        const isRecoverable = 
            errorMsg.includes('frame') ||
            errorMsg.includes('detached') ||
            errorMsg.includes('target closed') ||
            errorMsg.includes('protocol error') ||
            errorMsg.includes('navigation') ||
            errorMsg.includes('timeout') ||
            errorMsg.includes('session') ||
            errorMsg.includes('browser');
        
        if (isRecoverable && initAttempts < MAX_INIT_ATTEMPTS) {
            initError = `Attempt ${initAttempts} failed: ${err.message}`;
            log('INFO', 'Recoverable error, clearing session...');
            clearSession();
            log('INFO', `Retrying in 5s (attempt ${initAttempts + 1}/${MAX_INIT_ATTEMPTS})...`);
            setTimeout(() => initializeClient(), 5000);
            return;
        }
        
        initError = 'All connection attempts failed';
        
        log('ERROR', '');
        log('ERROR', 'TROUBLESHOOTING:');
        log('ERROR', '1. Install Google Chrome: https://www.google.com/chrome/');
        log('ERROR', '2. Close ALL browser windows');
        log('ERROR', '3. Delete .wwebjs_auth folder');
        log('ERROR', '4. Run: scripts\\diagnose-whatsapp.bat');
        log('ERROR', '5. Try with HEADLESS=false (see below)');
        log('ERROR', '');
        log('ERROR', 'To see the browser window, set HEADLESS=false:');
        log('ERROR', '  set HEADLESS=false && node index.js');
        log('ERROR', '');
    }
}

// =============================================
// API Routes
// =============================================

app.get('/status', (req, res) => {
    res.json({
        isReady,
        isAuthenticated,
        hasQrCode: !!qrCodeDataUrl,
        isInitializing,
        initAttempts,
        error: initError,
        clientInfo: clientInfo ? {
            pushname: clientInfo.pushname,
            wid: clientInfo.wid?._serialized,
            phone: clientInfo.wid?.user
        } : null
    });
});

app.get('/qr', (req, res) => {
    if (qrCodeDataUrl) {
        res.json({ qrCode: qrCodeDataUrl });
    } else if (isReady) {
        res.json({ qrCode: null, message: 'Already authenticated' });
    } else if (initError) {
        res.json({ qrCode: null, error: initError });
    } else if (isInitializing) {
        res.json({ 
            qrCode: null, 
            message: `Initializing (attempt ${initAttempts}/${MAX_INIT_ATTEMPTS})...`,
            isInitializing: true 
        });
    } else {
        res.json({ qrCode: null, message: 'Starting...' });
    }
});

app.post('/send', async (req, res) => {
    const { phone, message } = req.body;
    
    if (!isReady || !client) {
        return res.status(400).json({ success: false, error: 'WhatsApp not ready' });
    }
    
    if (!phone || !message) {
        return res.status(400).json({ success: false, error: 'Phone and message required' });
    }
    
    try {
        let cleanPhone = phone.replace(/\D/g, '');
        if (cleanPhone.length === 10) cleanPhone = '1' + cleanPhone;
        
        const formattedPhone = cleanPhone + '@c.us';
        log('INFO', 'Sending to:', formattedPhone);
        
        const result = await client.sendMessage(formattedPhone, message);
        log('INFO', 'Sent! ID:', result.id._serialized);
        
        res.json({ success: true, messageId: result.id._serialized });
    } catch (error) {
        log('ERROR', 'Send failed:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/logout', async (req, res) => {
    try {
        if (client && isReady) await client.logout();
        isReady = false;
        isAuthenticated = false;
        clientInfo = null;
        qrCodeDataUrl = null;
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/retry-init', async (req, res) => {
    log('INFO', 'Manual retry requested');
    initError = null;
    qrCodeDataUrl = null;
    isInitializing = false;
    initAttempts = 0;
    res.json({ success: true });
    initializeClient();
});

app.post('/clear-session', async (req, res) => {
    log('INFO', 'Clear session requested');
    try {
        if (client) {
            try { await client.destroy(); } catch (e) {}
            client = null;
        }
        isReady = false;
        isAuthenticated = false;
        isInitializing = false;
        initAttempts = 0;
        qrCodeDataUrl = null;
        clientInfo = null;
        initError = null;
        clearSession();
        res.json({ success: true });
        setTimeout(() => initializeClient(), 2000);
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok', ready: isReady, timestamp: new Date().toISOString() });
});

// Test browser launch endpoint
app.get('/test-browser', async (req, res) => {
    log('INFO', 'Testing browser launch...');
    try {
        const puppeteer = require('puppeteer');
        const chromePath = findChrome();
        
        const launchOptions = {
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox'],
        };
        
        if (chromePath) {
            launchOptions.executablePath = chromePath;
        }
        
        log('INFO', 'Launching browser...');
        const browser = await puppeteer.launch(launchOptions);
        
        log('INFO', 'Opening page...');
        const page = await browser.newPage();
        
        log('INFO', 'Navigating to WhatsApp Web...');
        await page.goto('https://web.whatsapp.com', { waitUntil: 'domcontentloaded', timeout: 30000 });
        
        log('INFO', 'Page loaded!');
        const title = await page.title();
        
        await browser.close();
        log('INFO', 'Browser test successful!');
        
        res.json({ 
            success: true, 
            message: 'Browser test passed',
            pageTitle: title,
            chromePath: chromePath || 'bundled'
        });
    } catch (error) {
        log('ERROR', 'Browser test failed:', error.message);
        res.json({ 
            success: false, 
            error: error.message,
            stack: error.stack?.split('\n').slice(0, 5)
        });
    }
});

// =============================================
// Start Server
// =============================================

const PORT = process.env.WA_PORT || 3001;

app.listen(PORT, '0.0.0.0', () => {
    log('INFO', `Server running on http://localhost:${PORT}`);
    log('INFO', '');
    log('INFO', 'Endpoints:');
    log('INFO', `  Status:       http://localhost:${PORT}/status`);
    log('INFO', `  QR Code:      http://localhost:${PORT}/qr`);
    log('INFO', `  Health:       http://localhost:${PORT}/health`);
    log('INFO', `  Test Browser: http://localhost:${PORT}/test-browser`);
    log('INFO', '');
    
    // Check HEADLESS env
    if (process.env.HEADLESS === 'false') {
        log('INFO', 'HEADLESS=false - Browser window will be visible');
    }
    
    setTimeout(() => initializeClient(), 1000);
});

process.on('SIGINT', async () => {
    log('INFO', 'Shutting down...');
    if (client) try { await client.destroy(); } catch (e) {}
    process.exit(0);
});

process.on('uncaughtException', (err) => {
    log('ERROR', 'Uncaught exception:', err.message);
    log('ERROR', err.stack);
    initError = 'Fatal error: ' + err.message;
    isInitializing = false;
});

process.on('unhandledRejection', (reason) => {
    log('ERROR', 'Unhandled rejection:', reason);
});
