import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Switch } from '../components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { 
  Settings as SettingsIcon, 
  Bot,
  Save,
  ExternalLink,
  Clock
} from 'lucide-react';
import { getSettings, updateSettings, getTimezoneInfo } from '../lib/api';
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
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

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
    } catch (error) {
      toast.error('Failed to save settings');
    } finally {
      setSaving(false);
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
        <p className="text-muted-foreground mt-1">Configure your WhatsApp Scheduler</p>
      </div>

      <Card className="bg-card border-border">
        <CardHeader>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center">
              <Bot className="w-5 h-5 text-blue-500" />
            </div>
            <div>
              <CardTitle className="font-heading text-lg">Telegram Bot</CardTitle>
              <CardDescription>Control your scheduler remotely via Telegram</CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="flex items-center justify-between">
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
            <Input
              id="telegram_token"
              type="password"
              value={settings.telegram_token}
              onChange={(e) => setSettings({ ...settings, telegram_token: e.target.value })}
              placeholder="Enter your Telegram bot token"
              className="font-mono"
              data-testid="telegram-token-input"
            />
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
            <Label htmlFor="telegram_chat_id">Chat ID (Optional)</Label>
            <Input
              id="telegram_chat_id"
              value={settings.telegram_chat_id}
              onChange={(e) => setSettings({ ...settings, telegram_chat_id: e.target.value })}
              placeholder="Your Telegram chat ID"
              className="font-mono"
              data-testid="telegram-chat-id-input"
            />
            <p className="text-xs text-muted-foreground">
              Send /start to your bot to automatically set this
            </p>
          </div>

          {settings.telegram_enabled && settings.telegram_token && (
            <div className="p-4 rounded-lg bg-secondary/50">
              <h4 className="font-medium mb-2">Available Commands</h4>
              <div className="space-y-1 font-mono text-sm text-muted-foreground">
                <p><span className="text-primary">/start</span> - Initialize bot</p>
                <p><span className="text-primary">/status</span> - Check WhatsApp connection</p>
                <p><span className="text-primary">/contacts</span> - List all contacts</p>
                <p><span className="text-primary">/schedules</span> - List active schedules</p>
                <p><span className="text-primary">/send name message</span> - Send message now</p>
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
            {saving ? 'Saving...' : 'Save Settings'}
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
            <p><strong className="text-foreground">WhatsApp Scheduler</strong> - Command Center</p>
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
