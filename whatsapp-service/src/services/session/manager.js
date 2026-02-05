/**
 * Session management - Production-grade session handling
 */
const fs = require('fs');
const path = require('path');
const { log } = require('../../utils/logger');
const { SESSION_PATH } = require('../../config/env');

const SESSION_CLIENT_ID = 'wa-scheduler';

/**
 * Get session info without clearing
 */
const getSessionInfo = () => {
  const sessionDir = path.join(SESSION_PATH, `session-${SESSION_CLIENT_ID}`);
  
  if (!fs.existsSync(sessionDir)) {
    return { exists: false, path: sessionDir };
  }

  try {
    const stats = fs.statSync(sessionDir);
    const files = fs.readdirSync(sessionDir, { recursive: true });
    
    return {
      exists: true,
      path: sessionDir,
      created: stats.birthtime,
      modified: stats.mtime,
      fileCount: files.length
    };
  } catch (error) {
    return { exists: false, error: error.message };
  }
};

/**
 * Backup session before clearing
 */
const backupSession = async () => {
  const sessionDir = path.join(SESSION_PATH, `session-${SESSION_CLIENT_ID}`);
  const backupDir = path.join(SESSION_PATH, `backup-${SESSION_CLIENT_ID}-${Date.now()}`);
  
  if (!fs.existsSync(sessionDir)) {
    return { success: false, message: 'No session to backup' };
  }

  try {
    fs.cpSync(sessionDir, backupDir, { recursive: true });
    log('INFO', `Session backed up to: ${backupDir}`);
    return { success: true, backupPath: backupDir };
  } catch (error) {
    log('ERROR', 'Backup failed:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Clear session with optional backup
 */
const clearSession = async (createBackup = true) => {
  try {
    const sessionDir = path.join(SESSION_PATH, `session-${SESSION_CLIENT_ID}`);
    
    if (!fs.existsSync(sessionDir)) {
      return { success: true, message: 'No session to clear' };
    }

    // Create backup first
    if (createBackup) {
      const backupResult = await backupSession();
      if (!backupResult.success) {
        log('WARN', 'Could not create backup, proceeding with clear anyway');
      }
    }

    // Clear session
    fs.rmSync(sessionDir, { recursive: true, force: true });
    log('INFO', 'Session cleared successfully');
    
    // Also clear cache
    const cacheDir = path.join(SESSION_PATH, '.wwebjs_cache');
    if (fs.existsSync(cacheDir)) {
      fs.rmSync(cacheDir, { recursive: true, force: true });
      log('INFO', 'Cache cleared');
    }
    
    return { success: true, message: 'Session cleared' };
  } catch (error) {
    log('ERROR', 'Clear session error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Clean up old backups (keep last 3)
 */
const cleanupOldBackups = () => {
  try {
    const backups = fs.readdirSync(SESSION_PATH)
      .filter(f => f.startsWith(`backup-${SESSION_CLIENT_ID}-`))
      .map(f => ({
        name: f,
        path: path.join(SESSION_PATH, f),
        time: parseInt(f.split('-').pop())
      }))
      .sort((a, b) => b.time - a.time);

    // Keep last 3 backups
    const toDelete = backups.slice(3);
    
    for (const backup of toDelete) {
      fs.rmSync(backup.path, { recursive: true, force: true });
      log('INFO', `Cleaned up old backup: ${backup.name}`);
    }

    return { deleted: toDelete.length };
  } catch (error) {
    log('WARN', 'Backup cleanup error:', error.message);
    return { deleted: 0, error: error.message };
  }
};

module.exports = {
  clearSession,
  getSessionInfo,
  backupSession,
  cleanupOldBackups
};
