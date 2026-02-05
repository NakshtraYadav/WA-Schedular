/**
 * Session Observability - Operator-Grade Health Monitoring
 * 
 * DESIGN PRINCIPLES:
 * - Cheap queries (in-memory state + single indexed lookups)
 * - Dashboard-ready structured JSON
 * - Alert thresholds for automated monitoring
 * - Sub-10ms response time target
 * 
 * METRICS EXPOSED:
 * - Session state machine position
 * - Reconnect attempt tracking
 * - Heartbeat freshness
 * - Auth credential age
 * - Distributed lock status
 * - Corruption detection flags
 * - Latency percentiles
 */

const { log } = require('../../utils/logger');

// In-memory metrics (cheap reads, no DB queries)
const metrics = {
  // Session state
  currentState: 'disconnected',  // connected | disconnected | reconnecting | qr_required | circuit_open
  stateChangedAt: null,
  
  // Reconnect tracking
  reconnectAttempts: 0,
  reconnectStartedAt: null,
  lastReconnectDuration: null,
  reconnectLatencies: [],  // Last 10 latencies for percentile calc
  
  // Heartbeat (WhatsApp ping)
  lastHeartbeatAt: null,
  heartbeatCount: 0,
  missedHeartbeats: 0,
  
  // Auth freshness
  lastAuthAt: null,
  lastCredentialWriteAt: null,
  authMethod: null,  // 'qr_scan' | 'session_restore'
  
  // Lock status
  lockHeldBy: null,
  lockAcquiredAt: null,
  lockOperation: null,
  
  // Corruption tracking
  checksumValid: true,
  lastValidationAt: null,
  corruptionDetectedAt: null,
  validationFailures: 0,
  
  // Circuit breaker
  circuitBreakerOpen: false,
  circuitBreakerTrippedAt: null,
  consecutiveFailures: 0,
  
  // Startup tracking
  serviceStartedAt: Date.now(),
  lastInitAttemptAt: null,
  initSuccessful: false
};

// Alert thresholds (configurable)
const ALERT_THRESHOLDS = {
  // WARNING thresholds
  warning: {
    heartbeatStaleSeconds: 60,        // No heartbeat for 60s
    reconnectAttempts: 3,             // 3+ reconnect attempts
    credentialAgeHours: 24,           // Credentials older than 24h
    reconnectLatencyMs: 30000,        // Reconnect taking >30s
    missedHeartbeats: 3,              // 3 missed heartbeats
    validationFailures: 1             // Any validation failure
  },
  
  // CRITICAL thresholds
  critical: {
    heartbeatStaleSeconds: 300,       // No heartbeat for 5 min
    reconnectAttempts: 7,             // 7+ attempts (near max)
    credentialAgeHours: 168,          // Credentials older than 7 days
    reconnectLatencyMs: 120000,       // Reconnect taking >2 min
    missedHeartbeats: 10,             // 10 missed heartbeats
    circuitBreakerOpen: true,         // Circuit breaker tripped
    corruptionDetected: true,         // Any corruption
    disconnectedMinutes: 30           // Disconnected for 30+ min
  }
};

/**
 * Update session state (call from client events)
 */
const updateState = (newState, metadata = {}) => {
  const now = Date.now();
  const previousState = metrics.currentState;
  
  metrics.currentState = newState;
  metrics.stateChangedAt = now;
  
  // Track state-specific metrics
  if (newState === 'connected') {
    metrics.initSuccessful = true;
    metrics.reconnectAttempts = 0;
    metrics.consecutiveFailures = 0;
    
    // Record reconnect latency if we were reconnecting
    if (previousState === 'reconnecting' && metrics.reconnectStartedAt) {
      const latency = now - metrics.reconnectStartedAt;
      metrics.lastReconnectDuration = latency;
      recordLatency(latency);
    }
    metrics.reconnectStartedAt = null;
  }
  
  if (newState === 'reconnecting') {
    if (previousState !== 'reconnecting') {
      metrics.reconnectStartedAt = now;
    }
    metrics.reconnectAttempts++;
  }
  
  if (newState === 'circuit_open') {
    metrics.circuitBreakerOpen = true;
    metrics.circuitBreakerTrippedAt = now;
  }
  
  if (newState === 'disconnected') {
    metrics.consecutiveFailures++;
  }
  
  if (metadata.authMethod) {
    metrics.authMethod = metadata.authMethod;
    metrics.lastAuthAt = now;
  }
  
  log('INFO', `[OBSERVABILITY] State: ${previousState} → ${newState}`);
};

