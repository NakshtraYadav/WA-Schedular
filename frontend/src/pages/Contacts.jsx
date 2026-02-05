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
  ShieldCheck,
  UserX
} from 'lucide-react';
import { getContacts, createContact, updateContact, deleteContact, sendNow, syncWhatsAppContacts, verifyBulkNumbers, deleteUnverifiedContacts } from '../api';
import { useWhatsAppStatus } from '../hooks/useWhatsAppStatus';
import { toast } from 'sonner';

function Contacts() {
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [removingUnverified, setRemovingUnverified] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [verificationResults, setVerificationResults] = useState({}); // { phone: true/false }
  const [dialogOpen, setDialogOpen] = useState(false);
  const [sendDialogOpen, setSendDialogOpen] = useState(false);
  const [selectedContact, setSelectedContact] = useState(null);
  const [formData, setFormData] = useState({ name: '', phone: '', notes: '' });
  const [sendMessage, setSendMessage] = useState('');
  
  // Use shared WhatsApp status hook for consistency with sidebar
  const { status: waStatus } = useWhatsAppStatus();
  const waConnected = waStatus?.isReady || false;

  const fetchContacts = useCallback(async () => {
    try {
      const contactsRes = await getContacts();
      setContacts(contactsRes.data);
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

  const handleVerifyAll = async () => {
    if (!waConnected) {
      toast.error('WhatsApp is not connected. Please connect first.');
      return;
    }

    if (contacts.length === 0) {
      toast.error('No contacts to verify');
      return;
    }

    setVerifying(true);
    const estimatedTime = Math.ceil(contacts.length / 5) * 2; // ~2 seconds per batch of 5
    const toastId = toast.loading(`Verifying ${contacts.length} contacts... (est. ${estimatedTime}s)`);

    try {
      const phones = contacts.map(c => c.phone);
      const res = await verifyBulkNumbers(phones);
      toast.dismiss(toastId);

      if (res.data && res.data.success) {
        const registered = res.data.registered || 0;
        const notRegistered = res.data.notRegistered || 0;
        
        // Refresh contacts to get updated verification status from DB
        await fetchContacts();
        
        if (notRegistered === 0) {
          toast.success(`All ${registered} contacts are on WhatsApp! ✓`);
        } else {
          toast.warning(`${registered} on WhatsApp, ${notRegistered} not found`);
        }
      } else {
        const errorMsg = res.data?.error || 'Verification failed';
        if (errorMsg.toLowerCase().includes('not connected')) {
          toast.error('WhatsApp is not connected. Go to Connect page and scan QR code first.');
        } else if (errorMsg.toLowerCase().includes('timeout')) {
          toast.error('Verification timed out. Try with fewer contacts or check WhatsApp connection.');
        } else {
          toast.error(errorMsg);
        }
      }
    } catch (error) {
      toast.dismiss(toastId);
      let errorMsg = error.response?.data?.error || error.response?.data?.detail || error.message || 'Failed to verify contacts';
      if (error.code === 'ECONNABORTED' || errorMsg.includes('timeout')) {
        errorMsg = `Verification timed out after 3 minutes. You have ${contacts.length} contacts - try verifying fewer at a time.`;
      }
      toast.error(errorMsg);
    } finally {
      setVerifying(false);
    }
  };

  const handleRemoveUnverified = async () => {
    const unverifiedCount = contacts.filter(c => c.is_verified === false).length;
    if (unverifiedCount === 0) {
      toast.info('No unverified contacts to remove');
      return;
    }
    
    if (!window.confirm(`Remove ${unverifiedCount} unverified contacts? This cannot be undone.`)) {
      return;
    }
    
    setRemovingUnverified(true);
    try {
      const res = await deleteUnverifiedContacts();
      if (res.data?.success) {
        toast.success(res.data.message || `Removed ${res.data.deleted_count} contacts`);
        await fetchContacts();
      } else {
        toast.error(res.data?.error || 'Failed to remove contacts');
      }
    } catch (error) {
      toast.error('Failed to remove unverified contacts');
    } finally {
      setRemovingUnverified(false);
    }
  };

  // Get verification status - prioritize DB value, fallback to session results
  const getVerificationStatus = (contact) => {
    // First check if DB has verification status
    if (contact.is_verified === true) return 'verified';
    if (contact.is_verified === false) return 'not_found';
    
    // Fallback to session results (for just-verified contacts before page refresh)
    const phone = contact.phone;
    if (Object.keys(verificationResults).length === 0) return 'unknown';
    const cleanPhone = phone.replace(/[\s\-\+]/g, '');
    if (verificationResults[phone] !== undefined) return verificationResults[phone] ? 'verified' : 'not_found';
    if (verificationResults[cleanPhone] !== undefined) return verificationResults[cleanPhone] ? 'verified' : 'not_found';
    return 'unknown';
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
            onClick={handleVerifyAll}
            disabled={verifying || !waConnected || contacts.length === 0}
            data-testid="verify-contacts-btn"
            title={!waConnected ? "Connect WhatsApp first" : "Check which contacts are on WhatsApp"}
          >
            {verifying ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <ShieldCheck className="w-4 h-4 mr-2" />}
            Verify All
          </Button>
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

      {/* Verification Summary - Show only after verification */}
      {Object.keys(verificationResults).length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-card border-border">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-lg bg-emerald-500/20 flex items-center justify-center">
                  <CheckCircle className="w-5 h-5 text-emerald-500" />
                </div>
                <div>
                  <p className="text-2xl font-bold">
                    {contacts.filter(c => getVerificationStatus(c) === 'verified').length}
                  </p>
                  <p className="text-sm text-muted-foreground">On WhatsApp</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="bg-card border-border">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-lg bg-red-500/20 flex items-center justify-center">
                  <XCircle className="w-5 h-5 text-red-500" />
                </div>
                <div>
                  <p className="text-2xl font-bold">
                    {contacts.filter(c => getVerificationStatus(c) === 'not_found').length}
                  </p>
                  <p className="text-sm text-muted-foreground">Not on WhatsApp</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card className="bg-card border-border">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-lg bg-primary/20 flex items-center justify-center">
                  <Users className="w-5 h-5 text-primary" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{contacts.length}</p>
                  <p className="text-sm text-muted-foreground">Total Contacts</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

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
                  <TableHead>Status</TableHead>
                  <TableHead>Notes</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {contacts.map((contact) => {
                  const status = getVerificationStatus(contact.phone);
                  return (
                  <TableRow key={contact.id} data-testid={`contact-row-${contact.id}`}>
                    <TableCell className="font-medium">{contact.name}</TableCell>
                    <TableCell>
                      <span className="font-mono text-sm">{contact.phone}</span>
                    </TableCell>
                    <TableCell>
                      {status === 'verified' && (
                        <Badge className="bg-emerald-500/20 text-emerald-500 border-0">
                          <CheckCircle className="w-3 h-3 mr-1" />
                          On WhatsApp
                        </Badge>
                      )}
                      {status === 'not_found' && (
                        <Badge variant="destructive" className="bg-red-500/20 text-red-500 border-0">
                          <XCircle className="w-3 h-3 mr-1" />
                          Not Found
                        </Badge>
                      )}
                      {status === 'unknown' && (
                        <Badge variant="outline" className="text-muted-foreground">
                          <AlertCircle className="w-3 h-3 mr-1" />
                          Not Verified
                        </Badge>
                      )}
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
                            disabled={status === 'not_found'}
                            title={status === 'not_found' ? 'Contact not on WhatsApp' : 'Send message'}
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
                  );
                })}
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
