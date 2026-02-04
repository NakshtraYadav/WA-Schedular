/**
 * WhatsAppContext - Provides WhatsApp status across components
 */
import React, { createContext, useContext } from 'react';
import { useWhatsAppStatus } from '../hooks/useWhatsAppStatus';

const WhatsAppContext = createContext(null);

export const WhatsAppProvider = ({ children }) => {
  const waStatus = useWhatsAppStatus();

  return (
    <WhatsAppContext.Provider value={waStatus}>
      {children}
    </WhatsAppContext.Provider>
  );
};

export const useWhatsAppContext = () => {
  const context = useContext(WhatsAppContext);
  if (!context) {
    throw new Error('useWhatsAppContext must be used within WhatsAppProvider');
  }
  return context;
};

export default WhatsAppContext;
