/**
 * MongoDB Session Store for WhatsApp
 * 
 * This provides PERSISTENT session storage that survives:
 * - Process restarts
 * - System reboots
 * - Unclean shutdowns
 * - Container restarts
 * 
 * Sessions are stored atomically in MongoDB, eliminating
 * filesystem lock issues and corruption from kill signals.
 */
const mongoose = require('mongoose');
const { MongoStore } = require('wwebjs-mongo');
const { log } = require('../../utils/logger');

let store = null;
let isConnected = false;

const MONGO_URL = process.env.MONGO_URL || 'mongodb://localhost:27017/wa_scheduler';

/**
 * Initialize MongoDB connection for session storage
 */
const initSessionStore = async () => {
  if (isConnected && store) {
    return store;
  }

  try {
    log('INFO', 'Connecting to MongoDB for session storage...');
    
    // Connect mongoose
    await mongoose.connect(MONGO_URL, {
      serverSelectionTimeoutMS: 5000,
      maxPoolSize: 5
    });

    // Create the store
    store = new MongoStore({ mongoose });
    isConnected = true;

    log('INFO', '✓ MongoDB session store initialized');
    log('INFO', `  Database: ${MONGO_URL.split('@').pop() || MONGO_URL}`);

    // Handle connection events
    mongoose.connection.on('disconnected', () => {
      log('WARN', 'MongoDB disconnected');
      isConnected = false;
    });

    mongoose.connection.on('reconnected', () => {
      log('INFO', 'MongoDB reconnected');
      isConnected = true;
    });

    return store;
  } catch (error) {
    log('ERROR', 'Failed to initialize MongoDB session store:', error.message);
    throw error;
  }
};

/**
 * Check if we have an existing session in MongoDB
 */
const hasExistingSession = async (clientId = 'wa-scheduler') => {
  try {
    if (!isConnected) {
      await initSessionStore();
    }

    // Check if session exists in MongoDB
    const Session = mongoose.connection.collection('whatsapp-sessions');
    const session = await Session.findOne({ session: clientId });
    
    if (session) {
      log('INFO', `Found existing session for ${clientId} in MongoDB`);
      return true;
    }
    
    log('INFO', `No existing session found for ${clientId}`);
    return false;
  } catch (error) {
    log('WARN', 'Error checking session:', error.message);
    return false;
  }
};

/**
 * Delete session from MongoDB (for logout/clear)
 */
const deleteSession = async (clientId = 'wa-scheduler') => {
  try {
    if (!isConnected) {
      await initSessionStore();
    }

    const Session = mongoose.connection.collection('whatsapp-sessions');
    const result = await Session.deleteMany({ session: clientId });
    
    log('INFO', `Deleted ${result.deletedCount} session entries for ${clientId}`);
    return { success: true, deleted: result.deletedCount };
  } catch (error) {
    log('ERROR', 'Error deleting session:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Get session info from MongoDB
 */
const getSessionInfo = async (clientId = 'wa-scheduler') => {
  try {
    if (!isConnected) {
      await initSessionStore();
    }

    const Session = mongoose.connection.collection('whatsapp-sessions');
    const sessions = await Session.find({ session: clientId }).toArray();
    
    return {
      exists: sessions.length > 0,
      entries: sessions.length,
      clientId
    };
  } catch (error) {
    return { exists: false, error: error.message };
  }
};

/**
 * Close MongoDB connection
 */
const closeStore = async () => {
  if (mongoose.connection.readyState === 1) {
    await mongoose.connection.close();
    isConnected = false;
    store = null;
    log('INFO', 'MongoDB connection closed');
  }
};

module.exports = {
  initSessionStore,
  hasExistingSession,
  deleteSession,
  getSessionInfo,
  closeStore,
  getStore: () => store,
  isConnected: () => isConnected
};
