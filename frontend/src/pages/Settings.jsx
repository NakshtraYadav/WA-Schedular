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
  Github
} from 'lucide-react';
import { getSettings, updateSettings, getTimezoneInfo, checkForUpdates, installUpdate, getAppVersion, getTelegramStatus, testTelegram } from '../api';
import { toast } from 'sonner';
import { useVersionContext } from '../context';

function SettingsPage() {
  const { version: versionInfo, refresh: checkVersion } = useVersionContext() || {};
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
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [checkingUpdate, setCheckingUpdate] = useState(false);
  const [installingUpdate, setInstallingUpdate] = useState(false);

  const fetchUpdateInfo = useCallback(async () => {
    try {
      const updateRes = await checkForUpdates();
      setUpdateInfo(updateRes.data);
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
        const statusRes = await getTelegramStatus();
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
      // Refresh global version context
      if (checkVersion) checkVersion();
    } catch (error) {
      toast.error('Failed to check for updates');
    } finally {
      setCheckingUpdate(false);
    }
  };

  const handleInstallUpdate = async () => {
    setInstallingUpdate(true);
    
    try {
      // Step 1: Show updating
      toast.loading('Pulling latest changes...', { id: 'update' });
      
      const res = await installUpdate();
      
      if (res.data.success) {
        const { restart_type, restart_message, full_restart_required } = res.data;
        
        // Step 2: Show appropriate message based on restart type
        if (full_restart_required) {
          toast.success(
            `Updated to v${res.data.new_version || 'latest'}! ${res.data.files_changed || 0} files changed.`,
            { id: 'update', duration: 3000 }
          );
          toast.warning(restart_message, { duration: 10000 });
        } else if (restart_type === 'frontend_refresh' || restart_type === 'both') {
          toast.success(
            `Updated to v${res.data.new_version || 'latest'}! Refreshing...`,
            { id: 'update', duration: 2000 }
          );
          setTimeout(() => {
            window.location.reload(true);
          }, 1500);
        } else if (restart_type === 'backend_only') {
          toast.success(
            `Updated to v${res.data.new_version || 'latest'}! Backend auto-restarting.`,
            { id: 'update' }
          );
          fetchUpdateInfo();
        } else {
          toast.success(
            `Updated to v${res.data.new_version || 'latest'}! No restart needed.`,
            { id: 'update' }
          );
          fetchUpdateInfo();
        }
      } else {
        toast.error(res.data.error || 'Update failed', { id: 'update' });
      }
    } catch (error) {
      toast.error('Update failed: ' + (error.message || 'Unknown error'), { id: 'update' });
    } finally {
      setInstallingUpdate(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await updateSettings(settings);
      toast.success('Settings saved');
      // Refresh telegram status
      const statusRes = await getTelegramStatus();
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
      
      // Then test using the proper API function
      const response = await testTelegram();
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

          {/* Setup Instructions - Hide when bot is fully configured (has token + chat_id + enabled) */}
          {!(settings.telegram_enabled && settings.telegram_token && settings.telegram_chat_id) && (
            <div className="p-4 rounded-lg bg-blue-500/10 border border-blue-500/20">
              <h4 className="font-medium text-blue-500 mb-3 flex items-center gap-2">
                <AlertCircle className="w-4 h-4" />
                Setup Instructions
              </h4>
              <ol className="text-sm text-muted-foreground space-y-2 list-decimal list-inside">
                <li>Open Telegram and search for <a href="https://t.me/BotFather" target="_blank" rel="noopener noreferrer" className="text-primary hover:underline">@BotFather</a></li>
                <li>Send <code className="bg-muted px-1 rounded">/newbot</code> and follow the prompts</li>
                <li>Copy the bot token and paste it above</li>
                <li>Click Test to verify the connection</li>
                <li>Open your new bot in Telegram and send <code className="bg-muted px-1 rounded">/start</code></li>
                <li>Enable the toggle above and save settings</li>
              </ol>
            </div>
          )}

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
              <Badge className="bg-green-500">
                {updateInfo?.update_type === 'major' ? 'Major Update' : 
                 updateInfo?.update_type === 'minor' ? 'Update Available' : 'Patch Available'}
              </Badge>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Version Info */}
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 rounded-lg bg-secondary/30">
              <p className="text-xs text-muted-foreground mb-1">Current Version</p>
              <p className="font-mono font-semibold text-lg">
                v{updateInfo?.local?.version || versionInfo?.version || '1.0.0'}
              </p>
              <p className="text-xs text-muted-foreground">
                Build {updateInfo?.local?.build || versionInfo?.build || 1}
                {updateInfo?.local?.sha && updateInfo.local.sha !== 'none' && (
                  <span className="ml-2">({updateInfo.local.sha})</span>
                )}
              </p>
            </div>
            <div className="p-4 rounded-lg bg-secondary/30">
              <p className="text-xs text-muted-foreground mb-1">Latest on GitHub</p>
              {updateInfo?.remote?.build ? (
                <>
                  <p className="font-mono font-semibold text-lg text-primary">
                    v{updateInfo.remote.version}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    Build {updateInfo.remote.build}
                    {updateInfo.remote.sha && <span className="ml-2">({updateInfo.remote.sha})</span>}
                  </p>
                </>
              ) : (
                <>
                  <p className="font-mono font-semibold text-sm text-muted-foreground">
                    {updateInfo?.remote?.sha || '...'}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    No version.json in repo yet
                  </p>
                </>
              )}
              {updateInfo?.commit_message && (
                <p className="text-xs text-muted-foreground mt-1 truncate" title={updateInfo.commit_message}>
                  Latest: {updateInfo.commit_message}
                </p>
              )}
            </div>
          </div>

          {/* Changelog Preview */}
          {updateInfo?.has_update && updateInfo?.remote?.changelog?.length > 0 && (
            <div className="p-4 rounded-lg bg-green-500/10 border border-green-500/20">
              <h4 className="font-medium text-green-500 mb-2">What's New in v{updateInfo.remote.version}</h4>
              <ul className="text-sm text-muted-foreground space-y-1">
                {updateInfo.remote.changelog[0]?.changes?.slice(0, 5).map((change, i) => (
                  <li key={i} className="flex items-start gap-2">
                    <span className="text-green-500">•</span>
                    {change}
                  </li>
                ))}
              </ul>
            </div>
          )}

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
          <div className="space-y-3 text-sm text-muted-foreground">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-foreground">WA Scheduler</span>
              <span className="font-mono text-primary">
                v{versionInfo?.version || "1.0.0"}
                {versionInfo?.git_sha && versionInfo.git_sha !== "unknown" && (
                  <span className="text-muted-foreground text-xs ml-1">({versionInfo.git_sha})</span>
                )}
              </span>
            </div>
            <p>A local tool for scheduling WhatsApp messages with Telegram remote control.</p>
            <div className="pt-2 border-t border-border">
              <div className="grid grid-cols-2 gap-2 text-xs">
                <div>
                  <span className="text-muted-foreground">App Name:</span>
                  <span className="ml-2 text-foreground">{versionInfo?.app_name || "WhatsApp Scheduler"}</span>
                </div>
                <div>
                  <span className="text-muted-foreground">Build Date:</span>
                  <span className="ml-2 text-foreground">{versionInfo?.release_date || "N/A"}</span>
                </div>
              </div>
            </div>
            <p className="text-xs mt-4 p-3 bg-amber-500/10 border border-amber-500/20 rounded-lg">
              <strong className="text-amber-500">Note:</strong> WhatsApp Web automation should be used responsibly. 
              Excessive automated messaging may result in account restrictions.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default SettingsPage;
