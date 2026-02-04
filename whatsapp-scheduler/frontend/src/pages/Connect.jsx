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
  Zap
} from 'lucide-react';
import { getWhatsAppStatus, getWhatsAppQR, logoutWhatsApp, simulateConnect } from '../lib/api';
import { toast } from 'sonner';

function Connect() {
  const [status, setStatus] = useState(null);
  const [qrCode, setQrCode] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [connecting, setConnecting] = useState(false);

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

  const handleSimulateConnect = async () => {
    setConnecting(true);
    try {
      await simulateConnect();
      toast.success('WhatsApp connected (simulation mode)');
      fetchStatus();
    } catch (error) {
      toast.error('Failed to connect');
    } finally {
      setConnecting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

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
                  : 'bg-red-500/20'
            }`}>
              {status?.isReady ? (
                <CheckCircle className="w-8 h-8 text-emerald-500" />
              ) : status?.hasQrCode ? (
                <Smartphone className="w-8 h-8 text-amber-500" />
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
                  {status?.isReady ? 'Connected' : status?.hasQrCode ? 'Waiting for scan' : 'Disconnected'}
                </Badge>
                {status?.simulationMode && (
                  <Badge variant="outline" className="text-amber-500 border-amber-500">
                    Simulation
                  </Badge>
                )}
              </div>
              {status?.isReady && status?.clientInfo && (
                <p className="text-muted-foreground mt-1">
                  Logged in as <span className="font-medium text-foreground">{status.clientInfo.pushname}</span>
                </p>
              )}
              {status?.clientInfo?.wid && (
                <p className="text-xs font-mono text-muted-foreground mt-1">
                  {status.clientInfo.wid}
                </p>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

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
                    {status?.simulationMode && (
                      <div className="mb-4">
                        <Badge variant="secondary" className="mb-2">Simulation Mode</Badge>
                        <p className="text-sm text-muted-foreground mb-3">
                          Click below to simulate WhatsApp connection for demo purposes.
                        </p>
                        <Button
                          onClick={handleSimulateConnect}
                          disabled={connecting}
                          className="btn-glow"
                          data-testid="simulate-connect-btn"
                        >
                          <Zap className="w-4 h-4 mr-2" />
                          {connecting ? 'Connecting...' : 'Simulate Connection'}
                        </Button>
                      </div>
                    )}
                    {!status?.simulationMode && (
                      <>
                        <p className="text-muted-foreground">
                          Open WhatsApp on your phone
                        </p>
                        <p className="text-sm text-muted-foreground mt-1">
                          Go to <span className="font-medium text-foreground">Settings → Linked Devices → Link a Device</span>
                        </p>
                        <p className="text-sm text-muted-foreground mt-1">
                          Point your phone at this screen to capture the QR code
                        </p>
                      </>
                    )}
                  </div>
                </>
              ) : (
                <div className="text-center py-8">
                  {status?.error ? (
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
                          <li>Delete the .wwebjs_auth folder in whatsapp-service</li>
                          <li>Check antivirus is not blocking Chrome</li>
                        </ol>
                      </div>
                      <Button onClick={fetchStatus} variant="outline">
                        <RefreshCw className="w-4 h-4 mr-2" />
                        Retry Connection
                      </Button>
                    </>
                  ) : (
                    <>
                      <Loader2 className="w-8 h-8 animate-spin text-primary mx-auto mb-4" />
                      <p className="text-muted-foreground">
                        Initializing WhatsApp...
                      </p>
                      <p className="text-xs text-muted-foreground mt-2">
                        This may take up to 60 seconds on first run
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
            <li>Wait for the QR code to appear above</li>
            <li>Open WhatsApp on your phone</li>
            <li>Go to <span className="text-foreground">Settings → Linked Devices</span></li>
            <li>Tap <span className="text-foreground">Link a Device</span></li>
            <li>Scan the QR code with your phone</li>
            <li>Once connected, you can schedule messages!</li>
          </ol>
          <div className="mt-4 p-4 rounded-lg bg-amber-500/10 border border-amber-500/30">
            <p className="text-sm text-amber-500">
              Note: This environment runs in simulation mode. For real WhatsApp integration, 
              download the code and run it on your local Windows PC with Chrome installed.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default Connect;
