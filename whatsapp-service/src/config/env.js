/**
 * Environment configuration
 * 
 * CRITICAL: SESSION_PATH must be an ABSOLUTE path on persistent storage.
 * Relative paths cause session loss on restart due to CWD changes.
 */
const path = require('path');

const PORT = process.env.WA_PORT || 3001;

// Get project root directory (whatsapp-service is inside project root)
const PROJECT_ROOT = path.resolve(__dirname, '..', '..', '..');

// Session path - use project's data folder (not system /app which needs root)
const DEFAULT_SESSION_PATH = path.join(PROJECT_ROOT, 'data', 'whatsapp-sessions');
const SESSION_PATH = process.env.SESSION_PATH || DEFAULT_SESSION_PATH;

// Validate session path is absolute
if (!path.isAbsolute(SESSION_PATH)) {
  console.error('FATAL: SESSION_PATH must be absolute! Got:', SESSION_PATH);
  process.exit(1);
}

module.exports = {
  PORT,
  SESSION_PATH
};
