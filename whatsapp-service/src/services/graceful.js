/**
 * Graceful Shutdown Coordinator for WhatsApp Service
 * 
 * Ensures clean shutdown that:
 * - Saves WhatsApp session to MongoDB
 * - Releases distributed locks
 * - Completes in-flight operations
 * - Prevents reconnect storms on restart
 * 
 * Integrates with PM2 for zero-downtime restarts
 */

const { log } = require('../utils/logger');

// Shutdown state
let isShuttingDown = false;
let shutdownPromise = null;
let activeOperations = new Set();
let shutdownCallbacks = [];

// Timeouts
const SHUTDOWN_TIMEOUT_MS = 25000;  // 25s (PM2 gives us 30s)
const OPERATION_WAIT_MS = 10000;    // Max 10s waiting for operations
const SESSION_SAVE_MS = 10000;      // Max 10s for session save

/**
 * Register a callback to run during shutdown
 */
const onShutdown = (name, callback) => {
  shutdownCallbacks.push({ name, callback });
  log('INFO', `[GRACEFUL] Registered shutdown callback: ${name}`);
};

/**
 * Track an in-flight operation
 * Returns a completion function to call when done
 */
const trackOperation = (operationId) => {
  if (isShuttingDown) {
    throw new Error('Service is shutting down, rejecting new operation');
  }
  
  activeOperations.add(operationId);
  
  return () => {
    activeOperations.delete(operationId);
  };
};

/**
 * Check if new operations should be accepted
 */
const isAcceptingOperations = () => !isShuttingDown;

/**
 * Get count of active operations
 */
const getActiveOperationCount = () => activeOperations.size;

/**
 * Wait for all active operations to complete
 */
const waitForOperations = async () => {
  const startTime = Date.now();
  
  while (activeOperations.size > 0) {
    if (Date.now() - startTime > OPERATION_WAIT_MS) {
      log('WARN', `[GRACEFUL] Timeout waiting for ${activeOperations.size} operations`);
      log('WARN', `[GRACEFUL] Abandoning operations: ${[...activeOperations].join(', ')}`);
      break;
    }
    
    log('INFO', `[GRACEFUL] Waiting for ${activeOperations.size} operations...`);
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  if (activeOperations.size === 0) {
    log('INFO', '[GRACEFUL] All operations completed');
  }
};

/**
 * Execute all shutdown callbacks in order
 */
const executeCallbacks = async () => {
  for (const { name, callback } of shutdownCallbacks) {
    try {
      log('INFO', `[GRACEFUL] Running callback: ${name}`);
      const result = await Promise.race([
        callback(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Callback timeout')), 5000)
        )
      ]);
      log('INFO', `[GRACEFUL] Callback complete: ${name}`);
    } catch (error) {
      log('WARN', `[GRACEFUL] Callback failed: ${name} - ${error.message}`);
    }
  }
};

/**
 * Main graceful shutdown handler
 */
const gracefulShutdown = async (signal) => {
  if (isShuttingDown) {
    log('INFO', `[GRACEFUL] Shutdown already in progress (signal: ${signal})`);
    return shutdownPromise;
  }
  
  isShuttingDown = true;
  log('INFO', `[GRACEFUL] ========================================`);
  log('INFO', `[GRACEFUL] GRACEFUL SHUTDOWN INITIATED (${signal})`);
  log('INFO', `[GRACEFUL] ========================================`);
  
  shutdownPromise = (async () => {
    const shutdownStart = Date.now();
    
    try {
      // PHASE 1: Stop accepting new work
      log('INFO', '[GRACEFUL] Phase 1: Stop accepting new operations');
      // isShuttingDown flag already set
      
      // PHASE 2: Wait for in-flight operations
      log('INFO', `[GRACEFUL] Phase 2: Waiting for ${activeOperations.size} active operations`);
      await waitForOperations();
      
      // PHASE 3: Execute shutdown callbacks (session save, lock release, etc.)
      log('INFO', '[GRACEFUL] Phase 3: Running shutdown callbacks');
      await executeCallbacks();
      
      // PHASE 4: Final cleanup
      log('INFO', '[GRACEFUL] Phase 4: Final cleanup');
      
      const shutdownDuration = Date.now() - shutdownStart;
      log('INFO', `[GRACEFUL] ========================================`);
      log('INFO', `[GRACEFUL] SHUTDOWN COMPLETE (${shutdownDuration}ms)`);
      log('INFO', `[GRACEFUL] ========================================`);
      
      // Tell PM2 we're ready to die
      if (process.send) {
        process.send('shutdown');
      }
      
      // Exit cleanly
      setTimeout(() => {
        process.exit(0);
      }, 500);
      
    } catch (error) {
      log('ERROR', `[GRACEFUL] Shutdown error: ${error.message}`);
      process.exit(1);
    }
  })();
  
  return shutdownPromise;
};

/**
 * Install signal handlers
 */
const installShutdownHandlers = () => {
  // Graceful signals
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  
  // PM2 shutdown message
  process.on('message', (msg) => {
    if (msg === 'shutdown') {
      gracefulShutdown('PM2_SHUTDOWN');
    }
  });
  
  // Tell PM2 we're ready (after initialization)
  const signalReady = () => {
    if (process.send) {
      process.send('ready');
      log('INFO', '[GRACEFUL] Sent ready signal to PM2');
    }
  };
  
  log('INFO', '[GRACEFUL] Shutdown handlers installed');
  
  return { signalReady };
};

/**
 * Create shutdown coordinator for a specific component
 */
const createShutdownCoordinator = () => {
  return {
    onShutdown,
    trackOperation,
    isAcceptingOperations,
    getActiveOperationCount,
    isShuttingDown: () => isShuttingDown,
    installShutdownHandlers,
    gracefulShutdown
  };
};

module.exports = createShutdownCoordinator();
