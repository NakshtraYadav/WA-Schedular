/**
 * WhatsApp API endpoints
 */
import apiClient from './client';

export const getWhatsAppStatus = () => apiClient.get('/api/whatsapp/status');
export const getWhatsAppQR = () => apiClient.get('/api/whatsapp/qr');
export const logoutWhatsApp = () => apiClient.post('/api/whatsapp/logout');
export const retryWhatsApp = () => apiClient.post('/api/whatsapp/retry');
export const clearWhatsAppSession = () => apiClient.post('/api/whatsapp/clear-session');
export const testBrowser = () => apiClient.get('/api/whatsapp/test-browser');
