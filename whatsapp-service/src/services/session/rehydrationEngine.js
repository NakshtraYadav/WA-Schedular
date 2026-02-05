/**
 * Session Rehydration Engine
 * 
 * On service boot:
 * 1. Load all sessions from MongoDB
 * 2. Validate credentials
 * 3. Attempt reconnect with exponential backoff
 * 4. Prevent reconnect storms (circuit breaker)
 * 5. Log structured reconnect events
 * 
 * GUARANTEES:
 * - User NEVER scans QR again unless credentials truly invalid
 * - No reconnect storms on service restart
 * - Graceful handling of multiple service instances
 */

const { log } = require('../../utils/logger');
const {
  initDurableStore,
  loadSession,
  hasValidSession,
  updateConnectionStatus,
  recordReconnectAttempt,
  acquireReconnectLock,
  releaseReconnectLock,
  getSessionsForReconnect,
  updateSessionStatus,
  logSessionEvent,
  isStoreReady
} = require('./durableStore');

// Reconnect configuration - tuned for stability
const RECONNECT_CONFIG = {
  initialDelayMs: 3000,       // Wait 3s after boot before reconnects
  maxConcurrent: 1,           // For single-user, only 1 at a time
  staggerDelayMs: 2000,       // 2s between starting reconnects
  maxAttempts: 10,            // Give up after 10 failures
  circuitBreakerThreshold: 3, // Pause all reconnects if 3 fail in a row
  circuitBreakerResetMs: 60000 // Reset circuit breaker after 60s
};

// State
let reconnectQueue = [];
let activeReconnects = 0;
let consecutiveFailures = 0;
let circuitBreakerOpen = false;
let clientInitializerFn = null;
let isEngineRunning = false;

/**
 * Initialize rehydration engine on boot
 * @param {string} mongoUrl - MongoDB connection URL
 * @param {function} clientInitializer - Function to initialize WhatsApp client
 */
const initRehydrationEngine = async (mongoUrl, clientInitializer) => {
  if (isEngineRunning) {
    log('INFO', 'Rehydration engine already running');
    return { status: 'already_running' };
  }
  
  log('INFO', '=== Session Rehydration Engine Starting ===');
  clientInitializerFn = clientInitializer;
  
  try {
    // Step 1: Initialize durable store
    await initDurableStore(mongoUrl);
    
    // Step 2: Wait for services to stabilize
    log('INFO', `Waiting ${RECONNECT_CONFIG.initialDelayMs}ms for services to stabilize...`);
    await new Promise(resolve => setTimeout(resolve, RECONNECT_CONFIG.initialDelayMs));
    
    // Step 3: Find sessions needing reconnect
    const sessions = await getSessionsForReconnect();
    
    if (sessions.length === 0) {
      log('INFO', '✓ No sessions require reconnection');
      isEngineRunning = true;
      return { status: 'ready', reconnected: 0, queued: 0 };
    }
    
    log('INFO', `Found ${sessions.length} session(s) to reconnect`);
    
    // Step 4: Queue reconnects
    for (const session of sessions) {
      await queueReconnect(session.account_id);
    }
    
    // Step 5: Start processing queue
    isEngineRunning = true;
    processReconnectQueue();
    
    return { status: 'processing', queued: sessions.length };
    
  } catch (error) {
    log('ERROR', `Rehydration engine failed: ${error.message}`);
    return { status: 'error', error: error.message };
  }
};

/**
 * Queue a session for reconnection
 */
const queueReconnect = async (accountId) => {
  // Check if already in queue
  if (reconnectQueue.some(item => item.accountId === accountId)) {
    log('INFO', `${accountId} already in reconnect queue`);
    return false;
  }
  
  // Validate session first
  const isValid = await hasValidSession(accountId);
  
  if (!isValid) {
    log('WARN', `Session ${accountId} is invalid/corrupt, requires QR scan`);
    await updateSessionStatus(accountId, 'qr_required');
    return false;
  }
  
  reconnectQueue.push({
    accountId,
    queuedAt: Date.now()
  });
  
  log('INFO', `Queued reconnect for: ${accountId} (queue size: ${reconnectQueue.length})`);
  return true;
};

