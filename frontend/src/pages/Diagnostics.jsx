import React, { useState, useEffect, useCallback } from 'react';
import { 
  Activity, 
  Database, 
  Server, 
  MessageCircle, 
  RefreshCw, 
  Trash2, 
  Terminal,
  CheckCircle,
  XCircle,
  AlertCircle,
  Cpu,
  HardDrive,
  Clock,
  FileText,
  ChevronDown,
  ChevronUp,
  Zap,
  RotateCcw
} from 'lucide-react';
import { toast } from 'sonner';
import { apiClient } from '../api';

const ServiceCard = ({ name, icon: Icon, status, details, port, onAction, actionLabel, actionIcon: ActionIcon }) => {
  const statusColors = {
    running: 'text-green-500 bg-green-500/10 border-green-500/20',
    stopped: 'text-red-500 bg-red-500/10 border-red-500/20',
    error: 'text-red-500 bg-red-500/10 border-red-500/20',
    unknown: 'text-yellow-500 bg-yellow-500/10 border-yellow-500/20',
    initializing: 'text-blue-500 bg-blue-500/10 border-blue-500/20'
  };

  const statusIcons = {
    running: CheckCircle,
    stopped: XCircle,
    error: XCircle,
    unknown: AlertCircle,
    initializing: RefreshCw
  };

  const StatusIcon = statusIcons[status] || AlertCircle;
  const colorClass = statusColors[status] || statusColors.unknown;

  return (
    <div className={`rounded-xl border p-5 ${colorClass}`}>
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-background/50">
            <Icon className="w-5 h-5" />
          </div>
          <div>
            <h3 className="font-semibold text-foreground">{name}</h3>
            <p className="text-xs text-muted-foreground">Port {port}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <StatusIcon className={`w-5 h-5 ${status === 'initializing' ? 'animate-spin' : ''}`} />
          <span className="text-sm font-medium capitalize">{status}</span>
        </div>
      </div>
      
      {details && (
        <div className="mt-4 p-3 rounded-lg bg-background/50 text-xs font-mono space-y-1">
          {Object.entries(details).slice(0, 5).map(([key, value]) => (
            <div key={key} className="flex justify-between">
              <span className="text-muted-foreground">{key}:</span>
              <span className="text-foreground">{String(value).substring(0, 30)}</span>
            </div>
          ))}
        </div>
      )}
      
      {onAction && (
        <button
          onClick={onAction}
          className="mt-4 w-full flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-background/50 hover:bg-background text-sm font-medium transition-colors"
        >
          {ActionIcon && <ActionIcon className="w-4 h-4" />}
          {actionLabel}
        </button>
      )}
    </div>
  );
};

