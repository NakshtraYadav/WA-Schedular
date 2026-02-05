/**
 * API Module - Re-exports all API functions
 */

// WhatsApp
export {
  getWhatsAppStatus,
  getWhatsAppQR,
  logoutWhatsApp,
  retryWhatsApp,
  clearWhatsAppSession,
  testBrowser
} from './whatsapp.api';

// Contacts
export {
  getContacts,
  createContact,
  updateContact,
  deleteContact,
  syncWhatsAppContacts,
  verifyWhatsAppNumber,
  verifyBulkNumbers,
  verifySingleContact,
  deleteUnverifiedContacts,
  bulkDeleteContacts
} from './contacts.api';

// Templates
export {
  getTemplates,
  createTemplate,
  updateTemplate,
  deleteTemplate
} from './templates.api';

// Schedules
export {
  getSchedules,
  getSchedule,
  createSchedule,
  updateSchedule,
  toggleSchedule,
  deleteSchedule,
  testRunSchedule,
  getScheduleDebug,
  sendNow
} from './schedules.api';

// Logs
export {
  getLogs,
  clearLogs
} from './logs.api';

// Settings
export {
  getSettings,
  updateSettings,
  getTimezoneInfo,
  testTelegram,
  getTelegramStatus
} from './settings.api';

// Updates
export {
  checkForUpdates,
  installUpdate,
  getAutoUpdaterStatus,
  controlAutoUpdater
} from './updates.api';

// Diagnostics
export {
  getDiagnostics,
  getServiceLogs,
  getAllLogsSummary,
  clearServiceLogs
} from './diagnostics.api';

// Dashboard
export {
  getDashboardStats
} from './dashboard.api';

// Version
export {
  getAppVersion,
  getHealth
} from './version.api';

// Export client for custom use
export { default as apiClient } from './client';
