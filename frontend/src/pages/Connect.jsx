import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { 
  Radio, 
  RefreshCw,
  LogOut,
  CheckCircle,
  Smartphone,
  Loader2,
  Zap,
  Trash2,
  AlertTriangle,
  QrCode
} from 'lucide-react';
import { getWhatsAppStatus, getWhatsAppQR, logoutWhatsApp } from '../api';
import { toast } from 'sonner';
import axios from 'axios';

const API_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:8001';

function Connect() {
  const [status, setStatus] = useState(null);
  const [qrCode, setQrCode] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [clearingSession, setClearingSession] = useState(false);
  const [generatingQR, setGeneratingQR] = useState(false);

  const fetchStatus = useCallback(async () => {
    try {
      const [statusRes, qrRes] = await Promise.all([
        getWhatsAppStatus(),
        getWhatsAppQR()
      ]);
      setStatus(statusRes.data);
      setQrCode(qrRes.data?.qrCode || null);
    } catch (error) {
      console.error('Failed to fetch status:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 3000);
    return () => clearInterval(interval);
  }, [fetchStatus]);

  const handleLogout = async () => {
    if (!window.confirm('Disconnect from WhatsApp?')) return;
    setLoggingOut(true);
    try {
      await logoutWhatsApp();
      toast.success('Logged out from WhatsApp');
      fetchStatus();
    } catch (error) {
      toast.error('Failed to logout');
    } finally {
      setLoggingOut(false);
    }
  };

  const handleClearSession = async () => {
    if (!window.confirm('This will clear the WhatsApp session. You will need to scan the QR code again. Continue?')) {
      return;
    }
    
    setClearingSession(true);
    try {
      // Call the clear-session endpoint directly on WhatsApp service
      await axios.post('http://localhost:3001/clear-session', {}, { timeout: 10000 });
      toast.success('Session cleared! Click "Generate QR Code" to reconnect.');
      setQrCode(null);
      
      // Wait a moment then refresh
      setTimeout(() => {
        fetchStatus();
      }, 3000);
    } catch (error) {
      // Try via backend
      try {
        await axios.post(`${API_URL}/api/whatsapp/clear-session`, {}, { timeout: 10000 });
        toast.success('Session cleared! Click "Generate QR Code" to reconnect.');
        setQrCode(null);
        setTimeout(() => fetchStatus(), 3000);
      } catch (e) {
        toast.error('Could not clear session. Try running scripts/fix-whatsapp.bat manually.');
      }
    } finally {
      setClearingSession(false);
    }
  };

  const handleGenerateQR = async () => {
    setGeneratingQR(true);
    try {
      await axios.post('http://localhost:3001/generate-qr', {}, { timeout: 5000 });
      toast.success('Generating QR code... Please wait 10-30 seconds.');
      
      // Start polling for QR code
      let attempts = 0;
      const pollInterval = setInterval(async () => {
        attempts++;
        await fetchStatus();
        
        if (qrCode || status?.isReady || attempts > 30) {
          clearInterval(pollInterval);
          setGeneratingQR(false);
        }
      }, 2000);
    } catch (error) {
      toast.error('Could not start QR generation. Check if WhatsApp service is running.');
      setGeneratingQR(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  // Check for specific error types
  const hasFrameError = status?.error && (
    status.error.includes('frame') || 
    status.error.includes('detached') ||
    status.error.includes('Target closed') ||
    status.error.includes('Protocol error') ||
    status.error.includes('Navigation')
  );

  return (
    <div data-testid="connect-page" className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">WhatsApp Connection</h1>
          <p className="text-muted-foreground mt-1">Connect your WhatsApp account via QR code</p>
        </div>
        <Button 
          onClick={fetchStatus}
          variant="outline"
          size="sm"
          data-testid="refresh-status-btn"
        >
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg flex items-center gap-2">
            <Radio className="w-5 h-5" />
            Connection Status
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4">
            <div className={`w-16 h-16 rounded-full flex items-center justify-center ${
              status?.isReady 
                ? 'bg-emerald-500/20' 
                : status?.hasQrCode 
                  ? 'bg-amber-500/20'
                  : status?.isInitializing
                    ? 'bg-blue-500/20'
                    : 'bg-red-500/20'
            }`}>
              {status?.isReady ? (
                <CheckCircle className="w-8 h-8 text-emerald-500" />
              ) : status?.hasQrCode ? (
                <Smartphone className="w-8 h-8 text-amber-500" />
              ) : status?.isInitializing ? (
                <Loader2 className="w-8 h-8 text-blue-500 animate-spin" />
              ) : (
                <Radio className="w-8 h-8 text-red-500" />
              )}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <Badge 
                  variant={status?.isReady ? 'default' : 'secondary'}
                  className={status?.isReady ? 'bg-emerald-500' : ''}
                >
                  {status?.isReady ? 'Connected' : status?.hasQrCode ? 'Waiting for scan' : status?.isInitializing ? 'Initializing...' : 'Disconnected'}
                </Badge>
                {status?.isInitializing && (
                  <Badge variant="outline" className="text-blue-500 border-blue-500">
                    Attempt {status.initAttempts || 1}/3
                  </Badge>
                )}
              </div>
              {status?.isReady && status?.clientInfo && (
                <p className="text-muted-foreground mt-1">
                  Logged in as <span className="font-medium text-foreground">{status.clientInfo.pushname}</span>
                  {status.clientInfo.phone && (
                    <span className="text-xs text-muted-foreground ml-2">({status.clientInfo.phone})</span>
                  )}
                </p>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Error with specific fix for frame detached */}
      {status?.error && hasFrameError && (
        <Card className="bg-card border-destructive">
          <CardHeader className="pb-2">
            <CardTitle className="font-heading text-lg flex items-center gap-2 text-destructive">
              <AlertTriangle className="w-5 h-5" />
              WhatsApp Initialization Error
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-destructive mb-4">{status.error}</p>
            <div className="p-4 rounded-lg bg-amber-500/10 border border-amber-500/30 mb-4">
              <p className="text-sm font-medium text-amber-500 mb-2">This is a known issue. Here's how to fix it:</p>
              <ol className="text-xs text-muted-foreground list-decimal list-inside space-y-1">
                <li>Click <strong>"Clear Session & Retry"</strong> below</li>
                <li>Wait 30-90 seconds for reinitialization</li>
                <li>If it still fails, run <code className="bg-secondary px-1 rounded">scripts\fix-whatsapp.bat</code></li>
                <li>Make sure Google Chrome is installed and no Chrome windows are open</li>
              </ol>
            </div>
            <div className="flex gap-2">
              <Button 
                onClick={handleClearSession} 
                disabled={clearingSession}
                variant="default"
              >
                {clearingSession ? (
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                ) : (
                  <Trash2 className="w-4 h-4 mr-2" />
                )}
                {clearingSession ? 'Clearing...' : 'Clear Session & Retry'}
              </Button>
              <Button 
                onClick={handleRetryInit} 
                disabled={retrying}
                variant="outline"
              >
                <RefreshCw className={`w-4 h-4 mr-2 ${retrying ? 'animate-spin' : ''}`} />
                {retrying ? 'Retrying...' : 'Retry Init'}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {!status?.isReady && (
        <Card className="bg-card border-border">
          <CardHeader>
            <CardTitle className="font-heading text-lg">Connect WhatsApp</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col items-center">
              {qrCode ? (
                <>
                  <div className="qr-container mb-4" data-testid="qr-code-container">
                    <img 
                      src={qrCode} 
                      alt="WhatsApp QR Code" 
                      className="w-64 h-64"
                      data-testid="qr-code-image"
                    />
                  </div>
                  <div className="text-center">
                    <p className="text-muted-foreground">
                      Open WhatsApp on your phone
                    </p>
                    <p className="text-sm text-muted-foreground mt-1">
                      Go to <span className="font-medium text-foreground">Settings → Linked Devices → Link a Device</span>
                    </p>
                    <p className="text-sm text-muted-foreground mt-1">
                      Point your phone at this screen to capture the QR code
                    </p>
                    {status?.qrCount === 1 && (
                      <p className="text-xs text-amber-500 mt-3">
                        💡 First QR code - if scan fails, wait ~20s for auto-refresh
                      </p>
                    )}
                  </div>
                </>
              ) : (
                <div className="text-center py-8">
                  {status?.error && !hasFrameError ? (
                    <>
                      <div className="w-16 h-16 rounded-full bg-red-500/20 flex items-center justify-center mx-auto mb-4">
                        <Radio className="w-8 h-8 text-red-500" />
                      </div>
                      <p className="text-foreground font-medium mb-2">WhatsApp Service Error</p>
                      <p className="text-sm text-destructive mb-4">{status.error}</p>
                      <div className="p-4 rounded-lg bg-secondary/50 text-left max-w-md mx-auto mb-4">
                        <p className="text-sm font-medium text-foreground mb-2">Troubleshooting:</p>
                        <ol className="text-xs text-muted-foreground list-decimal list-inside space-y-1">
                          <li>Make sure Google Chrome is installed</li>
                          <li>Close all Chrome windows and try again</li>
                          <li>Run <code className="bg-secondary px-1 rounded">scripts\fix-whatsapp.bat</code></li>
                          <li>Check antivirus is not blocking Chrome</li>
                        </ol>
                      </div>
                      <div className="flex gap-2 justify-center">
                        <Button onClick={handleClearSession} disabled={clearingSession}>
                          <Trash2 className="w-4 h-4 mr-2" />
                          Clear Session
                        </Button>
                        <Button onClick={handleRetryInit} variant="outline" disabled={retrying}>
                          <RefreshCw className="w-4 h-4 mr-2" />
                          Retry
                        </Button>
                      </div>
                    </>
                  ) : status?.isInitializing ? (
                    <>
                      <Loader2 className="w-12 h-12 animate-spin text-primary mx-auto mb-4" />
                      <p className="text-foreground font-medium">
                        Initializing WhatsApp...
                      </p>
                      <p className="text-sm text-muted-foreground mt-2">
                        {status.initAttempts > 1 
                          ? `Attempt ${status.initAttempts}/3 - This may take longer...`
                          : 'This may take 30-90 seconds on first run'
                        }
                      </p>
                      <div className="mt-4 w-64 bg-secondary rounded-full h-2 overflow-hidden">
                        <div className="bg-primary h-2 animate-pulse" style={{ width: '60%' }}></div>
                      </div>
                    </>
                  ) : (
                    <>
                      <Loader2 className="w-8 h-8 animate-spin text-primary mx-auto mb-4" />
                      <p className="text-muted-foreground">
                        Starting WhatsApp service...
                      </p>
                      <p className="text-xs text-muted-foreground mt-2">
                        Please wait...
                      </p>
                    </>
                  )}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {status?.isReady && (
        <Card className="bg-card border-border">
          <CardContent className="py-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Disconnect WhatsApp</p>
                <p className="text-sm text-muted-foreground">
                  Log out from WhatsApp Web session
                </p>
              </div>
              <Button 
                variant="destructive"
                onClick={handleLogout}
                disabled={loggingOut}
                data-testid="logout-whatsapp-btn"
              >
                <LogOut className="w-4 h-4 mr-2" />
                {loggingOut ? 'Logging out...' : 'Disconnect'}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg">How it works</CardTitle>
        </CardHeader>
        <CardContent>
          <ol className="list-decimal list-inside space-y-2 text-muted-foreground">
            <li>Wait for the QR code to appear above (30-90 seconds)</li>
            <li>Open WhatsApp on your phone</li>
            <li>Go to <span className="text-foreground">Settings → Linked Devices</span></li>
            <li>Tap <span className="text-foreground">Link a Device</span></li>
            <li>Scan the QR code with your phone</li>
            <li>Once connected, you can schedule messages!</li>
          </ol>
          <div className="mt-4 p-4 rounded-lg bg-secondary/50">
            <p className="text-sm font-medium text-foreground mb-2">Having trouble?</p>
            <ul className="text-xs text-muted-foreground list-disc list-inside space-y-1">
              <li>Make sure Google Chrome is installed</li>
              <li>Run <code className="bg-background px-1 rounded">scripts\fix-whatsapp.bat</code> to clear session</li>
              <li>Run <code className="bg-background px-1 rounded">scripts\reinstall-whatsapp.bat</code> for a full reinstall</li>
            </ul>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default Connect;
