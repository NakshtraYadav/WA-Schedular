/**
 * Contacts API endpoints
 */
import apiClient from './client';

export const getContacts = () => apiClient.get('/api/contacts');
export const createContact = (data) => apiClient.post('/api/contacts', data);
export const updateContact = (id, data) => apiClient.put(`/api/contacts/${id}`, data);
export const deleteContact = (id) => apiClient.delete(`/api/contacts/${id}`);
export const syncWhatsAppContacts = () => apiClient.post('/api/contacts/sync-whatsapp');
