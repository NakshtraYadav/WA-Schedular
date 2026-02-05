import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
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
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '../components/ui/dialog';
import { 
  Plus, 
  Pencil, 
  Trash2, 
  Users,
  Phone,
  Send,
  RefreshCw,
  Download,
  Loader2,
  CheckCircle,
  XCircle,
  AlertCircle,
  ShieldCheck
} from 'lucide-react';
import { getContacts, createContact, updateContact, deleteContact, sendNow, getWhatsAppStatus, syncWhatsAppContacts, verifyBulkNumbers } from '../api';
import { toast } from 'sonner';

function Contacts() {
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [sendDialogOpen, setSendDialogOpen] = useState(false);
  const [selectedContact, setSelectedContact] = useState(null);
  const [formData, setFormData] = useState({ name: '', phone: '', notes: '' });
  const [sendMessage, setSendMessage] = useState('');
  const [waConnected, setWaConnected] = useState(false);

  const fetchContacts = useCallback(async () => {
    try {
      const [contactsRes, statusRes] = await Promise.all([
        getContacts(),
        getWhatsAppStatus()
      ]);
      setContacts(contactsRes.data);
      setWaConnected(statusRes.data?.isReady || false);
    } catch (error) {
      toast.error('Failed to fetch contacts');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchContacts();
  }, [fetchContacts]);

  const handleSyncContacts = async () => {
    if (!waConnected) {
      toast.error('WhatsApp is not connected. Please connect first.');
      return;
    }
    
    setSyncing(true);
    const toastId = toast.loading('Syncing WhatsApp contacts...');
    
    try {
      const res = await syncWhatsAppContacts();
      toast.dismiss(toastId);
      
      if (res.data.success) {
        toast.success(res.data.message || `Imported ${res.data.imported} contacts`);
        fetchContacts();
      } else {
        toast.error(res.data.error || 'Failed to sync contacts');
      }
    } catch (error) {
      toast.dismiss(toastId);
      toast.error('Failed to sync contacts');
    } finally {
      setSyncing(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (selectedContact) {
        await updateContact(selectedContact.id, formData);
        toast.success('Contact updated');
      } else {
        await createContact(formData);
        toast.success('Contact created');
      }
      setDialogOpen(false);
      setFormData({ name: '', phone: '', notes: '' });
      setSelectedContact(null);
      fetchContacts();
    } catch (error) {
      toast.error('Failed to save contact');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this contact?')) return;
    try {
      await deleteContact(id);
      toast.success('Contact deleted');
      fetchContacts();
    } catch (error) {
      toast.error('Failed to delete contact');
    }
  };

  const handleEdit = (contact) => {
    setSelectedContact(contact);
    setFormData({ name: contact.name, phone: contact.phone, notes: contact.notes || '' });
    setDialogOpen(true);
  };

  const handleSendNow = async () => {
    if (!selectedContact || !sendMessage.trim()) return;
    try {
      const result = await sendNow(selectedContact.id, sendMessage);
      if (result.data.success) {
        toast.success('Message sent!');
        setSendDialogOpen(false);
        setSendMessage('');
        setSelectedContact(null);
      } else {
        toast.error(result.data.error || 'Failed to send message');
      }
    } catch (error) {
      toast.error('Failed to send message');
    }
  };

  const openSendDialog = (contact) => {
    setSelectedContact(contact);
    setSendMessage('');
    setSendDialogOpen(true);
  };

  return (
    <div data-testid="contacts-page" className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">Contacts</h1>
          <p className="text-muted-foreground mt-1">Manage your WhatsApp contacts</p>
        </div>
        <div className="flex gap-3">
          <Button 
            variant="outline"
            onClick={handleSyncContacts}
            disabled={syncing || !waConnected}
            data-testid="sync-contacts-btn"
            title={!waConnected ? "Connect WhatsApp first" : "Import contacts from WhatsApp"}
          >
            {syncing ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Download className="w-4 h-4 mr-2" />}
            Sync from WhatsApp
          </Button>
          <Button 
            onClick={() => {
              setSelectedContact(null);
              setFormData({ name: '', phone: '', notes: '' });
              setDialogOpen(true);
            }}
            className="btn-glow"
            data-testid="add-contact-btn"
          >
            <Plus className="w-4 h-4 mr-2" />
            Add Contact
          </Button>
        </div>
      </div>

      <Card className="bg-card border-border">
        <CardHeader>
          <CardTitle className="font-heading text-lg flex items-center gap-2">
            <Users className="w-5 h-5" />
            All Contacts ({contacts.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          {contacts.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Phone</TableHead>
                  <TableHead>Notes</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {contacts.map((contact) => (
                  <TableRow key={contact.id} data-testid={`contact-row-${contact.id}`}>
                    <TableCell className="font-medium">{contact.name}</TableCell>
                    <TableCell>
                      <span className="font-mono text-sm">{contact.phone}</span>
                    </TableCell>
                    <TableCell className="text-muted-foreground max-w-[200px] truncate">
                      {contact.notes || '-'}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-2">
                        {waConnected && (
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => openSendDialog(contact)}
                            data-testid={`send-now-${contact.id}`}
                          >
                            <Send className="w-4 h-4" />
                          </Button>
                        )}
                        <Button 
                          variant="ghost" 
                          size="sm"
                          onClick={() => handleEdit(contact)}
                          data-testid={`edit-contact-${contact.id}`}
                        >
                          <Pencil className="w-4 h-4" />
                        </Button>
                        <Button 
                          variant="ghost" 
                          size="sm"
                          onClick={() => handleDelete(contact.id)}
                          className="text-destructive hover:text-destructive"
                          data-testid={`delete-contact-${contact.id}`}
                        >
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-12">
              <Users className="w-12 h-12 mx-auto text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No contacts yet</p>
              <Button 
                onClick={() => setDialogOpen(true)} 
                variant="link" 
                className="mt-2"
              >
                Add your first contact
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="bg-card border-border" data-testid="contact-dialog">
          <DialogHeader>
            <DialogTitle className="font-heading">
              {selectedContact ? 'Edit Contact' : 'Add Contact'}
            </DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Name</Label>
              <Input
                id="name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="John Doe"
                required
                data-testid="contact-name-input"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="phone">Phone Number</Label>
              <div className="relative">
                <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  id="phone"
                  value={formData.phone}
                  onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                  placeholder="+1234567890"
                  className="pl-10 font-mono"
                  required
                  data-testid="contact-phone-input"
                />
              </div>
              <p className="text-xs text-muted-foreground">Include country code (e.g., +1 for US)</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">Notes (Optional)</Label>
              <Textarea
                id="notes"
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                placeholder="Any notes about this contact..."
                rows={3}
                data-testid="contact-notes-input"
              />
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" className="btn-glow" data-testid="save-contact-btn">
                {selectedContact ? 'Update' : 'Add Contact'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <Dialog open={sendDialogOpen} onOpenChange={setSendDialogOpen}>
        <DialogContent className="bg-card border-border" data-testid="send-message-dialog">
          <DialogHeader>
            <DialogTitle className="font-heading">
              Send Message to {selectedContact?.name}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>Phone</Label>
              <p className="font-mono text-sm text-muted-foreground">{selectedContact?.phone}</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="message">Message</Label>
              <Textarea
                id="message"
                value={sendMessage}
                onChange={(e) => setSendMessage(e.target.value)}
                placeholder="Type your message..."
                rows={4}
                data-testid="send-message-input"
              />
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setSendDialogOpen(false)}>
                Cancel
              </Button>
              <Button 
                onClick={handleSendNow} 
                className="btn-glow"
                disabled={!sendMessage.trim()}
                data-testid="confirm-send-btn"
              >
                <Send className="w-4 h-4 mr-2" />
                Send Now
              </Button>
            </DialogFooter>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default Contacts;
