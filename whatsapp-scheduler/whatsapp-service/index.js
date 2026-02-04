const express = require('express');
const cors = require('cors');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

let qrCodeDataUrl = null;
let isReady = false;
let isAuthenticated = false;
let clientInfo = null;
let initError = null;
let client = null;
let isInitializing = false;
let initAttempts = 0;
const MAX_INIT_ATTEMPTS = 3;

console.log('================================================');
console.log('  WhatsApp Web Service v2.1 (Windows Hardened)');
console.log('================================================');
console.log('');

// Paths
const SESSION_PATH = path.join(__dirname, '.wwebjs_auth');
const CACHE_PATH = path.join(__dirname, '.wwebjs_cache');

// Clear corrupted session
function clearSession() {
    let cleared = false;
    try {
        if (fs.existsSync(SESSION_PATH)) {
            fs.rmSync(SESSION_PATH, { recursive: true, force: true });
            console.log('[Session] Cleared session data');
            cleared = true;
        }
        if (fs.existsSync(CACHE_PATH)) {
            fs.rmSync(CACHE_PATH, { recursive: true, force: true });
            console.log('[Session] Cleared cache data');
            cleared = true;
        }
    } catch (err) {
        console.error('[Session] Error clearing:', err.message);
    }
    return cleared;
}

// Find Chrome executable on Windows
function findChrome() {
    const possiblePaths = [
        process.env.CHROME_PATH,
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        path.join(process.env.LOCALAPPDATA || '', 'Google\\Chrome\\Application\\chrome.exe'),
        path.join(process.env.PROGRAMFILES || '', 'Google\\Chrome\\Application\\chrome.exe'),
        path.join(process.env['PROGRAMFILES(X86)'] || '', 'Google\\Chrome\\Application\\chrome.exe'),
        // Edge as fallback
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    ].filter(Boolean);

    for (const chromePath of possiblePaths) {
        if (fs.existsSync(chromePath)) {
            console.log('[Chrome] Found at:', chromePath);
            return chromePath;
        }
    }
    
    console.log('[Chrome] Not found in common locations, using bundled Chromium');
    return null;
}

// Create client with robust configuration
function createClient() {
    console.log('[Client] Creating WhatsApp client...');
    
    const chromePath = findChrome();
    
    const puppeteerArgs = [
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
        '--window-size=1920,1080'
    ];

    const clientConfig = {
        authStrategy: new LocalAuth({
            dataPath: SESSION_PATH
        }),
        puppeteer: {
            headless: true,
            args: puppeteerArgs,
            defaultViewport: null,
            ignoreHTTPSErrors: true,
            timeout: 60000,
        },
        qrMaxRetries: 5,
        takeoverOnConflict: true,
        takeoverTimeoutMs: 10000,
    };

    // Use system Chrome if found
    if (chromePath) {
        clientConfig.puppeteer.executablePath = chromePath;
    }
    
    return new Client(clientConfig);
}

function setupClientEvents(clientInstance) {
    // QR Code event
    clientInstance.on('qr', async (qr) => {
        console.log('');
        console.log('================================================');
        console.log('  QR CODE RECEIVED!');
        console.log('================================================');
        console.log('');
        console.log('Scan with WhatsApp:');
        console.log('  Settings > Linked Devices > Link a Device');
        console.log('');
        console.log('Or open: http://localhost:3000/connect');
        console.log('');
        
        try {
            qrCodeDataUrl = await qrcode.toDataURL(qr);
            isAuthenticated = false;
            isReady = false;
            initError = null;
            isInitializing = false;
        } catch (err) {
            console.error('[QR] Error generating QR code:', err.message);
        }
    });

    // Loading screen
    clientInstance.on('loading_screen', (percent, message) => {
        console.log(`[Loading] ${percent}% - ${message}`);
    });

    // Ready event
    clientInstance.on('ready', () => {
        console.log('');
        console.log('================================================');
        console.log('  WHATSAPP CONNECTED SUCCESSFULLY!');
        console.log('================================================');
        
        isReady = true;
        isAuthenticated = true;
        isInitializing = false;
        initAttempts = 0;
        qrCodeDataUrl = null;
        initError = null;
        clientInfo = clientInstance.info;
        
        if (clientInfo) {
            console.log(`  Logged in as: ${clientInfo.pushname}`);
            console.log(`  Phone: ${clientInfo.wid?.user}`);
        }
        console.log('');
        console.log('  You can now send messages!');
        console.log('================================================');
        console.log('');
    });

    // Authenticated event
    clientInstance.on('authenticated', () => {
        console.log('[Auth] WhatsApp authenticated');
        isAuthenticated = true;
        initError = null;
    });

    // Auth failure event
    clientInstance.on('auth_failure', async (msg) => {
        console.error('[Auth] Authentication failed:', msg);
        isAuthenticated = false;
        isReady = false;
        isInitializing = false;
        initError = 'Authentication failed: ' + msg;
        
        // Clear corrupted session
        clearSession();
        
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            console.log('[Auth] Retrying in 5 seconds...');
            setTimeout(() => initializeClient(), 5000);
        }
    });

    // Disconnected event
    clientInstance.on('disconnected', async (reason) => {
        console.log('[Disconnect] WhatsApp disconnected:', reason);
        isReady = false;
        isAuthenticated = false;
        qrCodeDataUrl = null;
        clientInfo = null;
        
        if (reason === 'NAVIGATION' || reason === 'LOGOUT' || reason === 'CONFLICT') {
            console.log('[Disconnect] Auto-reconnecting in 10 seconds...');
            setTimeout(() => initializeClient(), 10000);
        }
    });

    // Change state
    clientInstance.on('change_state', (state) => {
        console.log('[State] Changed to:', state);
    });

    // Message received
    clientInstance.on('message', (msg) => {
        if (!msg.isStatus) {
            const preview = msg.body?.substring(0, 50) || '(media)';
            console.log(`[Message] From ${msg.from}: ${preview}...`);
        }
    });
}

