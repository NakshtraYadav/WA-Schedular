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
log('INFO', '  WhatsApp Web Service v3.0');
log('INFO', '  Using whatsapp-web.js@1.34.6 (latest stable)');
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
        '/usr/bin/chromium',
    ].filter(Boolean);

    for (const p of paths) {
        if (fs.existsSync(p)) {
            log('INFO', 'Using browser:', p);
            return p;
        }
    }
    log('INFO', 'Using bundled Chromium from puppeteer');
    return null;
}

function createClient() {
    log('INFO', 'Creating client with whatsapp-web.js@1.34.6...');
    
    const chromePath = findChrome();
    
    // Official recommended configuration for v1.34.x
    const config = {
        authStrategy: new LocalAuth({
            clientId: 'whatsapp-scheduler',
            dataPath: SESSION_PATH
        }),
        puppeteer: {
            headless: true,
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--disable-gpu',
                '--disable-extensions',
                '--disable-software-rasterizer',
                '--disable-features=site-per-process',
                '--disable-web-security'
            ],
            timeout: 120000,
        },
        qrMaxRetries: 5,
        takeoverOnConflict: true,
        takeoverTimeoutMs: 10000
    };
    
    // Only set executablePath if a browser was found
    if (chromePath) {
        config.puppeteer.executablePath = chromePath;
    }
    
    return new Client(config);
}

function setupEvents(c) {
    // IMPORTANT: Set up ALL event handlers BEFORE calling initialize()
    
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
            log('ERROR', 'QR generation error:', err.message);
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
        log('INFO', 'Authenticated successfully');
        isAuthenticated = true;
        initError = null;
    });

    c.on('auth_failure', async (msg) => {
        log('ERROR', 'Authentication failed:', msg);
        isAuthenticated = false;
        isReady = false;
        isInitializing = false;
        initError = 'Authentication failed: ' + msg;
        clearSession();
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            log('INFO', 'Retrying in 5 seconds...');
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
            log('INFO', 'Reconnecting in 10 seconds...');
            setTimeout(() => initializeClient(), 10000);
        }
    });

    c.on('message', (msg) => {
        if (!msg.isStatus) {
            log('MSG', `${msg.from}: ${(msg.body || '').substring(0, 30)}...`);
        }
    });
    
    c.on('change_state', (state) => {
        log('INFO', 'State changed:', state);
    });
}

async function initializeClient() {
    if (isInitializing) {
        log('INFO', 'Already initializing, skipping...');
        return;
    }
    
    isInitializing = true;
    initAttempts++;
    initError = null;
    
    log('INFO', `Initialization attempt ${initAttempts}/${MAX_INIT_ATTEMPTS}`);
    
    try {
        // Destroy old client if exists
        if (client) {
            log('INFO', 'Destroying previous client instance...');
            try { 
                await client.destroy(); 
            } catch (e) {
                log('WARN', 'Error destroying old client:', e.message);
            }
            client = null;
            await new Promise(r => setTimeout(r, 3000));
        }
        
        // Create new client
        client = createClient();
        
        // Set up events BEFORE initialize (critical!)
        setupEvents(client);
        
        log('INFO', 'Starting initialization... (this may take 30-120 seconds)');
        
        // Initialize with timeout
        await Promise.race([
            client.initialize(),
            new Promise((_, rej) => setTimeout(() => rej(new Error('Initialization timeout (180s)')), 180000))
        ]);
        
        log('INFO', 'Initialization completed successfully');
        
    } catch (err) {
        log('ERROR', 'Initialization failed:', err.message);
        isInitializing = false;
        
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            initError = `Attempt ${initAttempts} failed: ${err.message}`;
            
            // Only clear session if it's an auth-related error, not a browser error
            const shouldClearSession = err.message.toLowerCase().includes('auth') || 
                                       err.message.toLowerCase().includes('session') ||
                                       err.message.toLowerCase().includes('protocol');
            
            if (shouldClearSession) {
                log('INFO', 'Auth error detected, clearing session...');
                clearSession();
            } else {
                log('INFO', 'Browser/timeout error - keeping session for retry');
            }
            
            log('INFO', 'Retrying in 5 seconds...');
            setTimeout(() => initializeClient(), 5000);
        } else {
            initError = 'All initialization attempts failed. Suggestions:\n' +
                '1) Close all Chrome/Edge windows\n' +
                '2) Run scripts\\fix-whatsapp.bat\n' +
                '3) Restart your computer\n' +
                '4) Check if antivirus is blocking puppeteer';
            log('ERROR', initError);
        }
    }
}

// ============================================================================
// API Routes
// ============================================================================

