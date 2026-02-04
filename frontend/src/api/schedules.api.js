/**
 * Schedules API endpoints
 */
import apiClient from './client';

export const getSchedules = () => apiClient.get('/api/schedules');
export const createSchedule = (data) => apiClient.post('/api/schedules', data);
export const toggleSchedule = (id) => apiClient.put(`/api/schedules/${id}/toggle`);
export const deleteSchedule = (id) => apiClient.delete(`/api/schedules/${id}`);
export const testRunSchedule = (id) => apiClient.post(`/api/schedules/test-run/${id}`);
export const getScheduleDebug = () => apiClient.get('/api/schedules/debug');
export const sendNow = (contactId, message) => 
  apiClient.post('/api/send-now', null, { params: { contact_id: contactId, message } });
