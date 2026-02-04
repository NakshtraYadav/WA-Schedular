/**
 * Session management
 */
const fs = require('fs');
const path = require('path');
const { log } = require('../../utils/logger');
const { SESSION_PATH } = require('../../config/env');

const clearSession = async () => {
  try {
    const sessionPath = path.resolve(SESSION_PATH);
    
    if (fs.existsSync(sessionPath)) {
      fs.rmSync(sessionPath, { recursive: true, force: true });
      log('INFO', 'Session cleared successfully');
      return { success: true, message: 'Session cleared' };
    }
    
    return { success: true, message: 'No session to clear' };
  } catch (error) {
    log('ERROR', 'Clear session error:', error.message);
    return { success: false, error: error.message };
  }
};

module.exports = {
  clearSession
};
