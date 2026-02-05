/**
 * Express application setup
 */
const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./middleware/errorHandler');
const routes = require('./routes');
const { initWhatsApp } = require('./services/whatsapp/client');
const { log } = require('./utils/logger');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/', routes);

// Error handler
app.use(errorHandler);

// Initialize WhatsApp client with delay to ensure services are ready
// This helps avoid race conditions on first start
setTimeout(() => {
  log('INFO', 'Starting WhatsApp initialization (delayed start for stability)...');
  initWhatsApp();
}, 3000);

module.exports = app;
