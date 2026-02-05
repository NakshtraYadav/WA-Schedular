/**
 * Environment configuration
 * 
 * CRITICAL: SESSION_PATH must be an ABSOLUTE path on persistent storage.
 * Relative paths cause session loss on restart due to CWD changes.
 */
const path = require('path');

const PORT = process.env.WA_PORT || 3001;

// ALWAYS use absolute path for session persistence
// This survives: server restart, container restart, system reboot
const SESSION_PATH = process.env.SESSION_PATH || '/app/data/whatsapp-sessions';

// Validate session path is absolute
if (!path.isAbsolute(SESSION_PATH)) {
  console.error('FATAL: SESSION_PATH must be absolute! Got:', SESSION_PATH);
  process.exit(1);
}

module.exports = {
  PORT,
  SESSION_PATH
};
