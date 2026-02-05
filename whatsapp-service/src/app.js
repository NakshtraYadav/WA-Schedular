/**
 * Express application setup
 */
const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./middleware/errorHandler');
const routes = require('./routes');
const { log } = require('./utils/logger');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/', routes);

// Error handler
app.use(errorHandler);

// Don't auto-initialize WhatsApp - wait for user to request QR code
// This ensures QR is fresh when user is ready to scan
log('INFO', 'WhatsApp service ready - QR will be generated on demand');

module.exports = app;
