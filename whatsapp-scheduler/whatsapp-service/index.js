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

const log = (level, ...args) => {
    const ts = new Date().toISOString().substr(11, 8);
    console.log(`[${ts}] [${level}]`, ...args);
};

log('INFO', '================================================');
log('INFO', '  WhatsApp Web Service v2.3');
log('INFO', '  Using whatsapp-web.js@1.23.0 + puppeteer@21.5.0');
log('INFO', '================================================');
log('INFO', '');

const SESSION_PATH = path.join(__dirname, '.wwebjs_auth');

function clearSession() {
    try {
        if (fs.existsSync(SESSION_PATH)) {
            fs.rmSync(SESSION_PATH, { recursive: true, force: true });
            log('INFO', 'Session cleared');
        }
        const cachePath = path.join(__dirname, '.wwebjs_cache');
        if (fs.existsSync(cachePath)) {
            fs.rmSync(cachePath, { recursive: true, force: true });
        }
        return true;
    } catch (err) {
        log('ERROR', 'Clear failed:', err.message);
        return false;
    }
}

function findChrome() {
    const paths = [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'Google\\Chrome\\Application\\chrome.exe') : null,
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
        '/usr/bin/google-chrome',
        '/usr/bin/chromium-browser',
    ].filter(Boolean);

    for (const p of paths) {
        if (fs.existsSync(p)) {
            log('INFO', 'Using browser:', p);
            return p;
        }
    }
    log('INFO', 'Using bundled Chromium');
    return null;
}

function createClient() {
    log('INFO', 'Creating client...');
    
    const chromePath = findChrome();
    
    const config = {
        authStrategy: new LocalAuth({ dataPath: SESSION_PATH }),
        puppeteer: {
            headless: true,
            executablePath: chromePath || undefined,
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--single-process',
                '--disable-gpu',
                '--disable-extensions',
                '--disable-software-rasterizer'
            ],
            timeout: 60000,
        },
        qrMaxRetries: 5,
    };
    
    return new Client(config);
}

function setupEvents(c) {
    c.on('qr', async (qr) => {
        log('INFO', '');
        log('INFO', '========== QR CODE READY =========');
        log('INFO', 'Scan at: http://localhost:3000/connect');
        log('INFO', '===================================');
        log('INFO', '');
        
        try {
            qrCodeDataUrl = await qrcode.toDataURL(qr);
            isAuthenticated = false;
            isReady = false;
            initError = null;
            isInitializing = false;
        } catch (err) {
            log('ERROR', 'QR error:', err.message);
        }
    });

    c.on('loading_screen', (percent, message) => {
        log('INFO', `Loading: ${percent}% - ${message}`);
    });

    c.on('ready', () => {
        log('INFO', '');
        log('INFO', '========== CONNECTED! ==========');
        isReady = true;
        isAuthenticated = true;
        isInitializing = false;
        initAttempts = 0;
        qrCodeDataUrl = null;
        initError = null;
        clientInfo = c.info;
        if (clientInfo) {
            log('INFO', 'User:', clientInfo.pushname);
            log('INFO', 'Phone:', clientInfo.wid?.user);
        }
        log('INFO', '=================================');
        log('INFO', '');
    });

    c.on('authenticated', () => {
        log('INFO', 'Authenticated');
        isAuthenticated = true;
        initError = null;
    });

    c.on('auth_failure', async (msg) => {
        log('ERROR', 'Auth failed:', msg);
        isAuthenticated = false;
        isReady = false;
        isInitializing = false;
        initError = 'Auth failed: ' + msg;
        clearSession();
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            setTimeout(() => initializeClient(), 5000);
        }
    });

    c.on('disconnected', async (reason) => {
        log('WARN', 'Disconnected:', reason);
        isReady = false;
        isAuthenticated = false;
        qrCodeDataUrl = null;
        clientInfo = null;
        if (['NAVIGATION', 'LOGOUT', 'CONFLICT'].includes(reason)) {
            setTimeout(() => initializeClient(), 10000);
        }
    });

    c.on('message', (msg) => {
        if (!msg.isStatus) {
            log('MSG', `${msg.from}: ${(msg.body || '').substring(0, 30)}...`);
        }
    });
}

