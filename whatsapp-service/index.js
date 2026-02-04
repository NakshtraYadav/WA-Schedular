/**
 * WhatsApp Service - Entry Point
 * Modular Express application for WhatsApp Web.js integration
 */
const app = require('./src/app');
const { log } = require('./src/utils/logger');
const { PORT } = require('./src/config/env');

const port = PORT || 3001;

app.listen(port, () => {
  log('INFO', `WhatsApp Service running on port ${port}`);
});

// Global error handlers
process.on('uncaughtException', (err) => {
  log('ERROR', 'Uncaught exception:', err);
});

process.on('unhandledRejection', (reason) => {
  log('ERROR', 'Unhandled rejection:', reason);
});