/**
 * Record heartbeat (call on WhatsApp ping/pong)
 */
const recordHeartbeat = () => {
  const now = Date.now();
  
  // Check for missed heartbeats (expected every 30s)
  if (metrics.lastHeartbeatAt) {
    const gap = now - metrics.lastHeartbeatAt;
    if (gap > 45000) {  // >45s means we missed one
      metrics.missedHeartbeats++;
    }
  }
  
  metrics.lastHeartbeatAt = now;
  metrics.heartbeatCount++;
};

/**
 * Record credential write (call when session saved to MongoDB)
 */
const recordCredentialWrite = () => {
  metrics.lastCredentialWriteAt = Date.now();
};

/**
 * Record validation result
 */
const recordValidation = (isValid) => {
  metrics.lastValidationAt = Date.now();
  metrics.checksumValid = isValid;
  
  if (!isValid) {
    metrics.validationFailures++;
    metrics.corruptionDetectedAt = Date.now();
  }
};

/**
 * Update lock status
 */
const updateLockStatus = (lockInfo) => {
  if (lockInfo) {
    metrics.lockHeldBy = lockInfo.heldBy;
    metrics.lockAcquiredAt = lockInfo.acquiredAt;
    metrics.lockOperation = lockInfo.operation;
  } else {
    metrics.lockHeldBy = null;
    metrics.lockAcquiredAt = null;
    metrics.lockOperation = null;
  }
};

/**
 * Record reconnect latency for percentile calculation
 */
const recordLatency = (latencyMs) => {
  metrics.reconnectLatencies.push(latencyMs);
  // Keep only last 10 for memory efficiency
  if (metrics.reconnectLatencies.length > 10) {
    metrics.reconnectLatencies.shift();
  }
};

/**
 * Calculate latency percentiles
 */
const calculatePercentiles = () => {
  const latencies = [...metrics.reconnectLatencies].sort((a, b) => a - b);
  const len = latencies.length;
  
  if (len === 0) {
    return { p50: null, p90: null, p99: null };
  }
  
  return {
    p50: latencies[Math.floor(len * 0.5)] || null,
    p90: latencies[Math.floor(len * 0.9)] || null,
    p99: latencies[Math.floor(len * 0.99)] || null
  };
};

/**
 * Evaluate alert conditions
 * Returns: { level: 'ok' | 'warning' | 'critical', alerts: [...] }
 */