app.get('/status', (req, res) => {
    // Check if session exists
    const sessionExists = fs.existsSync(path.join(SESSION_PATH, 'session-whatsapp-scheduler'));
    
    res.json({
        isReady,
        isAuthenticated,
        hasQrCode: !!qrCodeDataUrl,
        isInitializing,
        initAttempts,
        error: initError,
        version: '1.6.0',
        library: 'whatsapp-web.js@1.34.6',
        hasSession: sessionExists,
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
        res.json({ qrCode: null, message: 'Already connected' });
    } else if (initError) {
        res.json({ qrCode: null, error: initError });
    } else if (isInitializing) {
        res.json({ 
            qrCode: null, 
            message: `Initializing browser... (${initAttempts}/${MAX_INIT_ATTEMPTS})`, 
            isInitializing: true 
        });
    } else {
        res.json({ qrCode: null, message: 'Starting service...' });
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
        let clean = phone.replace(/\D/g, '');
        if (clean.length === 10) clean = '1' + clean;
        const formatted = clean + '@c.us';
        log('INFO', 'Sending message to:', formatted);
        const result = await client.sendMessage(formatted, message);
        log('INFO', 'Message sent:', result.id._serialized);
        res.json({ success: true, messageId: result.id._serialized });
    } catch (error) {
        log('ERROR', 'Send failed:', error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/logout', async (req, res) => {
    try {
        if (client && isReady) {
            await client.logout();
        }
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
    log('INFO', 'Manual retry requested');
    initError = null;
    qrCodeDataUrl = null;
    isInitializing = false;
    initAttempts = 0;
    res.json({ success: true, message: 'Retry initiated' });
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
        res.json({ success: true, message: 'Session cleared, restarting...' });
        setTimeout(() => initializeClient(), 2000);
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        ready: isReady,
        version: '3.0.0'
    });
});

// Get all WhatsApp contacts
app.get('/contacts', async (req, res) => {
    if (!isReady || !client) {
        return res.status(400).json({ 
            success: false, 
            error: 'WhatsApp not connected',
            contacts: []
        });
    }
    
    try {
        log('INFO', 'Fetching contacts...');
        const contacts = await client.getContacts();
        
        // Filter to only real contacts (not groups, broadcasts)
        const realContacts = contacts.filter(c => 
            c.isUser && 
            !c.isGroup && 
            !c.isBroadcast && 
            c.id._serialized.endsWith('@c.us')
        );
        
        const formattedContacts = realContacts.map(c => ({
            id: c.id._serialized,
            number: c.id.user,
            name: c.name || c.pushname || c.id.user,
            pushname: c.pushname,
            isMyContact: c.isMyContact,
            isBlocked: c.isBlocked
        }));
        
        log('INFO', `Found ${formattedContacts.length} contacts`);
        
        res.json({
            success: true,
            contacts: formattedContacts,
            total: formattedContacts.length
        });
    } catch (error) {
        log('ERROR', 'Failed to get contacts:', error.message);
        res.status(500).json({
            success: false,
            error: error.message,
            contacts: []
        });
    }
});

// Test browser endpoint for diagnostics
app.get('/test-browser', async (req, res) => {
    log('INFO', 'Testing browser launch...');
    try {
        const puppeteer = require('puppeteer');
        const chromePath = findChrome();
        
        const browser = await puppeteer.launch({
            headless: true,
            executablePath: chromePath || undefined,
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        });
        
        const version = await browser.version();
        await browser.close();
        
        res.json({ 
            success: true, 
            message: 'Browser launched successfully',
            browserVersion: version,
            chromePath: chromePath || 'bundled'
        });
    } catch (error) {
        res.json({ 
            success: false, 
            error: error.message 
        });
    }
});

// ============================================================================
// Server Start
// ============================================================================
const PORT = 3001;

const server = app.listen(PORT, '0.0.0.0', () => {
    log('INFO', `WhatsApp service listening on http://localhost:${PORT}`);
    log('INFO', '');
    log('INFO', 'Available endpoints:');
    log('INFO', '  GET  /status       - Get service status');
    log('INFO', '  GET  /qr           - Get QR code for scanning');
    log('INFO', '  GET  /health       - Health check');
    log('INFO', '  POST /send         - Send a message');
    log('INFO', '  POST /logout       - Logout from WhatsApp');
    log('INFO', '  POST /retry-init   - Retry initialization');
    log('INFO', '  POST /clear-session - Clear session and restart');
    log('INFO', '  GET  /test-browser - Test browser launch');
    log('INFO', '');
    
    // Start initialization after server is ready
    setTimeout(() => initializeClient(), 1000);
});

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        log('ERROR', `Port ${PORT} is already in use!`);
        log('ERROR', 'Run stop.bat first, or manually kill the process:');
        log('ERROR', '  netstat -ano | findstr :3001');
        log('ERROR', '  taskkill /F /PID <pid>');
        process.exit(1);
    }
    throw err;
});

// Graceful shutdown
process.on('SIGINT', async () => {
    log('INFO', 'Shutting down gracefully...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});

process.on('SIGTERM', async () => {
    log('INFO', 'Received SIGTERM, shutting down...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});

process.on('uncaughtException', (err) => {
    log('ERROR', 'Uncaught exception:', err.message);
    initError = 'Unexpected error: ' + err.message;
    isInitializing = false;
});

process.on('unhandledRejection', (reason) => {
    log('ERROR', 'Unhandled rejection:', reason);
});
