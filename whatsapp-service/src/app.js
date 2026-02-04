/**
 * Express application setup
 */
const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./middleware/errorHandler');
const routes = require('./routes');
const { initWhatsApp } = require('./services/whatsapp/client');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/', routes);

// Error handler
app.use(errorHandler);

// Initialize WhatsApp client
initWhatsApp();

module.exports = app;