/**
 * Process reconnect queue with concurrency control
 */
const processReconnectQueue = async () => {
  // Check circuit breaker
  if (circuitBreakerOpen) {
    log('WARN', `Circuit breaker OPEN - pausing reconnects for ${RECONNECT_CONFIG.circuitBreakerResetMs / 1000}s`);
    setTimeout(() => {
      circuitBreakerOpen = false;
      consecutiveFailures = 0;
      log('INFO', 'Circuit breaker reset - resuming reconnects');
      processReconnectQueue();
    }, RECONNECT_CONFIG.circuitBreakerResetMs);
    return;
  }
  
  // Check if we can process more
  if (reconnectQueue.length === 0) {
    log('INFO', 'Reconnect queue empty');
    return;
  }
  
  if (activeReconnects >= RECONNECT_CONFIG.maxConcurrent) {
    log('INFO', `Max concurrent reconnects (${RECONNECT_CONFIG.maxConcurrent}) reached, waiting...`);
    return;
  }
  
  // Get next item
  const item = reconnectQueue.shift();
  if (!item) return;
  
  activeReconnects++;
  
  // Execute with staggering for next
  executeReconnect(item).finally(() => {
    activeReconnects--;
    
    // Schedule next after stagger delay
    if (reconnectQueue.length > 0) {
      setTimeout(processReconnectQueue, RECONNECT_CONFIG.staggerDelayMs);
    }
  });
};

/**
 * Execute single reconnect attempt
 */
const executeReconnect = async (item) => {
  const { accountId } = item;
  
  try {
    // Try to acquire distributed lock
    const gotLock = await acquireReconnectLock(accountId, 180); // 3 min lock
    
    if (!gotLock) {
      log('INFO', `Skipping ${accountId} - another worker is handling it`);
      return { success: false, reason: 'locked' };
    }
    
    // Record attempt and get backoff info
    const attemptInfo = await recordReconnectAttempt(accountId);
    
    if (!attemptInfo || attemptInfo.attempts > RECONNECT_CONFIG.maxAttempts) {
      log('WARN', `Max reconnect attempts (${RECONNECT_CONFIG.maxAttempts}) reached for ${accountId}`);
      await updateSessionStatus(accountId, 'max_retries');
      await releaseReconnectLock(accountId);
      return { success: false, reason: 'max_attempts' };
    }
    
    log('INFO', `🔄 Reconnecting ${accountId} (attempt ${attemptInfo.attempts}/${RECONNECT_CONFIG.maxAttempts})...`);
    
    // Load session data
    const session = await loadSession(accountId);
    
    if (!session) {
      log('ERROR', `Cannot load session for ${accountId}`);
      await releaseReconnectLock(accountId);
      return { success: false, reason: 'no_session' };
    }
    
    if (session._corrupt) {
      log('ERROR', `Session ${accountId} is corrupt`);
      await updateSessionStatus(accountId, 'corrupt');
      await releaseReconnectLock(accountId);
      return { success: false, reason: 'corrupt' };
    }
    
    // Initialize client with session (calls the provided initializer)
    if (!clientInitializerFn) {
      log('ERROR', 'No client initializer function set');
      await releaseReconnectLock(accountId);
      return { success: false, reason: 'no_initializer' };
    }
    
    const result = await clientInitializerFn(accountId, session);
    
    if (result && result.success) {
      log('INFO', `✅ Successfully reconnected: ${accountId}`);
      await updateConnectionStatus(accountId, 'connected');
      consecutiveFailures = 0;
      await releaseReconnectLock(accountId);
      return { success: true };
    }
    
    // Handle failure
    log('WARN', `Reconnect failed for ${accountId}: ${result?.error || 'unknown'}`);
    consecutiveFailures++;
    
    // Check circuit breaker threshold
    if (consecutiveFailures >= RECONNECT_CONFIG.circuitBreakerThreshold) {
      circuitBreakerOpen = true;
      log('WARN', `🔴 Circuit breaker TRIGGERED - ${consecutiveFailures} consecutive failures`);
      await logSessionEvent(accountId, 'circuit_breaker_triggered', {
        consecutive_failures: consecutiveFailures
      });
    }
    
    await releaseReconnectLock(accountId);
    
    // Re-queue with backoff delay
    const reQueueDelay = attemptInfo.nextBackoff * 1000;
    log('INFO', `Re-queueing ${accountId} in ${attemptInfo.nextBackoff}s`);
    
    setTimeout(() => {
      if (!circuitBreakerOpen) {
        queueReconnect(accountId);
        processReconnectQueue();
      }
    }, reQueueDelay);
    
    return { success: false, reason: result?.error || 'failed', nextAttemptIn: attemptInfo.nextBackoff };
    
  } catch (error) {
    log('ERROR', `Reconnect error for ${accountId}: ${error.message}`);
    consecutiveFailures++;
    await releaseReconnectLock(accountId);
    return { success: false, reason: error.message };
  }
};

