/**
 * useVersion hook - App version management
 */
import { useState, useEffect } from 'react';
import { getAppVersion, checkForUpdates } from '../api';

export const useVersion = () => {
  const [version, setVersion] = useState(null);
  const [updateInfo, setUpdateInfo] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchVersion = async () => {
    try {
      const [versionRes, updateRes] = await Promise.all([
        getAppVersion(),
        checkForUpdates()
      ]);
      setVersion(versionRes.data);
      setUpdateInfo(updateRes.data);
    } catch (error) {
      console.error('Failed to fetch version:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchVersion();
    // Check for updates every 5 minutes
    const interval = setInterval(fetchVersion, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  return { version, updateInfo, loading, refresh: fetchVersion };
};

export default useVersion;
