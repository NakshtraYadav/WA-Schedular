import { useState, useEffect, useCallback } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
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
  MessageSquare,
  Copy
} from 'lucide-react';
import { getTemplates, createTemplate, updateTemplate, deleteTemplate } from '../lib/api';
import { toast } from 'sonner';

function Templates() {
  const [templates, setTemplates] = useState([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [selectedTemplate, setSelectedTemplate] = useState(null);
  const [formData, setFormData] = useState({ title: '', content: '' });

  const fetchTemplates = useCallback(async () => {
    try {
      const res = await getTemplates();
      setTemplates(res.data);
    } catch (error) {
      toast.error('Failed to fetch templates');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTemplates();
  }, [fetchTemplates]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (selectedTemplate) {
        await updateTemplate(selectedTemplate.id, formData);
        toast.success('Template updated');
      } else {
        await createTemplate(formData);
        toast.success('Template created');
      }
      setDialogOpen(false);
      setFormData({ title: '', content: '' });
      setSelectedTemplate(null);
      fetchTemplates();
    } catch (error) {
      toast.error('Failed to save template');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this template?')) return;
    try {
      await deleteTemplate(id);
      toast.success('Template deleted');
      fetchTemplates();
    } catch (error) {
      toast.error('Failed to delete template');
    }
  };

  const handleEdit = (template) => {
    setSelectedTemplate(template);
    setFormData({ title: template.title, content: template.content });
    setDialogOpen(true);
  };

  const copyToClipboard = (content) => {
    navigator.clipboard.writeText(content);
    toast.success('Copied to clipboard');
  };

  return (
    <div data-testid="templates-page" className="space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">Message Templates</h1>
          <p className="text-muted-foreground mt-1">Create reusable message templates</p>
        </div>
        <Button 
          onClick={() => {
            setSelectedTemplate(null);
            setFormData({ title: '', content: '' });
            setDialogOpen(true);
          }}
          className="btn-glow"
          data-testid="add-template-btn"
        >
          <Plus className="w-4 h-4 mr-2" />
          Add Template
        </Button>
      </div>

      {templates.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {templates.map((template) => (
            <Card 
              key={template.id} 
              className="bg-card border-border card-hover"
              data-testid={`template-card-${template.id}`}
            >
              <CardHeader className="pb-2">
                <CardTitle className="font-heading text-lg flex items-center justify-between">
                  <span className="truncate">{template.title}</span>
                  <div className="flex items-center gap-1">
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onClick={() => copyToClipboard(template.content)}
                      data-testid={`copy-template-${template.id}`}
                    >
                      <Copy className="w-4 h-4" />
                    </Button>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onClick={() => handleEdit(template)}
                      data-testid={`edit-template-${template.id}`}
                    >
                      <Pencil className="w-4 h-4" />
                    </Button>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onClick={() => handleDelete(template.id)}
                      className="text-destructive hover:text-destructive"
                      data-testid={`delete-template-${template.id}`}
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground whitespace-pre-wrap line-clamp-4">
                  {template.content}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <Card className="bg-card border-border">
          <CardContent className="py-12">
            <div className="text-center">
              <MessageSquare className="w-12 h-12 mx-auto text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No templates yet</p>
              <Button 
                onClick={() => setDialogOpen(true)} 
                variant="link" 
                className="mt-2"
              >
                Create your first template
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="bg-card border-border" data-testid="template-dialog">
          <DialogHeader>
            <DialogTitle className="font-heading">
              {selectedTemplate ? 'Edit Template' : 'Create Template'}
            </DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="e.g., Weekly Reminder"
                required
                data-testid="template-title-input"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="content">Message Content</Label>
              <Textarea
                id="content"
                value={formData.content}
                onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                placeholder="Type your message template here..."
                rows={6}
                required
                data-testid="template-content-input"
              />
              <p className="text-xs text-muted-foreground">
                Tip: You can use this template when scheduling messages
              </p>
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" className="btn-glow" data-testid="save-template-btn">
                {selectedTemplate ? 'Update' : 'Create Template'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default Templates;
