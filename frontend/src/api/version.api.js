/**
 * Version API endpoints
 */
import apiClient from './client';

export const getAppVersion = () => apiClient.get('/api/version');
export const getHealth = () => apiClient.get('/api/health');