async function initializeClient() {
    if (isInitializing) {
        console.log('[Init] Already initializing, skipping...');
        return;
    }
    
    isInitializing = true;
    initAttempts++;
    initError = null;
    
    console.log(`[Init] Attempt ${initAttempts}/${MAX_INIT_ATTEMPTS}`);
    
    try {
        // Destroy existing client
        if (client) {
            console.log('[Init] Destroying existing client...');
            try { 
                await client.destroy(); 
            } catch (e) {
                console.log('[Init] Destroy warning:', e.message);
            }
            client = null;
            await new Promise(r => setTimeout(r, 2000));
        }
        
        client = createClient();
        setupClientEvents(client);
        
        console.log('[Init] Starting WhatsApp client...');
        console.log('[Init] This may take 30-90 seconds...');
        console.log('');
        
        // Initialize with timeout
        const initPromise = client.initialize();
        const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Initialization timeout (120s)')), 120000)
        );
        
        await Promise.race([initPromise, timeoutPromise]);
        
    } catch (err) {
        console.error('');
        console.error('================================================');
        console.error('  INITIALIZATION ERROR');
        console.error('================================================');
        console.error('Error:', err.message);
        console.error('');
        
        isInitializing = false;
        
        // Handle frame detachment and similar errors
        const isRecoverableError = 
            err.message.includes('frame') ||
            err.message.includes('detached') ||
            err.message.includes('Target closed') ||
            err.message.includes('Protocol error') ||
            err.message.includes('Navigation') ||
            err.message.includes('timeout') ||
            err.message.includes('Session');
        
        if (isRecoverableError && initAttempts < MAX_INIT_ATTEMPTS) {
            initError = `Attempt ${initAttempts} failed: ${err.message}. Retrying...`;
            console.log('[Error] Recoverable error, clearing session...');
            clearSession();
            console.log(`[Error] Retrying in 5 seconds (attempt ${initAttempts + 1}/${MAX_INIT_ATTEMPTS})...`);
            setTimeout(() => initializeClient(), 5000);
            return;
        }
        
        initError = `All connection attempts failed`;
        
        console.log('');
        console.log('TROUBLESHOOTING STEPS:');
        console.log('1. Make sure Google Chrome or Microsoft Edge is installed');
        console.log('2. Close ALL browser windows');
        console.log('3. Delete .wwebjs_auth and .wwebjs_cache folders');
        console.log('4. Disable antivirus temporarily');
        console.log('5. Restart your computer');
        console.log('6. Run: npm run clean && npm start');
        console.log('');
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
            message: `Initializing... (attempt ${initAttempts}/${MAX_INIT_ATTEMPTS})`,
            isInitializing: true 
        });
    } else {
        res.json({ qrCode: null, message: 'Starting...' });
    }
});

app.post('/send', async (req, res) => {
    const { phone, message } = req.body;
    
    if (!isReady || !client) {
        return res.status(400).json({ 
            success: false, 
            error: 'WhatsApp not ready. Please scan QR code first.' 
        });
    }
    
    if (!phone || !message) {
        return res.status(400).json({ 
            success: false, 
            error: 'Phone and message are required' 
        });
    }
    
    try {
        let cleanPhone = phone.replace(/\D/g, '');
        
        // Add country code if missing (default US)
        if (cleanPhone.length === 10) {
            cleanPhone = '1' + cleanPhone;
        }
        
        const formattedPhone = cleanPhone + '@c.us';
        console.log(`[Send] Sending to ${formattedPhone}...`);
        
        const result = await client.sendMessage(formattedPhone, message);
        console.log(`[Send] Success! ID: ${result.id._serialized}`);
        
        res.json({ 
            success: true, 
            messageId: result.id._serialized,
            timestamp: result.timestamp
        });
    } catch (error) {
        console.error('[Send] Error:', error.message);
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

app.post('/retry-init', async (req, res) => {
    console.log('[API] Manual retry requested');
    initError = null;
    qrCodeDataUrl = null;
    isInitializing = false;
    initAttempts = 0;
    res.json({ success: true, message: 'Reinitialization started' });
    initializeClient();
});

app.post('/clear-session', async (req, res) => {
    console.log('[API] Clear session requested');
    
    try {
        // Destroy client
        if (client) {
            try { await client.destroy(); } catch (e) {}
            client = null;
        }
        
        // Reset state
        isReady = false;
        isAuthenticated = false;
        isInitializing = false;
        initAttempts = 0;
        qrCodeDataUrl = null;
        clientInfo = null;
        initError = null;
        
        // Clear files
        clearSession();
        
        res.json({ success: true, message: 'Session cleared' });
        
        // Restart
        setTimeout(() => initializeClient(), 2000);
        
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        service: 'whatsapp',
        ready: isReady,
        timestamp: new Date().toISOString() 
    });
});

// =============================================
// Start Server
// =============================================

const PORT = process.env.WA_PORT || 3001;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Server] Running on http://localhost:${PORT}`);
    console.log('');
    
    // Delay init to let Express start
    setTimeout(() => initializeClient(), 1000);
});

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n[Shutdown] Graceful shutdown...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\n[Shutdown] SIGTERM received...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});

// Catch unhandled errors
process.on('uncaughtException', (err) => {
    console.error('[Fatal] Uncaught exception:', err.message);
    initError = 'Service error: ' + err.message;
    isInitializing = false;
});

process.on('unhandledRejection', (reason) => {
    console.error('[Fatal] Unhandled rejection:', reason);
});
