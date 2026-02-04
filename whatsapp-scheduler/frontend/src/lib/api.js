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
export const simulateConnect = () => api.post('/whatsapp/simulate-connect');

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
