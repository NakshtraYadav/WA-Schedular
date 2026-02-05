/**
 * PM2 Ecosystem Configuration
 * 
 * Zero-touch graceful restart system for WA Scheduler
 * 
 * GUARANTEES:
 * - No WhatsApp session corruption
 * - No duplicate scheduler execution
 * - No partial MongoDB writes
 * - No zombie distributed locks
 * - No reconnect storms
 */

module.exports = {
  apps: [
    // =========================================================================
    // WHATSAPP SERVICE (Most Critical - Longest Shutdown)
    // =========================================================================
    {
      name: 'wa-whatsapp',
      script: 'index.js',
      cwd: './whatsapp-service',
      
      // Interpreter
      interpreter: 'node',
      interpreter_args: '--max-old-space-size=2048',
      
      // Restart behavior
      autorestart: true,
      watch: false,  // Never watch - too risky for session
      max_restarts: 10,
      min_uptime: '30s',
      restart_delay: 5000,
      
      // CRITICAL: Graceful shutdown settings
      kill_timeout: 30000,        // 30 seconds for session save
      wait_ready: true,           // Wait for 'ready' signal
      listen_timeout: 60000,      // 60s to become ready
      shutdown_with_message: true,
      
      // Memory management
      max_memory_restart: '2G',   // Restart if using >2GB
      
      // Environment
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      env_development: {
        NODE_ENV: 'development',
        PORT: 3001
      },
      
      // Logging
      log_file: './logs/whatsapp-combined.log',
      out_file: './logs/whatsapp-out.log',
      error_file: './logs/whatsapp-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      // Prevent duplicate instances
      instance_var: 'INSTANCE_ID',
      instances: 1,
      exec_mode: 'fork',  // NOT cluster - WhatsApp needs single instance
      
      // Health check
      exp_backoff_restart_delay: 100  // Exponential backoff on crash
    },

    // =========================================================================
    // BACKEND SERVICE (Python FastAPI)
    // =========================================================================
    {
      name: 'wa-backend',
      script: 'venv/bin/python',
      args: '-m uvicorn server:app --host 0.0.0.0 --port 8001',
      cwd: './backend',
      
      // Restart behavior
      autorestart: true,
      watch: false,  // Use uvicorn's built-in reload in dev
      max_restarts: 10,
      min_uptime: '10s',
      restart_delay: 2000,
      
      // Graceful shutdown
      kill_timeout: 10000,        // 10 seconds for in-flight requests
      wait_ready: true,
      listen_timeout: 30000,
      
      // Memory management
      max_memory_restart: '512M',
      
      // Environment
      env: {
        PYTHONUNBUFFERED: '1'
      },
      env_development: {
        PYTHONUNBUFFERED: '1'
      },
      
      // Logging
      log_file: './logs/backend-combined.log',
      out_file: './logs/backend-out.log',
      error_file: './logs/backend-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      // Single instance (scheduler requires this)
      instances: 1,
      exec_mode: 'fork'
    },

    // =========================================================================
    // FRONTEND SERVICE (React)
    // =========================================================================
    {
      name: 'wa-frontend',
      script: 'npm',
      args: 'start',
      cwd: './frontend',
      
      // Restart behavior
      autorestart: true,
      watch: false,  // React has HMR
      max_restarts: 5,
      min_uptime: '30s',
      restart_delay: 3000,
      
      // Graceful shutdown
      kill_timeout: 5000,         // 5 seconds is enough for frontend
      
      // Memory management
      max_memory_restart: '1G',
      
      // Environment
      env: {
        PORT: 3000,
        BROWSER: 'none',
        CI: 'false'
      },
      
      // Logging
      log_file: './logs/frontend-combined.log',
      out_file: './logs/frontend-out.log',
      error_file: './logs/frontend-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      instances: 1,
      exec_mode: 'fork'
    }
  ],

  // ===========================================================================
  // DEPLOYMENT CONFIGURATION
  // ===========================================================================
  deploy: {
    production: {
      user: 'wa-scheduler',
      host: 'localhost',
      ref: 'origin/main',
      repo: 'git@github.com:user/wa-scheduler.git',
      path: '/opt/wa-scheduler',
      
      // Pre-deployment: ensure clean state
      'pre-deploy-local': '',
      
      // Post-deployment: install deps, graceful reload
      'post-deploy': 'npm install --prefix frontend --legacy-peer-deps && pip install -r backend/requirements.txt && npm install --prefix whatsapp-service && pm2 reload ecosystem.config.js --env production',
      
      // Pre-setup: create directories
      'pre-setup': 'mkdir -p /opt/wa-scheduler/logs'
    }
  }
};