const evaluateAlerts = () => {
  const now = Date.now();
  const alerts = [];
  let level = 'ok';
  
  const setLevel = (newLevel) => {
    if (newLevel === 'critical') level = 'critical';
    else if (newLevel === 'warning' && level !== 'critical') level = 'warning';
  };
  
  // --- CRITICAL CHECKS ---
  
  // Circuit breaker open
  if (metrics.circuitBreakerOpen) {
    alerts.push({
      level: 'critical',
      code: 'CIRCUIT_BREAKER_OPEN',
      message: 'Circuit breaker is open - reconnection halted',
      trippedAt: metrics.circuitBreakerTrippedAt,
      action: 'Check WhatsApp service logs, may need manual intervention'
    });
    setLevel('critical');
  }
  
  // Corruption detected
  if (!metrics.checksumValid && metrics.corruptionDetectedAt) {
    alerts.push({
      level: 'critical',
      code: 'SESSION_CORRUPTION',
      message: 'Session data corruption detected',
      detectedAt: metrics.corruptionDetectedAt,
      action: 'Session may need to be cleared and QR rescanned'
    });
    setLevel('critical');
  }
  
  // Long disconnection
  if (metrics.currentState === 'disconnected' && metrics.stateChangedAt) {
    const disconnectedMinutes = (now - metrics.stateChangedAt) / 60000;
    if (disconnectedMinutes >= ALERT_THRESHOLDS.critical.disconnectedMinutes) {
      alerts.push({
        level: 'critical',
        code: 'LONG_DISCONNECTION',
        message: `Disconnected for ${Math.round(disconnectedMinutes)} minutes`,
        disconnectedAt: metrics.stateChangedAt,
        action: 'Check network connectivity and WhatsApp service status'
      });
      setLevel('critical');
    }
  }
  
  // Too many reconnect attempts
  if (metrics.reconnectAttempts >= ALERT_THRESHOLDS.critical.reconnectAttempts) {
    alerts.push({
      level: 'critical',
      code: 'EXCESSIVE_RECONNECTS',
      message: `${metrics.reconnectAttempts} reconnect attempts (max: 10)`,
      action: 'Near automatic failure threshold, investigate root cause'
    });
    setLevel('critical');
  }
  
  // Heartbeat stale (critical)
  if (metrics.lastHeartbeatAt) {
    const heartbeatAge = (now - metrics.lastHeartbeatAt) / 1000;
    if (heartbeatAge >= ALERT_THRESHOLDS.critical.heartbeatStaleSeconds) {
      alerts.push({
        level: 'critical',
        code: 'HEARTBEAT_DEAD',
        message: `No heartbeat for ${Math.round(heartbeatAge)}s`,
        lastHeartbeat: metrics.lastHeartbeatAt,
        action: 'WhatsApp connection likely dead, check browser process'
      });
      setLevel('critical');
    }
  }
  
  // --- WARNING CHECKS ---
  
  // Reconnect attempts warning
  if (metrics.reconnectAttempts >= ALERT_THRESHOLDS.warning.reconnectAttempts && 
      metrics.reconnectAttempts < ALERT_THRESHOLDS.critical.reconnectAttempts) {
    alerts.push({
      level: 'warning',
      code: 'RECONNECT_ATTEMPTS',
      message: `${metrics.reconnectAttempts} reconnect attempts`,
      action: 'Monitor closely, may escalate to critical'
    });
    setLevel('warning');
  }
  
  // Heartbeat stale (warning)
  if (metrics.lastHeartbeatAt) {
    const heartbeatAge = (now - metrics.lastHeartbeatAt) / 1000;
    if (heartbeatAge >= ALERT_THRESHOLDS.warning.heartbeatStaleSeconds &&
        heartbeatAge < ALERT_THRESHOLDS.critical.heartbeatStaleSeconds) {
      alerts.push({
        level: 'warning',
        code: 'HEARTBEAT_STALE',
        message: `No heartbeat for ${Math.round(heartbeatAge)}s`,
        action: 'Connection may be degraded'
      });
      setLevel('warning');
    }
  }
  
  // Credential age warning
  if (metrics.lastCredentialWriteAt) {
    const credentialAgeHours = (now - metrics.lastCredentialWriteAt) / 3600000;
    if (credentialAgeHours >= ALERT_THRESHOLDS.warning.credentialAgeHours) {
      alerts.push({
        level: credentialAgeHours >= ALERT_THRESHOLDS.critical.credentialAgeHours ? 'critical' : 'warning',
        code: 'CREDENTIAL_AGE',
        message: `Credentials ${Math.round(credentialAgeHours)}h old`,
        action: 'Session backup may be stale, verify MongoDB sync'
      });
      setLevel(credentialAgeHours >= ALERT_THRESHOLDS.critical.credentialAgeHours ? 'critical' : 'warning');
    }
  }
  
  // Missed heartbeats
  if (metrics.missedHeartbeats >= ALERT_THRESHOLDS.warning.missedHeartbeats) {
    alerts.push({
      level: metrics.missedHeartbeats >= ALERT_THRESHOLDS.critical.missedHeartbeats ? 'critical' : 'warning',
      code: 'MISSED_HEARTBEATS',
      message: `${metrics.missedHeartbeats} missed heartbeats`,
      action: 'Connection instability detected'
    });
    setLevel(metrics.missedHeartbeats >= ALERT_THRESHOLDS.critical.missedHeartbeats ? 'critical' : 'warning');
  }
  
  // Validation failures
  if (metrics.validationFailures >= ALERT_THRESHOLDS.warning.validationFailures) {
    alerts.push({
      level: 'warning',
      code: 'VALIDATION_FAILURES',
      message: `${metrics.validationFailures} checksum validation failures`,
      action: 'Session integrity at risk'
    });
    setLevel('warning');
  }
  
  // Slow reconnect
  if (metrics.lastReconnectDuration && 
      metrics.lastReconnectDuration >= ALERT_THRESHOLDS.warning.reconnectLatencyMs) {
    alerts.push({
      level: metrics.lastReconnectDuration >= ALERT_THRESHOLDS.critical.reconnectLatencyMs ? 'critical' : 'warning',
      code: 'SLOW_RECONNECT',
      message: `Last reconnect took ${Math.round(metrics.lastReconnectDuration / 1000)}s`,
      action: 'Network or WhatsApp service may be slow'
    });
  }
  
  return { level, alerts, alertCount: alerts.length };
};

