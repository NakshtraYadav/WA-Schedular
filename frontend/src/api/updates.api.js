/**
 * Updates API endpoints
 */
import apiClient from './client';

export const checkForUpdates = () => apiClient.get('/api/updates/check');
export const installUpdate = () => apiClient.post('/api/updates/install');
export const getAutoUpdaterStatus = () => apiClient.get('/api/updates/auto-updater/status');
export const controlAutoUpdater = (action) => apiClient.post(`/api/updates/auto-updater/${action}`);
