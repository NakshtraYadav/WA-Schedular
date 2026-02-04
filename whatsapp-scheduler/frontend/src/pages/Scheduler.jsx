import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
import { Input } from '../components/ui/input';
import { Badge } from '../components/ui/badge';
import { Switch } from '../components/ui/switch';
import { Calendar } from '../components/ui/calendar';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '../components/ui/popover';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '../components/ui/dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { 
  Plus, 
  Trash2, 
  Calendar as CalendarIcon,
  Clock,
  Repeat
} from 'lucide-react';
import { getSchedules, createSchedule, toggleSchedule, deleteSchedule, getContacts, getTemplates } from '../lib/api';
import { toast } from 'sonner';
import { format } from 'date-fns';

const CRON_PRESETS = [
  { label: 'Every day at 9 AM', value: '0 9 * * *', description: 'Daily at 9:00 AM' },
  { label: 'Every Monday at 9 AM', value: '0 9 * * 1', description: 'Weekly on Monday' },
  { label: 'Every weekday at 9 AM', value: '0 9 * * 1-5', description: 'Mon-Fri at 9:00 AM' },
  { label: 'First day of month', value: '0 9 1 * *', description: 'Monthly on the 1st' },
  { label: 'Every hour', value: '0 * * * *', description: 'Every hour at :00' },
  { label: 'Custom', value: 'custom', description: 'Enter custom cron' },
];

