/**
 * Session Observability Routes
 * 
 * Operator-grade endpoints for monitoring WhatsApp session health.
 * Designed for dashboard integration and alerting systems.
 * 
 * ENDPOINTS:
 * GET /session/health     - Compact health status (polling)
 * GET /session/observe    - Full observability data (dashboards)
 * GET /session/alerts     - Active alerts only
 * GET /session/metrics    - Prometheus-style metrics
 */

const express = require('express');
const router = express.Router();
const { 
  getObservabilityData, 
  getHealthStatus, 
  evaluateAlerts,
  ALERT_THRESHOLDS 
} = require('../services/session/observability');
const { log } = require('../utils/logger');

/**
 * GET /session/health
 * 
 * Lightweight health check for frequent polling.
 * Response time target: <5ms
 * 
 * Use for: Load balancer health checks, uptime monitors
 */
router.get('/health', (req, res) => {
  const startTime = Date.now();
  const health = getHealthStatus();
  
  // Set appropriate HTTP status based on health
  let httpStatus = 200;
  if (health.status === 'critical') httpStatus = 503;
  else if (health.status === 'warning') httpStatus = 200;  // Still operational
  
  res.status(httpStatus).json({
    ...health,
    _responseTime: `${Date.now() - startTime}ms`
  });
});

/**
 * GET /session/observe
 * 
 * Full observability data for dashboards.
 * Response time target: <10ms
 * 
 * Use for: Grafana, custom dashboards, debugging
 */
router.get('/observe', (req, res) => {
  const startTime = Date.now();
  
  try {
    const data = getObservabilityData();
    data._meta.responseTime = `${Date.now() - startTime}ms`;
    
    res.json(data);
  } catch (error) {
    log('ERROR', `Observability error: ${error.message}`);
    res.status(500).json({
      error: 'Failed to collect observability data',
      message: error.message
    });
  }
});

/**
 * GET /session/alerts
 * 
 * Active alerts only - for alerting integrations.
 * 
 * Use for: PagerDuty, Slack webhooks, alert aggregators
 */
router.get('/alerts', (req, res) => {
  const alertStatus = evaluateAlerts();
  
  res.json({
    level: alertStatus.level,
    count: alertStatus.alertCount,
    alerts: alertStatus.alerts,
    thresholds: ALERT_THRESHOLDS,
    checkedAt: new Date().toISOString()
  });
});

/**
 * GET /session/metrics
 * 
 * Prometheus-compatible metrics format.
 * 
 * Use for: Prometheus scraping, metrics aggregation
 */
router.get('/metrics', (req, res) => {
  const data = getObservabilityData();
  const now = Date.now();
  
  // Build Prometheus text format
  const lines = [
    '# HELP wa_session_state Current session state (1=connected, 0=other)',
    '# TYPE wa_session_state gauge',
    `wa_session_state{state="${data.session.state}"} ${data.session.state === 'connected' ? 1 : 0}`,
    '',
    '# HELP wa_session_uptime_seconds Service uptime in seconds',
    '# TYPE wa_session_uptime_seconds counter',
    `wa_session_uptime_seconds ${Math.round(data.health.uptime / 1000)}`,
    '',
    '# HELP wa_reconnect_attempts_total Total reconnect attempts',
    '# TYPE wa_reconnect_attempts_total counter',
    `wa_reconnect_attempts_total ${data.reconnect.attempts}`,
    '',
    '# HELP wa_heartbeat_age_seconds Seconds since last heartbeat',
    '# TYPE wa_heartbeat_age_seconds gauge',
    `wa_heartbeat_age_seconds ${data.heartbeat.age ? Math.round(data.heartbeat.age / 1000) : -1}`,
    '',
    '# HELP wa_heartbeat_total Total heartbeat count',
    '# TYPE wa_heartbeat_total counter',
    `wa_heartbeat_total ${data.heartbeat.count}`,
    '',
    '# HELP wa_heartbeat_missed_total Missed heartbeats',
    '# TYPE wa_heartbeat_missed_total counter',
    `wa_heartbeat_missed_total ${data.heartbeat.missed}`,
    '',
    '# HELP wa_credential_age_seconds Seconds since last credential write',
    '# TYPE wa_credential_age_seconds gauge',
    `wa_credential_age_seconds ${data.auth.credentialAge ? Math.round(data.auth.credentialAge / 1000) : -1}`,
    '',
    '# HELP wa_checksum_valid Session checksum validity (1=valid, 0=corrupt)',
    '# TYPE wa_checksum_valid gauge',
    `wa_checksum_valid ${data.integrity.checksumValid ? 1 : 0}`,
    '',
    '# HELP wa_validation_failures_total Checksum validation failures',
    '# TYPE wa_validation_failures_total counter',
    `wa_validation_failures_total ${data.integrity.validationFailures}`,
    '',
    '# HELP wa_circuit_breaker_open Circuit breaker state (1=open, 0=closed)',
    '# TYPE wa_circuit_breaker_open gauge',
    `wa_circuit_breaker_open ${data.circuitBreaker.open ? 1 : 0}`,
    '',
    '# HELP wa_consecutive_failures Current consecutive failure count',
    '# TYPE wa_consecutive_failures gauge',
    `wa_consecutive_failures ${data.circuitBreaker.consecutiveFailures}`,
    '',
    '# HELP wa_reconnect_latency_p50_ms 50th percentile reconnect latency',
    '# TYPE wa_reconnect_latency_p50_ms gauge',
    `wa_reconnect_latency_p50_ms ${data.reconnect.latencyPercentiles.p50 || 0}`,
    '',
    '# HELP wa_reconnect_latency_p90_ms 90th percentile reconnect latency',
    '# TYPE wa_reconnect_latency_p90_ms gauge',
    `wa_reconnect_latency_p90_ms ${data.reconnect.latencyPercentiles.p90 || 0}`,
    '',
    '# HELP wa_reconnect_latency_p99_ms 99th percentile reconnect latency',
    '# TYPE wa_reconnect_latency_p99_ms gauge',
    `wa_reconnect_latency_p99_ms ${data.reconnect.latencyPercentiles.p99 || 0}`,
    '',
    '# HELP wa_alert_count Current number of active alerts',
    '# TYPE wa_alert_count gauge',
    `wa_alert_count{level="${data.health.status}"} ${data.health.alertCount}`,
    ''
  ];
  
  res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
  res.send(lines.join('\n'));
});

/**
 * GET /session/thresholds
 * 
 * Get current alert threshold configuration.
 * 
 * Use for: Documentation, threshold tuning
 */
router.get('/thresholds', (req, res) => {
  res.json({
    thresholds: ALERT_THRESHOLDS,
    description: {
      warning: 'Conditions that require attention but service is operational',
      critical: 'Conditions that may cause service failure or data loss'
    }
  });
});

module.exports = router;