async function initializeClient() {
    if (isInitializing) return;
    
    isInitializing = true;
    initAttempts++;
    initError = null;
    
    log('INFO', `Attempt ${initAttempts}/${MAX_INIT_ATTEMPTS}`);
    
    try {
        if (client) {
            log('INFO', 'Destroying old client...');
            try { await client.destroy(); } catch (e) {}
            client = null;
            await new Promise(r => setTimeout(r, 3000));
        }
        
        client = createClient();
        setupEvents(client);
        
        log('INFO', 'Initializing... (30-90 seconds)');
        
        await Promise.race([
            client.initialize(),
            new Promise((_, rej) => setTimeout(() => rej(new Error('Timeout 120s')), 120000))
        ]);
        
    } catch (err) {
        log('ERROR', 'Init failed:', err.message);
        isInitializing = false;
        
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            initError = `Attempt ${initAttempts} failed: ${err.message}`;
            log('INFO', 'Clearing session and retrying in 5s...');
            clearSession();
            setTimeout(() => initializeClient(), 5000);
        } else {
            initError = 'All attempts failed. Try: 1) Close all Chrome windows 2) Run scripts\\fix-whatsapp.bat 3) Restart PC';
            log('ERROR', initError);
        }
    }
}

// Routes
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
    if (qrCodeDataUrl) res.json({ qrCode: qrCodeDataUrl });
    else if (isReady) res.json({ qrCode: null, message: 'Already connected' });
    else if (initError) res.json({ qrCode: null, error: initError });
    else if (isInitializing) res.json({ qrCode: null, message: `Initializing (${initAttempts}/${MAX_INIT_ATTEMPTS})...`, isInitializing: true });
    else res.json({ qrCode: null, message: 'Starting...' });
});

app.post('/send', async (req, res) => {
    const { phone, message } = req.body;
    if (!isReady || !client) return res.status(400).json({ success: false, error: 'Not ready' });
    if (!phone || !message) return res.status(400).json({ success: false, error: 'Phone and message required' });
    
    try {
        let clean = phone.replace(/\D/g, '');
        if (clean.length === 10) clean = '1' + clean;
        const formatted = clean + '@c.us';
        log('INFO', 'Sending to:', formatted);
        const result = await client.sendMessage(formatted, message);
        log('INFO', 'Sent:', result.id._serialized);
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

app.post('/retry-init', (req, res) => {
    log('INFO', 'Manual retry');
    initError = null;
    qrCodeDataUrl = null;
    isInitializing = false;
    initAttempts = 0;
    res.json({ success: true });
    initializeClient();
});

app.post('/clear-session', async (req, res) => {
    log('INFO', 'Clear session');
    try {
        if (client) { try { await client.destroy(); } catch (e) {} client = null; }
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
    res.json({ status: 'ok', ready: isReady });
});

// Start
const PORT = 3001;

const server = app.listen(PORT, '0.0.0.0', () => {
    log('INFO', `Server: http://localhost:${PORT}`);
    log('INFO', '');
    setTimeout(() => initializeClient(), 1000);
});

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        log('ERROR', `Port ${PORT} is already in use!`);
        log('ERROR', 'Run stop.bat first, or:');
        log('ERROR', '  netstat -ano | findstr :3001');
        log('ERROR', '  taskkill /F /PID <pid>');
        process.exit(1);
    }
    throw err;
});

process.on('SIGINT', async () => {
    log('INFO', 'Shutting down...');
    if (client) try { await client.destroy(); } catch (e) {}
    process.exit(0);
});

process.on('uncaughtException', (err) => {
    log('ERROR', 'Fatal:', err.message);
    initError = err.message;
    isInitializing = false;
});

process.on('unhandledRejection', (reason) => {
    log('ERROR', 'Unhandled:', reason);
});
