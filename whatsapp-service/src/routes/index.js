/**
 * Routes module - Aggregates all routes
 */
const express = require('express');
const router = express.Router();

const statusRoutes = require('./status.routes');
const messageRoutes = require('./message.routes');
const contactsRoutes = require('./contacts.routes');
const sessionRoutes = require('./session.routes');

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'whatsapp-service' });
});

// Mount routes
router.use('/', statusRoutes);
router.use('/', messageRoutes);
router.use('/', contactsRoutes);
router.use('/', sessionRoutes);

module.exports = router;
