/**
 * Settings API endpoints
 */
import apiClient from './client';

export const getSettings = () => apiClient.get('/api/settings');
export const updateSettings = (data) => apiClient.put('/api/settings', data);
export const getTimezoneInfo = () => apiClient.get('/api/settings/timezone');

// Telegram endpoints
export const testTelegram = () => apiClient.post('/api/telegram/test');
export const getTelegramStatus = () => apiClient.get('/api/telegram/status');
