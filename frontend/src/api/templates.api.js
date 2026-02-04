/**
 * Templates API endpoints
 */
import apiClient from './client';

export const getTemplates = () => apiClient.get('/api/templates');
export const createTemplate = (data) => apiClient.post('/api/templates', data);
export const updateTemplate = (id, data) => apiClient.put(`/api/templates/${id}`, data);
export const deleteTemplate = (id) => apiClient.delete(`/api/templates/${id}`);
