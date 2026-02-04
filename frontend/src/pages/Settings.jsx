import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Switch } from '../components/ui/switch';
import { Badge } from '../components/ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { 
  Settings as SettingsIcon, 
  Bot,
  Save,
  ExternalLink,
  Clock,
  CheckCircle,
  XCircle,
  Loader2,
  Send,
  AlertCircle,
  Download,
  RefreshCw,
  Github,
  Play,
  Square
} from 'lucide-react';
import { getSettings, updateSettings, getTimezoneInfo, api, checkForUpdates, installUpdate, getAutoUpdaterStatus, controlAutoUpdater, getAppVersion } from '../lib/api';
import { toast } from 'sonner';
import { useVersion } from '../App';

function SettingsPage() {
  const [settings, setSettings] = useState({
    telegram_token: '',
    telegram_chat_id: '',
    telegram_enabled: false,
    timezone: ''
  });
  const [timezoneInfo, setTimezoneInfo] = useState({
    system_timezone: '',
    common_timezones: []
  });
  const [telegramStatus, setTelegramStatus] = useState(null);
  const [updateInfo, setUpdateInfo] = useState(null);
  const [autoUpdaterStatus, setAutoUpdaterStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [checkingUpdate, setCheckingUpdate] = useState(false);
  const [installingUpdate, setInstallingUpdate] = useState(false);

  const fetchUpdateInfo = useCallback(async () => {
    try {
      const [updateRes, autoUpdaterRes] = await Promise.all([
        checkForUpdates(),
        getAutoUpdaterStatus()
      ]);
      setUpdateInfo(updateRes.data);
      setAutoUpdaterStatus(autoUpdaterRes.data);
    } catch (e) {
      console.error('Failed to fetch update info');
    }
  }, []);

  const fetchSettings = useCallback(async () => {
    try {
      const [settingsRes, tzRes] = await Promise.all([
        getSettings(),
        getTimezoneInfo()
      ]);
      setSettings({
        telegram_token: settingsRes.data.telegram_token || '',
        telegram_chat_id: settingsRes.data.telegram_chat_id || '',
        telegram_enabled: settingsRes.data.telegram_enabled || false,
        timezone: settingsRes.data.timezone || tzRes.data.system_timezone || ''
      });
      setTimezoneInfo({
        system_timezone: tzRes.data.system_timezone,
        common_timezones: tzRes.data.common_timezones || []
      });
      
      // Fetch Telegram status
      try {
        const statusRes = await api.get('/telegram/status');
        setTelegramStatus(statusRes.data);
      } catch (e) {
        console.error('Failed to fetch telegram status');
      }
      
      // Fetch update info
      await fetchUpdateInfo();
    } catch (error) {
      toast.error('Failed to fetch settings');
    } finally {
      setLoading(false);
    }
  }, [fetchUpdateInfo]);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  const handleCheckUpdate = async () => {
    setCheckingUpdate(true);
    try {
      const res = await checkForUpdates();
      setUpdateInfo(res.data);
      if (res.data.has_update) {
        toast.success('Update available!');
      } else {
        toast.info('You are up to date');
      }
    } catch (error) {
      toast.error('Failed to check for updates');
    } finally {
      setCheckingUpdate(false);
    }
  };

  const handleInstallUpdate = async () => {
    if (!window.confirm('This will download the latest version and restart all services. Continue?')) {
      return;
    }
    setInstallingUpdate(true);
    try {
      const res = await installUpdate();
      if (res.data.success) {
        toast.success('Update started! Services will restart automatically.');
      } else {
        toast.error(res.data.error || 'Failed to install update');
      }
    } catch (error) {
      toast.error('Failed to install update');
    } finally {
      setInstallingUpdate(false);
    }
  };

  const handleAutoUpdaterControl = async (action) => {
    try {
      const res = await controlAutoUpdater(action);
      if (res.data.success) {
        toast.success(res.data.output || `Auto-updater ${action}ed`);
        fetchUpdateInfo();
      } else {
        toast.error(res.data.error || 'Failed');
      }
    } catch (error) {
      toast.error(`Failed to ${action} auto-updater`);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await updateSettings(settings);
      toast.success('Settings saved');
      // Refresh telegram status
      const statusRes = await api.get('/telegram/status');
      setTelegramStatus(statusRes.data);
    } catch (error) {
      toast.error('Failed to save settings');
    } finally {
      setSaving(false);
    }
  };

  const handleTestTelegram = async () => {
    if (!settings.telegram_token) {
      toast.error('Please enter a bot token first');
      return;
    }
    
    setTesting(true);
    try {
      // Save first to ensure token is stored
      await updateSettings(settings);
      
      // Then test
      const response = await api.post('/telegram/test');
      const result = response.data;
      
      if (result.success) {
        if (result.message_sent) {
          toast.success(`Bot "${result.bot_username}" connected! Test message sent.`);
        } else {
          toast.success(`Bot "${result.bot_username}" connected! Send /start to the bot to receive messages.`);
        }
        // Update chat_id if it was set by /start
        fetchSettings();
      } else {
        toast.error(`Test failed: ${result.error}`);
      }
    } catch (error) {
      toast.error('Test failed: ' + (error.response?.data?.detail || error.message));
    } finally {
      setTesting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div data-testid="settings-page" className="space-y-6 animate-fade-in">
      <div>
        <h1 className="font-heading text-3xl font-bold text-foreground">Settings</h1>
        <p className="text-muted-foreground mt-1">Configure your WA Scheduler</p>
      </div>

      <Card className="bg-card border-border">
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center">
                <Bot className="w-5 h-5 text-blue-500" />
              </div>
              <div>
                <CardTitle className="font-heading text-lg">Telegram Bot</CardTitle>
                <CardDescription>Control your scheduler remotely via Telegram</CardDescription>
              </div>
            </div>
            {telegramStatus && (
              <Badge variant={telegramStatus.polling_active ? "default" : "secondary"}>
                {telegramStatus.polling_active ? (
                  <><CheckCircle className="w-3 h-3 mr-1" /> Active</>
                ) : (
                  <><XCircle className="w-3 h-3 mr-1" /> Inactive</>
                )}
              </Badge>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="flex items-center justify-between p-4 rounded-lg bg-secondary/30">
            <div>
              <Label className="text-base">Enable Telegram Bot</Label>
              <p className="text-sm text-muted-foreground">
                Receive notifications and send commands via Telegram
              </p>
            </div>
            <Switch
              checked={settings.telegram_enabled}
              onCheckedChange={(checked) => setSettings({ ...settings, telegram_enabled: checked })}
              data-testid="telegram-enabled-switch"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="telegram_token">Bot Token</Label>
            <div className="flex gap-2">
              <Input
                id="telegram_token"
                type="password"
                value={settings.telegram_token}
                onChange={(e) => setSettings({ ...settings, telegram_token: e.target.value })}
                placeholder="123456789:ABCdefGHIjklMNOpqrSTUvwxYZ"
                className="font-mono flex-1"
                data-testid="telegram-token-input"
              />
              <Button 
                type="button" 
                variant="outline"
                onClick={handleTestTelegram}
                disabled={testing || !settings.telegram_token}
              >
                {testing ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                Test
              </Button>
            </div>
            <p className="text-xs text-muted-foreground flex items-center gap-1">
              Get your bot token from 
              <a 
                href="https://t.me/BotFather" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-primary hover:underline inline-flex items-center gap-1"
              >
                @BotFather <ExternalLink className="w-3 h-3" />
              </a>
            </p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="telegram_chat_id">Chat ID</Label>
            <Input
              id="telegram_chat_id"
              value={settings.telegram_chat_id}
              onChange={(e) => setSettings({ ...settings, telegram_chat_id: e.target.value })}
              placeholder="Auto-filled when you send /start to bot"
              className="font-mono"
              data-testid="telegram-chat-id-input"
            />
            <p className="text-xs text-muted-foreground">
              {settings.telegram_chat_id ? (
                <span className="text-green-500">✓ Chat ID configured</span>
              ) : (
                <span>Send <code className="bg-muted px-1 rounded">/start</code> to your bot to automatically set this</span>
              )}
            </p>
          </div>

          {/* Setup Instructions */}
          <div className="p-4 rounded-lg bg-blue-500/10 border border-blue-500/20">
            <h4 className="font-medium text-blue-500 mb-3 flex items-center gap-2">
              <AlertCircle className="w-4 h-4" />
              Setup Instructions
            </h4>
            <ol className="text-sm text-muted-foreground space-y-2 list-decimal list-inside">
              <li>Open Telegram and search for <a href="https://t.me/BotFather" target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">@BotFather</a></li>
              <li>Send <code className="bg-muted px-1 rounded">/newbot</code> and follow the prompts</li>
              <li>Copy the bot token and paste it above</li>
              <li>Click "Test" to verify the connection</li>
              <li>Open your new bot in Telegram and send <code className="bg-muted px-1 rounded">/start</code></li>
              <li>Enable the toggle above and save settings</li>
            </ol>
          </div>

          {settings.telegram_enabled && settings.telegram_token && (
            <div className="p-4 rounded-lg bg-secondary/50">
              <h4 className="font-medium mb-2">Available Commands</h4>
              <div className="grid grid-cols-2 gap-2 font-mono text-sm text-muted-foreground">
                <p><span className="text-primary">/start</span> - Initialize bot</p>
                <p><span className="text-primary">/status</span> - WhatsApp status</p>
                <p><span className="text-primary">/contacts</span> - List contacts</p>
                <p><span className="text-primary">/schedules</span> - Active schedules</p>
                <p><span className="text-primary">/logs</span> - Message history</p>
                <p><span className="text-primary">/send name msg</span> - Send now</p>
              </div>
            </div>
          )}

          <Button 
            onClick={handleSave} 
            className="btn-glow"
            disabled={saving}
            data-testid="save-settings-btn"
          >
            <Save className="w-4 h-4 mr-2" />
            {saving ? 'Saving...' : 'Save Telegram Settings'}
          </Button>
        </CardContent>
      </Card>

      <Card className="bg-card border-border">
        <CardHeader>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-orange-500/20 flex items-center justify-center">
              <Clock className="w-5 h-5 text-orange-500" />
            </div>
            <div>
              <CardTitle className="font-heading text-lg">Timezone</CardTitle>
              <CardDescription>Configure timezone for scheduled messages</CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="timezone">Application Timezone</Label>
            <Select 
              value={settings.timezone} 
              onValueChange={(value) => setSettings({ ...settings, timezone: value })}
            >
              <SelectTrigger data-testid="timezone-select" className="w-full">
                <SelectValue placeholder="Select timezone" />
              </SelectTrigger>
              <SelectContent>
                {timezoneInfo.common_timezones.map((tz) => (
                  <SelectItem key={tz} value={tz}>
                    {tz} {tz === timezoneInfo.system_timezone && '(System)'}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              System timezone: <span className="font-mono text-primary">{timezoneInfo.system_timezone}</span>
            </p>
          </div>
          
          <Button 
            onClick={handleSave} 
            variant="outline"
            disabled={saving}
            data-testid="save-timezone-btn"
          >
            <Save className="w-4 h-4 mr-2" />
            {saving ? 'Saving...' : 'Save Timezone'}
          </Button>
        </CardContent>
      </Card>

      {/* Updates Card */}
      <Card className="bg-card border-border">
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-green-500/20 flex items-center justify-center">
                <Download className="w-5 h-5 text-green-500" />
              </div>
              <div>
                <CardTitle className="font-heading text-lg">Updates</CardTitle>
                <CardDescription>Keep your WA Scheduler up to date</CardDescription>
              </div>
            </div>
            {updateInfo?.has_update && (
              <Badge className="bg-green-500">Update Available</Badge>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Version Info */}
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 rounded-lg bg-secondary/30">
              <p className="text-xs text-muted-foreground mb-1">Current Version</p>
              <p className="font-mono font-semibold">
                {updateInfo?.local_version === 'none' ? 'Not tracked' : updateInfo?.local_version || '...'}
              </p>
            </div>
            <div className="p-4 rounded-lg bg-secondary/30">
              <p className="text-xs text-muted-foreground mb-1">Latest Version</p>
              <p className="font-mono font-semibold text-primary">{updateInfo?.remote_version || '...'}</p>
              {updateInfo?.remote_message && (
                <p className="text-xs text-muted-foreground mt-1 truncate" title={updateInfo.remote_message}>
                  {updateInfo.remote_message}
                </p>
              )}
            </div>
          </div>

          {/* Update Actions */}
          <div className="flex gap-3">
            <Button 
              variant="outline" 
              onClick={handleCheckUpdate}
              disabled={checkingUpdate}
            >
              {checkingUpdate ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <RefreshCw className="w-4 h-4 mr-2" />}
              Check for Updates
            </Button>
            
            {updateInfo?.has_update && (
              <Button 
                onClick={handleInstallUpdate}
                disabled={installingUpdate}
                className="btn-glow"
              >
                {installingUpdate ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Download className="w-4 h-4 mr-2" />}
                Install Update
              </Button>
            )}
            
            <a 
              href={`https://github.com/${updateInfo?.repo || 'NakshtraYadav/WA-Schedular'}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button variant="ghost">
                <Github className="w-4 h-4 mr-2" />
                View on GitHub
              </Button>
            </a>
          </div>

          {/* Auto-Updater */}
          <div className="p-4 rounded-lg bg-secondary/30 space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="font-medium">Auto-Updater</h4>
                <p className="text-sm text-muted-foreground">Automatically check for updates every 30 minutes</p>
              </div>
              <Badge variant={autoUpdaterStatus?.is_running ? "default" : "secondary"}>
                {autoUpdaterStatus?.is_running ? (
                  <><CheckCircle className="w-3 h-3 mr-1" /> Running</>
                ) : (
                  <><XCircle className="w-3 h-3 mr-1" /> Stopped</>
                )}
              </Badge>
            </div>
            
            <div className="flex gap-2">
              {autoUpdaterStatus?.is_running ? (
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => handleAutoUpdaterControl('stop')}
                >
                  <Square className="w-4 h-4 mr-2" />
                  Stop Auto-Updater
                </Button>
              ) : (
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => handleAutoUpdaterControl('start')}
                >
                  <Play className="w-4 h-4 mr-2" />
                  Start Auto-Updater
                </Button>
              )}
            </div>
            
            {autoUpdaterStatus?.recent_logs?.length > 0 && (
              <div className="mt-3">
                <p className="text-xs text-muted-foreground mb-2">Recent activity:</p>
                <div className="bg-zinc-950 rounded p-3 font-mono text-xs max-h-32 overflow-y-auto">
                  {autoUpdaterStatus.recent_logs.map((log, i) => (
                    <div key={i} className="text-zinc-400">{log}</div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg flex items-center gap-2">
            <SettingsIcon className="w-5 h-5" />
            About
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2 text-sm text-muted-foreground">
            <p><strong className="text-foreground">WA Scheduler</strong> v3.1</p>
            <p>A local tool for scheduling WhatsApp messages with Telegram remote control.</p>
            <p className="text-xs mt-4">
              Note: WhatsApp Web automation should be used responsibly. 
              Excessive automated messaging may result in account restrictions.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default SettingsPage;
