/**
 * Message logs API endpoints
 */
import apiClient from './client';

export const getLogs = (limit = 100) => apiClient.get('/api/logs', { params: { limit } });
export const clearLogs = () => apiClient.delete('/api/logs');