/**
 * Get full observability data (dashboard-ready)
 * Designed to be CHEAP - no DB queries, all in-memory
 */
const getObservabilityData = () => {
  const now = Date.now();
  const alertStatus = evaluateAlerts();
  const percentiles = calculatePercentiles();
  
  return {
    // Metadata
    _meta: {
      generatedAt: new Date().toISOString(),
      responseTimeTarget: '10ms',
      version: '1.0.0'
    },
    
    // Overall health
    health: {
      status: alertStatus.level,  // ok | warning | critical
      alertCount: alertStatus.alertCount,
      uptime: now - metrics.serviceStartedAt,
      uptimeFormatted: formatDuration(now - metrics.serviceStartedAt)
    },
    
    // Session state machine
    session: {
      state: metrics.currentState,
      stateChangedAt: metrics.stateChangedAt ? new Date(metrics.stateChangedAt).toISOString() : null,
      stateAge: metrics.stateChangedAt ? now - metrics.stateChangedAt : null,
      stateAgeFormatted: metrics.stateChangedAt ? formatDuration(now - metrics.stateChangedAt) : null,
      initSuccessful: metrics.initSuccessful,
      authMethod: metrics.authMethod
    },
    
    // Reconnect tracking
    reconnect: {
      attempts: metrics.reconnectAttempts,
      maxAttempts: 10,
      attemptsRemaining: Math.max(0, 10 - metrics.reconnectAttempts),
      inProgress: metrics.currentState === 'reconnecting',
      startedAt: metrics.reconnectStartedAt ? new Date(metrics.reconnectStartedAt).toISOString() : null,
      currentDuration: metrics.reconnectStartedAt ? now - metrics.reconnectStartedAt : null,
      lastDuration: metrics.lastReconnectDuration,
      latencyPercentiles: percentiles
    },
    
    // Heartbeat (connection liveness)
    heartbeat: {
      lastAt: metrics.lastHeartbeatAt ? new Date(metrics.lastHeartbeatAt).toISOString() : null,
      age: metrics.lastHeartbeatAt ? now - metrics.lastHeartbeatAt : null,
      ageFormatted: metrics.lastHeartbeatAt ? formatDuration(now - metrics.lastHeartbeatAt) : 'never',
      count: metrics.heartbeatCount,
      missed: metrics.missedHeartbeats,
      healthy: metrics.lastHeartbeatAt ? (now - metrics.lastHeartbeatAt) < 60000 : false
    },
    
    // Auth freshness
    auth: {
      lastAuthAt: metrics.lastAuthAt ? new Date(metrics.lastAuthAt).toISOString() : null,
      authAge: metrics.lastAuthAt ? now - metrics.lastAuthAt : null,
      authAgeFormatted: metrics.lastAuthAt ? formatDuration(now - metrics.lastAuthAt) : 'never',
      lastCredentialWriteAt: metrics.lastCredentialWriteAt ? new Date(metrics.lastCredentialWriteAt).toISOString() : null,
      credentialAge: metrics.lastCredentialWriteAt ? now - metrics.lastCredentialWriteAt : null,
      credentialAgeFormatted: metrics.lastCredentialWriteAt ? formatDuration(now - metrics.lastCredentialWriteAt) : 'never',
      credentialFresh: metrics.lastCredentialWriteAt ? (now - metrics.lastCredentialWriteAt) < 3600000 : false  // <1 hour
    },
    
    // Lock status
    lock: {
      held: !!metrics.lockHeldBy,
      heldBy: metrics.lockHeldBy,
      operation: metrics.lockOperation,
      acquiredAt: metrics.lockAcquiredAt ? new Date(metrics.lockAcquiredAt).toISOString() : null,
      duration: metrics.lockAcquiredAt ? now - metrics.lockAcquiredAt : null
    },
    
    // Corruption flags
    integrity: {
      checksumValid: metrics.checksumValid,
      lastValidationAt: metrics.lastValidationAt ? new Date(metrics.lastValidationAt).toISOString() : null,
      validationFailures: metrics.validationFailures,
      corruptionDetectedAt: metrics.corruptionDetectedAt ? new Date(metrics.corruptionDetectedAt).toISOString() : null,
      status: metrics.checksumValid ? 'healthy' : 'corrupted'
    },
    
    // Circuit breaker
    circuitBreaker: {
      open: metrics.circuitBreakerOpen,
      trippedAt: metrics.circuitBreakerTrippedAt ? new Date(metrics.circuitBreakerTrippedAt).toISOString() : null,
      consecutiveFailures: metrics.consecutiveFailures,
      threshold: 3
    },
    
    // Alerts
    alerts: alertStatus.alerts,
    
    // Thresholds (for dashboard reference)
    thresholds: ALERT_THRESHOLDS
  };
};