const LogViewer = ({ service, logs, isLoading, onRefresh, onClear }) => {
  const [expanded, setExpanded] = useState(true);
  
  return (
    <div className="rounded-xl border border-border bg-card overflow-hidden">
      <div 
        className="flex items-center justify-between p-4 bg-muted/30 cursor-pointer"
        onClick={() => setExpanded(!expanded)}
      >
        <div className="flex items-center gap-3">
          <Terminal className="w-5 h-5 text-primary" />
          <h3 className="font-semibold capitalize">{service} Logs</h3>
          {logs?.file && (
            <span className="text-xs text-muted-foreground bg-background px-2 py-1 rounded">
              {logs.file}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <button 
            onClick={(e) => { e.stopPropagation(); onRefresh(); }}
            className="p-2 hover:bg-background rounded-lg transition-colors"
            disabled={isLoading}
          >
            <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
          <button 
            onClick={(e) => { e.stopPropagation(); onClear(); }}
            className="p-2 hover:bg-background rounded-lg transition-colors text-destructive"
          >
            <Trash2 className="w-4 h-4" />
          </button>
          {expanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
        </div>
      </div>
      
      {expanded && (
        <div className="p-4 bg-zinc-950 max-h-64 overflow-y-auto font-mono text-xs">
          {logs?.logs?.length > 0 ? (
            logs.logs.map((line, i) => (
              <div 
                key={i} 
                className={`py-0.5 ${
                  line.includes('ERROR') || line.includes('[!!]') ? 'text-red-400' :
                  line.includes('WARN') || line.includes('[!]') ? 'text-yellow-400' :
                  line.includes('INFO') || line.includes('[OK]') ? 'text-green-400' :
                  'text-zinc-300'
                }`}
              >
                {line}
              </div>
            ))
          ) : (
            <div className="text-zinc-500 text-center py-4">
              {logs?.message || 'No logs available'}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default function Diagnostics() {
  const [diagnostics, setDiagnostics] = useState(null);
  const [logs, setLogs] = useState({});
  const [logsSummary, setLogsSummary] = useState({});
  const [loading, setLoading] = useState(true);
  const [loadingLogs, setLoadingLogs] = useState({});
  const [autoRefresh, setAutoRefresh] = useState(true);

  const fetchDiagnostics = useCallback(async () => {
    try {
      const response = await apiClient.get('/api/diagnostics');
      setDiagnostics(response.data);
    } catch (error) {
      console.error('Failed to fetch diagnostics:', error);
    }
  }, []);

  const fetchLogsSummary = useCallback(async () => {
    try {
      const response = await apiClient.get('/api/diagnostics/logs');
      setLogsSummary(response.data);
    } catch (error) {
      console.error('Failed to fetch logs summary:', error);
    }
  }, []);

  const fetchServiceLogs = async (service) => {
    setLoadingLogs(prev => ({ ...prev, [service]: true }));
    try {
      const response = await apiClient.get(`/api/diagnostics/logs/${service}?lines=50`);
      setLogs(prev => ({ ...prev, [service]: response.data }));
    } catch (error) {
      console.error(`Failed to fetch ${service} logs:`, error);
    } finally {
      setLoadingLogs(prev => ({ ...prev, [service]: false }));
    }
  };

  const clearLogs = async (service) => {
    try {
      await apiClient.post(`/api/diagnostics/clear-logs/${service}`);
      toast.success(`${service} logs cleared`);
      fetchServiceLogs(service);
      fetchLogsSummary();
    } catch (error) {
      toast.error('Failed to clear logs');
    }
  };

  const retryWhatsApp = async () => {
    try {
      await apiClient.post('/api/whatsapp/retry');
      toast.success('WhatsApp initialization retry triggered');
      setTimeout(fetchDiagnostics, 2000);
    } catch (error) {
      toast.error('Failed to retry WhatsApp initialization');
    }
  };

  const clearWhatsAppSession = async () => {
    try {
      await api.post('/whatsapp/clear-session');
      toast.success('WhatsApp session cleared, reinitializing...');
      setTimeout(fetchDiagnostics, 3000);
    } catch (error) {
      toast.error('Failed to clear WhatsApp session');
    }
  };

  const testBrowser = async () => {
    toast.info('Testing browser launch...');
    try {
      const response = await api.get('/whatsapp/test-browser');
      if (response.data.success) {
        toast.success(`Browser works! Version: ${response.data.browserVersion}`);
      } else {
        toast.error(`Browser test failed: ${response.data.error}`);
      }
    } catch (error) {
      toast.error('Browser test failed');
    }
  };

  useEffect(() => {
    const init = async () => {
      setLoading(true);
      await Promise.all([
        fetchDiagnostics(),
        fetchLogsSummary()
      ]);
      // Fetch logs for all services
      for (const service of ['whatsapp', 'backend', 'frontend', 'system']) {
        await fetchServiceLogs(service);
      }
      setLoading(false);
    };
    init();
  }, [fetchDiagnostics, fetchLogsSummary]);

  // Auto-refresh
  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(() => {
      fetchDiagnostics();
    }, 10000);
    return () => clearInterval(interval);
  }, [autoRefresh, fetchDiagnostics]);

  const getWhatsAppStatus = () => {
    if (!diagnostics?.services?.whatsapp) return 'unknown';
    const wa = diagnostics.services.whatsapp;
    if (wa.status === 'stopped') return 'stopped';
    if (wa.status === 'error') return 'error';
    if (wa.details?.isInitializing) return 'initializing';
    if (wa.details?.isReady) return 'running';
    return wa.status;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-6" data-testid="diagnostics-page">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">System Diagnostics</h1>
          <p className="text-muted-foreground">Monitor all services and view logs in real-time</p>
        </div>
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              className="rounded"
            />
            Auto-refresh
          </label>
          <button
            onClick={() => {
              fetchDiagnostics();
              fetchLogsSummary();
            }}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            <RefreshCw className="w-4 h-4" />
            Refresh All
          </button>
        </div>
      </div>

      {/* System Stats */}
      {diagnostics?.system && (
        <div className="grid grid-cols-4 gap-4">
          <div className="rounded-xl border border-border bg-card p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-blue-500/10">
                <Server className="w-5 h-5 text-blue-500" />
              </div>
              <div>
                <p className="text-xs text-muted-foreground">Platform</p>
                <p className="font-semibold">{diagnostics.system.platform}</p>
              </div>
            </div>
          </div>
          <div className="rounded-xl border border-border bg-card p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-green-500/10">
                <Cpu className="w-5 h-5 text-green-500" />
              </div>
              <div>
                <p className="text-xs text-muted-foreground">CPU Usage</p>
                <p className="font-semibold">{diagnostics.system.cpu_percent}%</p>
              </div>
            </div>
          </div>
          <div className="rounded-xl border border-border bg-card p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-purple-500/10">
                <Activity className="w-5 h-5 text-purple-500" />
              </div>
              <div>
                <p className="text-xs text-muted-foreground">Memory</p>
                <p className="font-semibold">{diagnostics.system.memory_percent}%</p>
              </div>
            </div>
          </div>
          <div className="rounded-xl border border-border bg-card p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-orange-500/10">
                <Clock className="w-5 h-5 text-orange-500" />
              </div>
              <div>
                <p className="text-xs text-muted-foreground">Last Check</p>
                <p className="font-semibold text-sm">
                  {new Date(diagnostics.timestamp).toLocaleTimeString()}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Service Status */}
      <div>
        <h2 className="text-lg font-semibold mb-4">Service Status</h2>
        <div className="grid grid-cols-3 gap-4">
          <ServiceCard
            name="WhatsApp Service"
            icon={MessageCircle}
            status={getWhatsAppStatus()}
            port={3001}
            details={diagnostics?.services?.whatsapp?.details}
            onAction={retryWhatsApp}
            actionLabel="Retry Init"
            actionIcon={RotateCcw}
          />
          <ServiceCard
            name="Backend API"
            icon={Server}
            status={diagnostics?.services?.backend?.status || 'unknown'}
            port={8001}
          />
          <ServiceCard
            name="MongoDB"
            icon={Database}
            status={diagnostics?.services?.mongodb?.status || 'unknown'}
            port={27017}
          />
        </div>
      </div>

      {/* WhatsApp Actions */}
      <div className="rounded-xl border border-border bg-card p-5">
        <h2 className="text-lg font-semibold mb-4">WhatsApp Actions</h2>
        <div className="flex gap-3">
          <button
            onClick={retryWhatsApp}
            className="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
          >
            <RotateCcw className="w-4 h-4" />
            Retry Initialization
          </button>
          <button
            onClick={clearWhatsAppSession}
            className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Clear Session & Restart
          </button>
          <button
            onClick={testBrowser}
            className="flex items-center gap-2 px-4 py-2 bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors"
          >
            <Zap className="w-4 h-4" />
            Test Browser Launch
          </button>
        </div>
        {diagnostics?.services?.whatsapp?.details?.error && (
          <div className="mt-4 p-4 rounded-lg bg-red-500/10 border border-red-500/20">
            <h4 className="font-medium text-red-500 mb-2">Error Details</h4>
            <pre className="text-xs text-red-400 whitespace-pre-wrap font-mono">
              {diagnostics.services.whatsapp.details.error}
            </pre>
          </div>
        )}
      </div>

      {/* Logs Summary */}
      <div className="rounded-xl border border-border bg-card p-5">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold">Log Files</h2>
          <button
            onClick={() => clearLogs('all')}
            className="flex items-center gap-2 px-3 py-1.5 text-sm text-destructive hover:bg-destructive/10 rounded-lg transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Clear All Logs
          </button>
        </div>
        <div className="grid grid-cols-4 gap-4">
          {Object.entries(logsSummary).map(([service, info]) => (
            <div key={service} className="p-4 rounded-lg bg-muted/30">
              <div className="flex items-center gap-2 mb-2">
                <FileText className="w-4 h-4 text-primary" />
                <span className="font-medium capitalize">{service}</span>
              </div>
              <div className="text-xs text-muted-foreground space-y-1">
                <p>{info.file_count} files</p>
                <p>{info.total_size_mb} MB</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Log Viewers */}
      <div className="space-y-4">
        <h2 className="text-lg font-semibold">Live Logs</h2>
        {['whatsapp', 'backend', 'system'].map(service => (
          <LogViewer
            key={service}
            service={service}
            logs={logs[service]}
            isLoading={loadingLogs[service]}
            onRefresh={() => fetchServiceLogs(service)}
            onClear={() => clearLogs(service)}
          />
        ))}
      </div>
    </div>
  );
}