function Scheduler() {
  const [schedules, setSchedules] = useState([]);
  const [contacts, setContacts] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [scheduleType, setScheduleType] = useState('once');
  const [selectedDate, setSelectedDate] = useState(null);
  const [selectedTime, setSelectedTime] = useState('09:00');
  const [selectedCronPreset, setSelectedCronPreset] = useState('');
  const [customCron, setCustomCron] = useState('');
  const [formData, setFormData] = useState({
    contact_id: '',
    message: '',
  });

  const fetchData = useCallback(async () => {
    try {
      const [schedulesRes, contactsRes, templatesRes] = await Promise.all([
        getSchedules(),
        getContacts(),
        getTemplates()
      ]);
      setSchedules(schedulesRes.data);
      setContacts(contactsRes.data);
      setTemplates(templatesRes.data);
    } catch (error) {
      toast.error('Failed to fetch data');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!formData.contact_id || !formData.message) {
      toast.error('Please select a contact and enter a message');
      return;
    }

    try {
      const data = {
        contact_id: formData.contact_id,
        message: formData.message,
        schedule_type: scheduleType,
      };

      if (scheduleType === 'once') {
        if (!selectedDate) {
          toast.error('Please select a date');
          return;
        }
        const [hours, minutes] = selectedTime.split(':');
        const scheduledTime = new Date(selectedDate);
        scheduledTime.setHours(parseInt(hours), parseInt(minutes), 0, 0);
        data.scheduled_time = scheduledTime.toISOString();
      } else {
        const cronValue = selectedCronPreset === 'custom' ? customCron : selectedCronPreset;
        if (!cronValue) {
          toast.error('Please select a schedule pattern');
          return;
        }
        data.cron_expression = cronValue;
        const preset = CRON_PRESETS.find(p => p.value === selectedCronPreset);
        data.cron_description = preset?.description || 'Custom schedule';
      }

      await createSchedule(data);
      toast.success('Schedule created');
      setDialogOpen(false);
      resetForm();
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Failed to create schedule');
    }
  };

  const resetForm = () => {
    setFormData({ contact_id: '', message: '' });
    setScheduleType('once');
    setSelectedDate(null);
    setSelectedTime('09:00');
    setSelectedCronPreset('');
    setCustomCron('');
  };

  const handleToggle = async (id) => {
    try {
      await toggleSchedule(id);
      toast.success('Schedule updated');
      fetchData();
    } catch (error) {
      toast.error('Failed to update schedule');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this schedule?')) return;
    try {
      await deleteSchedule(id);
      toast.success('Schedule deleted');
      fetchData();
    } catch (error) {
      toast.error('Failed to delete schedule');
    }
  };

  const useTemplate = (templateId) => {
    const template = templates.find(t => t.id === templateId);
    if (template) {
      setFormData({ ...formData, message: template.content });
    }
  };

  return (
    <div data-testid="scheduler-page" className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">Scheduler</h1>
          <p className="text-muted-foreground mt-1">Schedule one-time and recurring messages</p>
        </div>
        <Button 
          onClick={() => {
            resetForm();
            setDialogOpen(true);
          }}
          className="btn-glow"
          disabled={contacts.length === 0}
          data-testid="add-schedule-btn"
        >
          <Plus className="w-4 h-4 mr-2" />
          New Schedule
        </Button>
      </div>

      {contacts.length === 0 && (
        <Card className="bg-amber-500/10 border-amber-500/30">
          <CardContent className="py-4">
            <p className="text-amber-500 text-sm">Add contacts first before creating schedules</p>
          </CardContent>
        </Card>
      )}

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg flex items-center gap-2">
            <CalendarIcon className="w-5 h-5" />
            Scheduled Messages ({schedules.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          {schedules.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Contact</TableHead>
                  <TableHead>Message</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Schedule</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {schedules.map((schedule) => (
                  <TableRow key={schedule.id} data-testid={`schedule-row-${schedule.id}`}>
                    <TableCell className="font-medium">{schedule.contact_name}</TableCell>
                    <TableCell className="max-w-[200px] truncate text-muted-foreground">
                      {schedule.message}
                    </TableCell>
                    <TableCell>
                      <Badge variant={schedule.schedule_type === 'recurring' ? 'default' : 'secondary'}>
                        {schedule.schedule_type === 'recurring' ? (
                          <span className="flex items-center"><Repeat className="w-3 h-3 mr-1" /> Recurring</span>
                        ) : (
                          <span className="flex items-center"><Clock className="w-3 h-3 mr-1" /> Once</span>
                        )}
                      </Badge>
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {schedule.schedule_type === 'once' && schedule.scheduled_time
                        ? format(new Date(schedule.scheduled_time), 'MMM d, yyyy HH:mm')
                        : schedule.cron_description || schedule.cron_expression
                      }
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Switch
                          checked={schedule.is_active}
                          onCheckedChange={() => handleToggle(schedule.id)}
                          data-testid={`toggle-schedule-${schedule.id}`}
                        />
                        <span className={schedule.is_active ? 'text-emerald-500' : 'text-muted-foreground'}>
                          {schedule.is_active ? 'Active' : 'Paused'}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button 
                        variant="ghost" 
                        size="sm"
                        onClick={() => handleDelete(schedule.id)}
                        className="text-destructive hover:text-destructive"
                        data-testid={`delete-schedule-${schedule.id}`}
                      >
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-12">
              <CalendarIcon className="w-12 h-12 mx-auto text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No scheduled messages</p>
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="bg-card border-border max-w-lg" data-testid="schedule-dialog">
          <DialogHeader>
            <DialogTitle className="font-heading">Create Schedule</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label>Contact</Label>
              <Select
                value={formData.contact_id}
                onValueChange={(value) => setFormData({ ...formData, contact_id: value })}
              >
                <SelectTrigger data-testid="select-contact">
                  <SelectValue placeholder="Select contact" />
                </SelectTrigger>
                <SelectContent>
                  {contacts.map((contact) => (
                    <SelectItem key={contact.id} value={contact.id}>
                      {contact.name} ({contact.phone})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label>Message</Label>
                {templates.length > 0 && (
                  <Select onValueChange={useTemplate}>
                    <SelectTrigger className="w-[180px] h-8" data-testid="select-template">
                      <SelectValue placeholder="Use template" />
                    </SelectTrigger>
                    <SelectContent>
                      {templates.map((template) => (
                        <SelectItem key={template.id} value={template.id}>
                          {template.title}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              </div>
              <Textarea
                value={formData.message}
                onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                placeholder="Type your message..."
                rows={4}
                required
                data-testid="schedule-message-input"
              />
            </div>

            <div className="space-y-2">
              <Label>Schedule Type</Label>
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant={scheduleType === 'once' ? 'default' : 'outline'}
                  size="sm"
                  onClick={() => setScheduleType('once')}
                  data-testid="schedule-type-once"
                >
                  <Clock className="w-4 h-4 mr-2" />
                  One-time
                </Button>
                <Button
                  type="button"
                  variant={scheduleType === 'recurring' ? 'default' : 'outline'}
                  size="sm"
                  onClick={() => setScheduleType('recurring')}
                  data-testid="schedule-type-recurring"
                >
                  <Repeat className="w-4 h-4 mr-2" />
                  Recurring
                </Button>
              </div>
            </div>

            {scheduleType === 'once' && (
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Date</Label>
                  <Popover>
                    <PopoverTrigger asChild>
                      <Button
                        variant="outline"
                        className="w-full justify-start text-left font-normal"
                        data-testid="select-date"
                      >
                        <CalendarIcon className="mr-2 h-4 w-4" />
                        {selectedDate ? format(selectedDate, 'PPP') : 'Pick date'}
                      </Button>
                    </PopoverTrigger>
                    <PopoverContent className="w-auto p-0 bg-card border-border">
                      <Calendar
                        mode="single"
                        selected={selectedDate}
                        onSelect={setSelectedDate}
                        disabled={(date) => date < new Date()}
                        initialFocus
                      />
                    </PopoverContent>
                  </Popover>
                </div>
                <div className="space-y-2">
                  <Label>Time</Label>
                  <Input
                    type="time"
                    value={selectedTime}
                    onChange={(e) => setSelectedTime(e.target.value)}
                    className="font-mono"
                    data-testid="select-time"
                  />
                </div>
              </div>
            )}

            {scheduleType === 'recurring' && (
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label>Schedule Pattern</Label>
                  <Select
                    value={selectedCronPreset}
                    onValueChange={setSelectedCronPreset}
                  >
                    <SelectTrigger data-testid="select-cron-preset">
                      <SelectValue placeholder="Select pattern" />
                    </SelectTrigger>
                    <SelectContent>
                      {CRON_PRESETS.map((preset) => (
                        <SelectItem key={preset.value} value={preset.value}>
                          {preset.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                {selectedCronPreset === 'custom' && (
                  <div className="space-y-2">
                    <Label>Custom Cron Expression</Label>
                    <Input
                      value={customCron}
                      onChange={(e) => setCustomCron(e.target.value)}
                      placeholder="* * * * *"
                      className="font-mono"
                      data-testid="custom-cron-input"
                    />
                    <p className="text-xs text-muted-foreground">
                      Format: minute hour day month weekday
                    </p>
                  </div>
                )}
              </div>
            )}

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" className="btn-glow" data-testid="create-schedule-btn">
                Create Schedule
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default Scheduler;