/**
 * Get compact health status (for lightweight polling)
 */
const getHealthStatus = () => {
  const alertStatus = evaluateAlerts();
  const now = Date.now();
  
  return {
    status: alertStatus.level,
    state: metrics.currentState,
    connected: metrics.currentState === 'connected',
    heartbeatOk: metrics.lastHeartbeatAt ? (now - metrics.lastHeartbeatAt) < 60000 : false,
    alertCount: alertStatus.alertCount,
    uptime: now - metrics.serviceStartedAt
  };
};

/**
 * Format duration for human readability
 */
const formatDuration = (ms) => {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${Math.round(ms / 1000)}s`;
  if (ms < 3600000) return `${Math.round(ms / 60000)}m`;
  if (ms < 86400000) return `${Math.round(ms / 3600000)}h`;
  return `${Math.round(ms / 86400000)}d`;
};

/**
 * Reset metrics (for testing or after session clear)
 */
const resetMetrics = () => {
  metrics.currentState = 'disconnected';
  metrics.stateChangedAt = null;
  metrics.reconnectAttempts = 0;
  metrics.reconnectStartedAt = null;
  metrics.lastReconnectDuration = null;
  metrics.reconnectLatencies = [];
  metrics.lastHeartbeatAt = null;
  metrics.heartbeatCount = 0;
  metrics.missedHeartbeats = 0;
  metrics.lastAuthAt = null;
  metrics.lastCredentialWriteAt = null;
  metrics.authMethod = null;
  metrics.lockHeldBy = null;
  metrics.lockAcquiredAt = null;
  metrics.lockOperation = null;
  metrics.checksumValid = true;
  metrics.lastValidationAt = null;
  metrics.corruptionDetectedAt = null;
  metrics.validationFailures = 0;
  metrics.circuitBreakerOpen = false;
  metrics.circuitBreakerTrippedAt = null;
  metrics.consecutiveFailures = 0;
  metrics.initSuccessful = false;
  
  log('INFO', '[OBSERVABILITY] Metrics reset');
};

module.exports = {
  // State updates
  updateState,
  recordHeartbeat,
  recordCredentialWrite,
  recordValidation,
  updateLockStatus,
  recordLatency,
  resetMetrics,
  
  // Queries
  getObservabilityData,
  getHealthStatus,
  evaluateAlerts,
  
  // Constants
  ALERT_THRESHOLDS
};
