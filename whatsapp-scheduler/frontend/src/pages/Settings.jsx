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
  AlertCircle
} from 'lucide-react';
import { getSettings, updateSettings, getTimezoneInfo, api } from '../lib/api';
import { toast } from 'sonner';

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
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);

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
    } catch (error) {
      toast.error('Failed to fetch settings');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

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

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg flex items-center gap-2">
            <SettingsIcon className="w-5 h-5" />
            About
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2 text-sm text-muted-foreground">
            <p><strong className="text-foreground">WA Scheduler</strong> v3.0</p>
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
