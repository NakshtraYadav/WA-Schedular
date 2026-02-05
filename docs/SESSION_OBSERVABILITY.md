# Session Observability API

## Overview

Operator-grade monitoring endpoints for WhatsApp session health. Designed for:
- Dashboard integration (Grafana, custom UIs)
- Alerting systems (PagerDuty, Slack)
- Prometheus scraping
- Health checks (load balancers, uptime monitors)

## Endpoints

### GET /session/health
**Purpose:** Lightweight health check for frequent polling  
**Response Time:** <5ms  
**Use Case:** Load balancer checks, uptime monitors

```json
{
  "status": "ok",           // "ok" | "warning" | "critical"
  "state": "connected",     // Session state machine position
  "connected": true,
  "heartbeatOk": true,
  "alertCount": 0,
  "uptime": 3600000,
  "_responseTime": "2ms"
}
```

**HTTP Status Codes:**
- `200` - OK or Warning (service operational)
- `503` - Critical (service degraded)

---

### GET /session/observe
**Purpose:** Full observability data for dashboards  
**Response Time:** <10ms  
**Use Case:** Grafana dashboards, debugging

```json
{
  "_meta": {
    "generatedAt": "2026-02-05T12:00:00.000Z",
    "responseTimeTarget": "10ms",
    "version": "1.0.0"
  },
  
  "health": {
    "status": "ok",
    "alertCount": 0,
    "uptime": 3600000,
    "uptimeFormatted": "1h"
  },
  
  "session": {
    "state": "connected",
    "stateChangedAt": "2026-02-05T11:00:00.000Z",
    "stateAge": 3600000,
    "stateAgeFormatted": "1h",
    "initSuccessful": true,
    "authMethod": "session_restore"
  },
  
  "reconnect": {
    "attempts": 0,
    "maxAttempts": 10,
    "attemptsRemaining": 10,
    "inProgress": false,
    "latencyPercentiles": {
      "p50": 5000,
      "p90": 12000,
      "p99": 25000
    }
  },
  
  "heartbeat": {
    "lastAt": "2026-02-05T11:59:30.000Z",
    "age": 30000,
    "ageFormatted": "30s",
    "count": 120,
    "missed": 0,
    "healthy": true
  },
  
  "auth": {
    "lastAuthAt": "2026-02-05T11:00:00.000Z",
    "authAge": 3600000,
    "lastCredentialWriteAt": "2026-02-05T11:59:00.000Z",
    "credentialAge": 60000,
    "credentialFresh": true
  },
  
  "lock": {
    "held": false,
    "heldBy": null,
    "operation": null
  },
  
  "integrity": {
    "checksumValid": true,
    "validationFailures": 0,
    "status": "healthy"
  },
  
  "circuitBreaker": {
    "open": false,
    "consecutiveFailures": 0,
    "threshold": 3
  },
  
  "alerts": []
}
```

---

### GET /session/alerts
**Purpose:** Active alerts only  
**Use Case:** Alerting integrations (PagerDuty, Slack)

```json
{
  "level": "warning",
  "count": 1,
  "alerts": [
    {
      "level": "warning",
      "code": "HEARTBEAT_STALE",
      "message": "No heartbeat for 65s",
      "action": "Connection may be degraded"
    }
  ],
  "checkedAt": "2026-02-05T12:00:00.000Z"
}
```

---

### GET /session/metrics
**Purpose:** Prometheus-compatible metrics  
**Use Case:** Prometheus scraping

```
# HELP wa_session_state Current session state
# TYPE wa_session_state gauge
wa_session_state{state="connected"} 1

# HELP wa_reconnect_attempts_total Total reconnect attempts
# TYPE wa_reconnect_attempts_total counter
wa_reconnect_attempts_total 0

# HELP wa_heartbeat_age_seconds Seconds since last heartbeat
# TYPE wa_heartbeat_age_seconds gauge
wa_heartbeat_age_seconds 30

# HELP wa_circuit_breaker_open Circuit breaker state
# TYPE wa_circuit_breaker_open gauge
wa_circuit_breaker_open 0
```

---

## Alert Thresholds

### Warning Level
| Metric | Threshold | Meaning |
|--------|-----------|---------|
| Heartbeat age | 60s | No heartbeat for 60 seconds |
| Reconnect attempts | 3 | 3+ reconnect attempts |
| Credential age | 24h | Credentials older than 24 hours |
| Reconnect latency | 30s | Reconnect taking >30 seconds |
| Missed heartbeats | 3 | 3 missed heartbeats |
| Validation failures | 1 | Any checksum failure |

### Critical Level
| Metric | Threshold | Meaning |
|--------|-----------|---------|
| Heartbeat age | 300s | No heartbeat for 5 minutes |
| Reconnect attempts | 7 | 7+ attempts (near max 10) |
| Credential age | 168h | Credentials older than 7 days |
| Reconnect latency | 120s | Reconnect taking >2 minutes |
| Missed heartbeats | 10 | 10 missed heartbeats |
| Circuit breaker | open | Circuit breaker tripped |
| Corruption | detected | Session data corrupted |
| Disconnection | 30min | Disconnected for 30+ minutes |

---

## Integration Examples

### Grafana Dashboard Query (Prometheus)

```promql
# Session connected ratio
avg_over_time(wa_session_state[5m])

# Reconnect attempts trend
increase(wa_reconnect_attempts_total[1h])

# Heartbeat freshness
wa_heartbeat_age_seconds < 60
```

### Slack Webhook Alert

```bash
# Poll alerts endpoint and send to Slack if critical
curl -s http://localhost:3001/session/alerts | \
  jq -r 'select(.level == "critical") | .alerts[] | "⚠️ \(.code): \(.message)"' | \
  while read msg; do
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$msg\"}" \
      $SLACK_WEBHOOK_URL
  done
```

### Health Check Script

```bash
#!/bin/bash
response=$(curl -s -w "%{http_code}" http://localhost:3001/session/health)
http_code="${response: -3}"
body="${response:0:${#response}-3}"

if [ "$http_code" -eq 503 ]; then
  echo "CRITICAL: WhatsApp session unhealthy"
  echo "$body" | jq .
  exit 2
elif [ "$http_code" -eq 200 ]; then
  status=$(echo "$body" | jq -r .status)
  if [ "$status" = "warning" ]; then
    echo "WARNING: WhatsApp session has warnings"
    exit 1
  fi
  echo "OK: WhatsApp session healthy"
  exit 0
fi
```

---

## Backend API Proxy

The observability endpoints are also available through the Python backend:

- `GET /api/whatsapp/session/health`
- `GET /api/whatsapp/session/observe`
- `GET /api/whatsapp/session/alerts`

This allows frontend applications to access session health through the standard API gateway.
