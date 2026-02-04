/**
 * VersionContext - Provides app version across components
 */
import React, { createContext, useContext } from 'react';
import { useVersion } from '../hooks/useVersion';

const VersionContext = createContext(null);

export const VersionProvider = ({ children }) => {
  const versionState = useVersion();

  return (
    <VersionContext.Provider value={versionState}>
      {children}
    </VersionContext.Provider>
  );
};

export const useVersionContext = () => {
  const context = useContext(VersionContext);
  if (!context) {
    throw new Error('useVersionContext must be used within VersionProvider');
  }
  return context;
};

export default VersionContext;
