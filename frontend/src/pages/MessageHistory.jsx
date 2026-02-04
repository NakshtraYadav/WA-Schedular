import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { 
  History, 
  CheckCircle, 
  XCircle,
  Trash2,
  RefreshCw
} from 'lucide-react';
import { getLogs, clearLogs } from '../api';
import { toast } from 'sonner';
import { format } from 'date-fns';

function MessageHistory() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchLogs = useCallback(async () => {
    try {
      const res = await getLogs(100);
      setLogs(res.data);
    } catch (error) {
      toast.error('Failed to fetch logs');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  const handleClearLogs = async () => {
    if (!window.confirm('Clear all message history?')) return;
    try {
      await clearLogs();
      toast.success('History cleared');
      fetchLogs();
    } catch (error) {
      toast.error('Failed to clear history');
    }
  };

  return (
    <div data-testid="history-page" className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">Message History</h1>
          <p className="text-muted-foreground mt-1">View all sent messages and their status</p>
        </div>
        <div className="flex gap-2">
          <Button 
            onClick={fetchLogs}
            variant="outline"
            size="sm"
            data-testid="refresh-logs-btn"
          >
            <RefreshCw className="w-4 h-4 mr-2" />
            Refresh
          </Button>
          {logs.length > 0 && (
            <Button 
              onClick={handleClearLogs}
              variant="outline"
              size="sm"
              className="text-destructive hover:text-destructive"
              data-testid="clear-logs-btn"
            >
              <Trash2 className="w-4 h-4 mr-2" />
              Clear All
            </Button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <Card className="bg-card border-border">
          <CardContent className="py-4">
            <div className="text-2xl font-heading font-bold">{logs.length}</div>
            <p className="text-sm text-muted-foreground">Total Messages</p>
          </CardContent>
        </Card>
        <Card className="bg-card border-border">
          <CardContent className="py-4">
            <div className="text-2xl font-heading font-bold text-emerald-500">
              {logs.filter(l => l.status === 'sent').length}
            </div>
            <p className="text-sm text-muted-foreground">Sent</p>
          </CardContent>
        </Card>
        <Card className="bg-card border-border">
          <CardContent className="py-4">
            <div className="text-2xl font-heading font-bold text-destructive">
              {logs.filter(l => l.status === 'failed').length}
            </div>
            <p className="text-sm text-muted-foreground">Failed</p>
          </CardContent>
        </Card>
      </div>

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg flex items-center gap-2">
            <History className="w-5 h-5" />
            Message Log
          </CardTitle>
        </CardHeader>
        <CardContent>
          {logs.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Status</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Phone</TableHead>
                  <TableHead>Message</TableHead>
                  <TableHead>Sent At</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {logs.map((log) => (
                  <TableRow key={log.id} data-testid={`log-row-${log.id}`}>
                    <TableCell>
                      {log.status === 'sent' ? (
                        <Badge className="bg-emerald-500/20 text-emerald-500 border-emerald-500/30">
                          <CheckCircle className="w-3 h-3 mr-1" />
                          Sent
                        </Badge>
                      ) : (
                        <Badge variant="destructive">
                          <XCircle className="w-3 h-3 mr-1" />
                          Failed
                        </Badge>
                      )}
                    </TableCell>
                    <TableCell className="font-medium">{log.contact_name}</TableCell>
                    <TableCell className="font-mono text-sm">{log.contact_phone}</TableCell>
                    <TableCell className="max-w-[250px] truncate text-muted-foreground">
                      {log.message}
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {format(new Date(log.sent_at), 'MMM d, HH:mm:ss')}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-12">
              <History className="w-12 h-12 mx-auto text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No message history yet</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export default MessageHistory;
