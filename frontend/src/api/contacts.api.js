/**
 * Contacts API endpoints
 */
import apiClient from './client';

export const getContacts = () => apiClient.get('/api/contacts');
export const createContact = (data, verify = true) => 
  apiClient.post(`/api/contacts?verify=${verify}`, data);
export const updateContact = (id, data) => apiClient.put(`/api/contacts/${id}`, data);
export const deleteContact = (id) => apiClient.delete(`/api/contacts/${id}`);
export const syncWhatsAppContacts = () => apiClient.post('/api/contacts/sync-whatsapp');
export const verifyWhatsAppNumber = (phone) => apiClient.get(`/api/contacts/verify/${encodeURIComponent(phone)}`);
// Bulk verify needs longer timeout - each number takes ~1-2 seconds
export const verifyBulkNumbers = (phones) => apiClient.post('/api/contacts/verify-bulk', phones, { timeout: 180000 });
// Verify single contact and update DB
export const verifySingleContact = (phone) => apiClient.post(`/api/contacts/verify-single/${encodeURIComponent(phone)}`, {}, { timeout: 30000 });
// Delete all unverified contacts
export const deleteUnverifiedContacts = () => apiClient.delete('/api/contacts/unverified');
// Bulk delete selected contacts
export const bulkDeleteContacts = (contactIds) => apiClient.post('/api/contacts/bulk-delete', contactIds);