/**
 * Handle new disconnection event
 */
const handleDisconnection = async (accountId, reason) => {
  log('INFO', `Handling disconnection for ${accountId}: ${reason}`);
  
  await updateConnectionStatus(accountId, 'disconnected', reason);
  await logSessionEvent(accountId, 'disconnected', { reason });
  
  // Don't reconnect for intentional logout or conflicts
  const noReconnectReasons = ['LOGOUT', 'CONFLICT', 'NAVIGATION', 'BANNED'];
  if (noReconnectReasons.includes(reason)) {
    log('INFO', `Not reconnecting ${accountId} - reason: ${reason}`);
    if (reason === 'BANNED') {
      await updateSessionStatus(accountId, 'corrupt');
    }
    return;
  }
  
  // Queue for reconnect
  await queueReconnect(accountId);
  processReconnectQueue();
};

/**
 * Handle successful authentication (after QR scan or session restore)
 */
const handleAuthenticated = async (accountId, sessionData = null) => {
  log('INFO', `Session authenticated: ${accountId}`);
  
  await updateConnectionStatus(accountId, 'connected');
  await logSessionEvent(accountId, 'authenticated', {
    has_session_data: !!sessionData
  });
  
  // Reset failure counters
  consecutiveFailures = 0;
};

/**
 * Get reconnect status
 */
const getReconnectStatus = () => ({
  engineRunning: isEngineRunning,
  queueLength: reconnectQueue.length,
  activeReconnects,
  consecutiveFailures,
  circuitBreakerOpen,
  config: RECONNECT_CONFIG
});

/**
 * Force trigger reconnect for an account
 */
const triggerReconnect = async (accountId) => {
  if (!isStoreReady()) {
    log('WARN', 'Cannot trigger reconnect - store not ready');
    return { success: false, reason: 'store_not_ready' };
  }
  
  const queued = await queueReconnect(accountId);
  if (queued) {
    processReconnectQueue();
    return { success: true, message: 'Queued for reconnect' };
  }
  
  return { success: false, reason: 'Could not queue' };
};

/**
 * Reset circuit breaker (manual override)
 */
const resetCircuitBreaker = () => {
  circuitBreakerOpen = false;
  consecutiveFailures = 0;
  log('INFO', 'Circuit breaker manually reset');
  processReconnectQueue();
};

module.exports = {
  initRehydrationEngine,
  queueReconnect,
  handleDisconnection,
  handleAuthenticated,
  getReconnectStatus,
  triggerReconnect,
  resetCircuitBreaker
};
