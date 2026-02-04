/**
 * Dashboard API endpoints
 */
import apiClient from './client';

export const getDashboardStats = () => apiClient.get('/api/dashboard/stats');
