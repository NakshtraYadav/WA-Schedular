import axios from 'axios';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
export const API = `${BACKEND_URL}/api`;

export const api = axios.create({
  baseURL: API,
  headers: {
    'Content-Type': 'application/json',
  },
});

// WhatsApp
export const getWhatsAppStatus = () => api.get('/whatsapp/status');
export const getWhatsAppQR = () => api.get('/whatsapp/qr');
export const logoutWhatsApp = () => api.post('/whatsapp/logout');
export const retryWhatsApp = () => api.post('/whatsapp/retry');
export const clearWhatsAppSession = () => api.post('/whatsapp/clear-session');
export const testBrowser = () => api.get('/whatsapp/test-browser');

// Contacts
export const getContacts = () => api.get('/contacts');
export const createContact = (data) => api.post('/contacts', data);
export const updateContact = (id, data) => api.put(`/contacts/${id}`, data);
export const deleteContact = (id) => api.delete(`/contacts/${id}`);

// Templates
export const getTemplates = () => api.get('/templates');
export const createTemplate = (data) => api.post('/templates', data);
export const updateTemplate = (id, data) => api.put(`/templates/${id}`, data);
export const deleteTemplate = (id) => api.delete(`/templates/${id}`);

// Schedules
export const getSchedules = () => api.get('/schedules');
export const createSchedule = (data) => api.post('/schedules', data);
export const toggleSchedule = (id) => api.put(`/schedules/${id}/toggle`);
export const deleteSchedule = (id) => api.delete(`/schedules/${id}`);

// Send now
export const sendMessageNow = (contactId, message) => 
  api.post(`/send-now?contact_id=${contactId}&message=${encodeURIComponent(message)}`);

// Logs
export const getLogs = (limit = 100) => api.get(`/logs?limit=${limit}`);
export const clearLogs = () => api.delete('/logs');

// Settings
export const getSettings = () => api.get('/settings');
export const updateSettings = (data) => api.put('/settings', data);
export const getTimezoneInfo = () => api.get('/timezone');

// Dashboard
export const getDashboardStats = () => api.get('/dashboard/stats');

// Diagnostics
export const getDiagnostics = () => api.get('/diagnostics');
export const getLogsSummary = () => api.get('/diagnostics/logs');
export const getServiceLogs = (service, lines = 100) => api.get(`/diagnostics/logs/${service}?lines=${lines}`);
export const clearServiceLogs = (service) => api.post(`/diagnostics/clear-logs/${service}`);

// Updates
export const checkForUpdates = () => api.get('/updates/check');
export const installUpdate = () => api.post('/updates/install');
export const getAutoUpdaterStatus = () => api.get('/updates/auto-updater/status');
export const controlAutoUpdater = (action) => api.post(`/updates/auto-updater/${action}`);

// Version
export const getAppVersion = () => api.get('/version');
