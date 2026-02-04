const express = require('express');
const cors = require('cors');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

let qrCodeDataUrl = null;
let isReady = false;
let isAuthenticated = false;
let clientInfo = null;
let initError = null;
let client = null;

console.log('================================================');
console.log('  WhatsApp Web Service');
console.log('================================================');
console.log('');

// Puppeteer configuration for whatsapp-web.js
const puppeteerConfig = {
    headless: true,
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
    ]
};

function createClient() {
    console.log('Creating WhatsApp client...');
    
    return new Client({
        authStrategy: new LocalAuth({
            dataPath: path.join(__dirname, '.wwebjs_auth')
        }),
        puppeteer: puppeteerConfig,
        webVersionCache: {
            type: 'remote',
            remotePath: 'https://raw.githubusercontent.com/AkashManohar/webVersionCache/main/AkashManohar/AkashManohar',
        }
    });
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
        
        qrCodeDataUrl = await qrcode.toDataURL(qr);
        isAuthenticated = false;
        isReady = false;
        initError = null;
    });

    // Ready event
    clientInstance.on('ready', () => {
        console.log('');
        console.log('================================================');
        console.log('  WHATSAPP CONNECTED!');
        console.log('================================================');
        
        isReady = true;
        isAuthenticated = true;
        qrCodeDataUrl = null;
        initError = null;
        clientInfo = clientInstance.info;
        
        if (clientInfo) {
            console.log(`Logged in as: ${clientInfo.pushname}`);
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
    clientInstance.on('auth_failure', (msg) => {
        console.error('[Auth] Authentication failed:', msg);
        isAuthenticated = false;
        isReady = false;
        initError = 'Authentication failed: ' + msg;
    });

    // Disconnected event
    clientInstance.on('disconnected', (reason) => {
        console.log('[Disconnect] WhatsApp disconnected:', reason);
        isReady = false;
        isAuthenticated = false;
        qrCodeDataUrl = null;
        clientInfo = null;
    });

    // Message received
    clientInstance.on('message', (msg) => {
        console.log(`[Message] From ${msg.from}: ${msg.body.substring(0, 50)}...`);
    });
}

async function initializeClient() {
    try {
        if (client) {
            try { await client.destroy(); } catch (e) {}
        }
        
        client = createClient();
        setupClientEvents(client);
        
        console.log('Initializing WhatsApp client...');
        console.log('This may take 30-60 seconds on first run...');
        console.log('');
        
        await client.initialize();
    } catch (err) {
        console.error('Failed to initialize WhatsApp client:', err.message);
        initError = err.message;
        
        console.log('');
        console.log('TROUBLESHOOTING:');
        console.log('1. Delete the .wwebjs_auth folder and restart');
        console.log('2. Make sure no other Chrome/WhatsApp instances are running');
        console.log('3. Try: npm uninstall puppeteer && npm install puppeteer');
        console.log('4. Restart your computer');
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
        error: initError,
        clientInfo: clientInfo ? {
            pushname: clientInfo.pushname,
            wid: clientInfo.wid?._serialized
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
    } else {
        res.json({ qrCode: null, message: 'Initializing... Please wait (30-60 seconds)' });
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
        const formattedPhone = phone.replace(/\D/g, '') + '@c.us';
        console.log(`[Send] Sending to ${formattedPhone}...`);
        
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
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/retry-init', async (req, res) => {
    console.log('[Retry] Manual retry requested...');
    initError = null;
    qrCodeDataUrl = null;
    res.json({ success: true, message: 'Reinitialization started' });
    initializeClient();
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// =============================================
// Start Server
// =============================================

const PORT = process.env.WA_PORT || 3001;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`WhatsApp service running on http://localhost:${PORT}`);
    console.log('');
    initializeClient();
});

process.on('SIGINT', async () => {
    console.log('\nShutting down...');
    if (client) {
        try { await client.destroy(); } catch (e) {}
    }
    process.exit(0);
});
