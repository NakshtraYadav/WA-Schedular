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
console.log('  WhatsApp Web Service v2.0 (Hardened)');
console.log('================================================');
console.log('');

// Session path
const SESSION_PATH = path.join(__dirname, '.wwebjs_auth');

// Function to clear corrupted session
function clearSession() {
    try {
        if (fs.existsSync(SESSION_PATH)) {
            fs.rmSync(SESSION_PATH, { recursive: true, force: true });
            console.log('[Session] Cleared corrupted session data');
            return true;
        }
    } catch (err) {
        console.error('[Session] Error clearing session:', err.message);
    }
    return false;
}

// Create client with robust configuration
function createClient() {
    console.log('[Client] Creating WhatsApp client with hardened config...');
    
    const clientConfig = {
        authStrategy: new LocalAuth({
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
                '--no-zygote',
                '--disable-gpu',
                '--disable-extensions',
                '--disable-software-rasterizer',
                '--disable-features=site-per-process',
                '--disable-web-security',
                '--disable-features=IsolateOrigins',
                '--disable-site-isolation-trials',
                '--ignore-certificate-errors',
                '--ignore-certificate-errors-spki-list',
                '--disable-blink-features=AutomationControlled'
            ],
            defaultViewport: null,
            ignoreHTTPSErrors: true,
        },
        // Critical: Use local web version to avoid "frame detached" errors
        webVersionCache: {
            type: 'local',
            path: path.join(__dirname, '.wwebjs_cache')
        },
        // Increase timeouts
        qrMaxRetries: 5,
    };
    
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
        console.log('Scan with WhatsApp: Settings > Linked Devices > Link a Device');
        console.log('Or open: http://localhost:3000/connect');
        console.log('');
        
        try {
            qrCodeDataUrl = await qrcode.toDataURL(qr);
            isAuthenticated = false;
            isReady = false;
            initError = null;
        } catch (err) {
            console.error('[QR] Error generating QR code:', err.message);
        }
    });

    // Loading screen event
    clientInstance.on('loading_screen', (percent, message) => {
        console.log(`[Loading] ${percent}% - ${message}`);
    });

    // Ready event
    clientInstance.on('ready', () => {
        console.log('');
        console.log('================================================');
        console.log('  WHATSAPP CONNECTED!');
        console.log('================================================');
        
        isReady = true;
        isAuthenticated = true;
        isInitializing = false;
        initAttempts = 0;
        qrCodeDataUrl = null;
        initError = null;
        clientInfo = clientInstance.info;
        
        if (clientInfo) {
            console.log(`Logged in as: ${clientInfo.pushname}`);
            console.log(`Phone: ${clientInfo.wid?.user}`);
        }
        console.log('You can now send messages!');
        console.log('');
    });

    // Authenticated event
    clientInstance.on('authenticated', () => {
        console.log('[Auth] WhatsApp authenticated successfully');
        isAuthenticated = true;
        initError = null;
    });

    // Auth failure event
    clientInstance.on('auth_failure', async (msg) => {
        console.error('[Auth] Authentication failed:', msg);
        isAuthenticated = false;
        isReady = false;
        isInitializing = false;
        initError = 'Authentication failed. Clearing session...';
        
        // Clear session and retry
        clearSession();
        
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            console.log('[Auth] Will retry initialization in 5 seconds...');
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
        
        // Handle specific disconnect reasons
        if (reason === 'NAVIGATION' || reason === 'LOGOUT' || reason === 'CONFLICT') {
            console.log('[Disconnect] Will attempt to reconnect in 10 seconds...');
            setTimeout(() => initializeClient(), 10000);
        }
    });

    // Change state event
    clientInstance.on('change_state', (state) => {
        console.log('[State] WhatsApp state changed to:', state);
    });

    // Message received
    clientInstance.on('message', (msg) => {
        if (!msg.isStatus) {
            console.log(`[Message] From ${msg.from}: ${msg.body?.substring(0, 50) || '(media)'}...`);
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
    
    console.log(`[Init] Initialization attempt ${initAttempts}/${MAX_INIT_ATTEMPTS}`);
    
    try {
        // Destroy existing client
        if (client) {
            console.log('[Init] Destroying existing client...');
            try { 
                await client.destroy(); 
            } catch (e) {
                console.log('[Init] Client destroy warning:', e.message);
            }
            client = null;
            
            // Wait for cleanup
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
        client = createClient();
        setupClientEvents(client);
        
        console.log('[Init] Starting WhatsApp client...');
        console.log('[Init] This may take 30-90 seconds on first run...');
        console.log('');
        
        // Initialize with timeout
        const initPromise = client.initialize();
        const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Initialization timeout after 120 seconds')), 120000)
        );
        
        await Promise.race([initPromise, timeoutPromise]);
        
    } catch (err) {
        console.error('');
        console.error('================================================');
        console.error('  INITIALIZATION ERROR');
        console.error('================================================');
        console.error(`Error: ${err.message}`);
        console.error('');
        
        isInitializing = false;
        
        // Handle "Navigating frame was detached" specifically
        if (err.message.includes('frame was detached') || 
            err.message.includes('Navigating frame') ||
            err.message.includes('Target closed') ||
            err.message.includes('Protocol error')) {
            
            initError = 'WhatsApp Web navigation error. Clearing session and retrying...';
            console.log('[Error] Frame detachment detected - clearing session');
            clearSession();
            
            if (initAttempts < MAX_INIT_ATTEMPTS) {
                console.log(`[Error] Retrying in 5 seconds... (attempt ${initAttempts + 1}/${MAX_INIT_ATTEMPTS})`);
                setTimeout(() => initializeClient(), 5000);
                return;
            }
        }
        
        initError = err.message;
        
        console.log('TROUBLESHOOTING:');
        console.log('1. Run: npm run clean (clears session)');
        console.log('2. Close ALL Chrome/browser windows');
        console.log('3. Delete .wwebjs_auth and .wwebjs_cache folders manually');
        console.log('4. Reinstall: npm install');
        console.log('5. Restart your computer');
        console.log('');
        
        // Offer auto-retry
        if (initAttempts < MAX_INIT_ATTEMPTS) {
            console.log(`[Error] Auto-retrying in 10 seconds... (attempt ${initAttempts + 1}/${MAX_INIT_ATTEMPTS})`);
            setTimeout(() => initializeClient(), 10000);
        } else {
            console.log('[Error] Max retry attempts reached. Please troubleshoot manually.');
            initError = `Failed after ${MAX_INIT_ATTEMPTS} attempts: ${err.message}. Try deleting .wwebjs_auth folder and restart.`;
        }
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
        res.json({ qrCode: null, message: 'Initializing... Please wait (30-90 seconds)', isInitializing: true });
    } else {
        res.json({ qrCode: null, message: 'Starting...' });
    }
});

app.post('/send', async (req, res) => {
    const { phone, message } = req.body;
    
    if (!isReady || !client) {
        return res.status(400).json({ success: false, error: 'WhatsApp not ready. Please scan QR code first.' });
    }
    
    if (!phone || !message) {
        return res.status(400).json({ success: false, error: 'Phone and message are required' });
    }
    
    try {
        // Clean phone number - remove all non-digits
        let cleanPhone = phone.replace(/\D/g, '');
        
        // Ensure it has country code (assume +1 if not)
        if (cleanPhone.length === 10) {
            cleanPhone = '1' + cleanPhone; // Add US country code
        }
        
        const formattedPhone = cleanPhone + '@c.us';
        console.log(`[Send] Sending to ${formattedPhone}...`);
        
        // Check if number is registered on WhatsApp
        const isRegistered = await client.isRegisteredUser(formattedPhone);
        if (!isRegistered) {
            console.log(`[Send] Warning: ${cleanPhone} may not be on WhatsApp`);
        }
        
        const result = await client.sendMessage(formattedPhone, message);
        console.log(`[Send] Success! Message ID: ${result.id._serialized}`);
        
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
        if (client) {
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
    console.log('[Retry] Manual retry requested...');
    initError = null;
    qrCodeDataUrl = null;
    isInitializing = false;
    initAttempts = 0;
    res.json({ success: true, message: 'Reinitialization started' });
    initializeClient();
});

app.post('/clear-session', async (req, res) => {
    console.log('[Clear] Session clear requested...');
    
    try {
        // Destroy client first
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
        
        // Clear session files
        clearSession();
        
        // Also clear cache
        const cachePath = path.join(__dirname, '.wwebjs_cache');
        if (fs.existsSync(cachePath)) {
            fs.rmSync(cachePath, { recursive: true, force: true });
            console.log('[Clear] Cleared cache data');
        }
        
        res.json({ success: true, message: 'Session cleared. Restart service to reinitialize.' });
        
        // Auto-restart initialization
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
    console.log(`[Server] WhatsApp service running on http://localhost:${PORT}`);
    console.log('');
    
    // Delay initialization to let Express start cleanly
    setTimeout(() => {
        initializeClient();
    }, 1000);
});

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n[Shutdown] Shutting down gracefully...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\n[Shutdown] Received SIGTERM...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});

// Handle uncaught errors
process.on('uncaughtException', (err) => {
    console.error('[Fatal] Uncaught exception:', err.message);
    initError = 'Service crashed: ' + err.message;
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('[Fatal] Unhandled rejection:', reason);
});
