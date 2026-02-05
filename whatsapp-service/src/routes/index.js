/**
 * Routes module - Aggregates all routes
 */
const express = require('express');
const router = express.Router();

const statusRoutes = require('./status.routes');
const messageRoutes = require('./message.routes');
const contactsRoutes = require('./contacts.routes');
const sessionRoutes = require('./session.routes');
const observabilityRoutes = require('./observability.routes');

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'whatsapp-service' });
});

// Root route - service info
router.get('/', (req, res) => {
  const { getState } = require('../services/whatsapp/client');
  const state = getState();
  
  res.json({
    service: 'WhatsApp Service',
    version: '3.2.0',
    status: state.isReady ? 'connected' : 'disconnected',
    endpoints: {
      health: 'GET /health',
      status: 'GET /status',
      qr: 'GET /qr',
      send: 'POST /send',
      contacts: 'GET /contacts',
      generateQr: 'POST /generate-qr',
      logout: 'POST /logout',
      clearSession: 'POST /clear-session',
      // Observability endpoints
      sessionHealth: 'GET /session/health',
      sessionObserve: 'GET /session/observe',
      sessionAlerts: 'GET /session/alerts',
      sessionMetrics: 'GET /session/metrics'
    }
  });
});

// Mount routes
router.use('/', statusRoutes);
router.use('/', messageRoutes);
router.use('/', contactsRoutes);
router.use('/', sessionRoutes);
router.use('/session', observabilityRoutes);

module.exports = router;
