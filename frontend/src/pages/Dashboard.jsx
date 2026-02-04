import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { 
  Users, 
  MessageSquare, 
  Calendar, 
  Send, 
  CheckCircle, 
  XCircle,
  Radio,
  RefreshCw,
  ArrowRight
} from 'lucide-react';
import { getDashboardStats, getWhatsAppStatus } from '../api';
import { useNavigate } from 'react-router-dom';
import { format } from 'date-fns';

function Dashboard() {
  const [stats, setStats] = useState(null);
  const [waStatus, setWaStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const fetchData = useCallback(async () => {
    try {
      const [statsRes, statusRes] = await Promise.all([
        getDashboardStats(),
        getWhatsAppStatus()
      ]);
      setStats(statsRes.data);
      setWaStatus(statusRes.data);
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, [fetchData]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  const isConnected = waStatus && waStatus.isReady;
  const hasQrCode = waStatus && waStatus.hasQrCode;
  const clientName = waStatus && waStatus.clientInfo ? waStatus.clientInfo.pushname : 'User';
  
  const contactsCount = stats ? stats.contacts_count : 0;
  const templatesCount = stats ? stats.templates_count : 0;
  const activeSchedules = stats ? stats.active_schedules : 0;
  const sentMessages = stats ? stats.sent_messages : 0;
  const failedMessages = stats ? stats.failed_messages : 0;
  const recentLogs = stats && stats.recent_logs ? stats.recent_logs : [];
  const upcomingSchedules = stats && stats.upcoming_schedules ? stats.upcoming_schedules : [];

  return (
    <div data-testid="dashboard-page" className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">Dashboard</h1>
          <p className="text-muted-foreground mt-1">WhatsApp Scheduler Command Center</p>
        </div>
        <Button 
          onClick={fetchData} 
          variant="outline" 
          size="sm"
          data-testid="refresh-dashboard-btn"
        >
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      <Card className="bg-card border-border card-hover">
        <CardContent className="p-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${
                isConnected ? 'bg-emerald-500/20' : 'bg-red-500/20'
              }`}>
                <Radio className={`w-6 h-6 ${
                  isConnected ? 'text-emerald-500' : 'text-red-500'
                }`} />
              </div>
              <div>
                <h3 className="font-heading font-bold text-lg">WhatsApp Connection</h3>
                <div className="flex items-center gap-2 mt-1">
                  <span className={
                    isConnected ? 'status-dot-connected' : 
                    hasQrCode ? 'status-dot-pending' : 'status-dot-disconnected'
                  } />
                  <span className="text-sm text-muted-foreground">
                    {isConnected 
                      ? `Connected as ${clientName}`
                      : hasQrCode 
                        ? 'Waiting for QR scan...'
                        : 'Not connected'
                    }
                  </span>
                </div>
              </div>
            </div>
            <Button 
              onClick={() => navigate('/connect')}
              variant={isConnected ? 'secondary' : 'default'}
              className={!isConnected ? 'btn-glow' : ''}
              data-testid="connect-whatsapp-btn"
            >
              {isConnected ? 'Manage' : 'Connect'}
              <ArrowRight className="w-4 h-4 ml-2" />
            </Button>
          </div>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card className="bg-card border-border card-hover" data-testid="stat-contacts">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Contacts</CardTitle>
            <Users className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-heading font-bold">{contactsCount}</div>
          </CardContent>
        </Card>

        <Card className="bg-card border-border card-hover" data-testid="stat-templates">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Templates</CardTitle>
            <MessageSquare className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-heading font-bold">{templatesCount}</div>
          </CardContent>
        </Card>

        <Card className="bg-card border-border card-hover" data-testid="stat-schedules">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Active Schedules</CardTitle>
            <Calendar className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-heading font-bold">{activeSchedules}</div>
          </CardContent>
        </Card>

        <Card className="bg-card border-border card-hover" data-testid="stat-messages">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Messages Sent</CardTitle>
            <Send className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-heading font-bold">{sentMessages}</div>
            {failedMessages > 0 && (
              <p className="text-xs text-destructive mt-1">
                {failedMessages} failed
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="bg-card border-border" data-testid="recent-messages-card">
          <CardHeader>
            <CardTitle className="font-heading text-lg">Recent Messages</CardTitle>
          </CardHeader>
          <CardContent>
            {recentLogs.length > 0 ? (
              <div className="space-y-3">
                {recentLogs.map((log) => (
                  <div key={log.id} className="flex items-center justify-between p-3 rounded-lg bg-secondary/50">
                    <div className="flex items-center gap-3">
                      {log.status === 'sent' ? (
                        <CheckCircle className="w-4 h-4 text-emerald-500" />
                      ) : (
                        <XCircle className="w-4 h-4 text-destructive" />
                      )}
                      <div>
                        <p className="font-medium text-sm">{log.contact_name}</p>
                        <p className="text-xs text-muted-foreground truncate max-w-[200px]">
                          {log.message}
                        </p>
                      </div>
                    </div>
                    <span className="text-xs font-mono text-muted-foreground">
                      {format(new Date(log.sent_at), 'HH:mm')}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-muted-foreground text-sm text-center py-8">No recent messages</p>
            )}
          </CardContent>
        </Card>

        <Card className="bg-card border-border" data-testid="upcoming-schedules-card">
          <CardHeader>
            <CardTitle className="font-heading text-lg">Upcoming Schedules</CardTitle>
          </CardHeader>
          <CardContent>
            {upcomingSchedules.length > 0 ? (
              <div className="space-y-3">
                {upcomingSchedules.map((schedule) => (
                  <div key={schedule.id} className="flex items-center justify-between p-3 rounded-lg bg-secondary/50">
                    <div>
                      <p className="font-medium text-sm">{schedule.contact_name}</p>
                      <p className="text-xs text-muted-foreground truncate max-w-[200px]">
                        {schedule.message}
                      </p>
                    </div>
                    <Badge variant={schedule.schedule_type === 'recurring' ? 'default' : 'secondary'}>
                      {schedule.schedule_type === 'recurring' ? 'Recurring' : 'Once'}
                    </Badge>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-muted-foreground text-sm text-center py-8">No scheduled messages</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

export default Dashboard;
