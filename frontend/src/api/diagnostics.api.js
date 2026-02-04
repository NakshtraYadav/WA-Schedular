/**
 * Diagnostics API endpoints
 */
import apiClient from './client';

export const getDiagnostics = () => apiClient.get('/api/diagnostics');
export const getServiceLogs = (service, lines = 100) => 
  apiClient.get(`/api/diagnostics/logs/${service}`, { params: { lines } });
export const getAllLogsSummary = () => apiClient.get('/api/diagnostics/logs');
export const clearServiceLogs = (service) => apiClient.post(`/api/diagnostics/clear-logs/${service}`);
