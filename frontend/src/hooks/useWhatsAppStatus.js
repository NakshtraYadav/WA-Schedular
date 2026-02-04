/**
 * useWhatsAppStatus hook - WhatsApp connection status
 */
import { useState, useEffect, useCallback } from 'react';
import { getWhatsAppStatus } from '../api';

export const useWhatsAppStatus = (interval = 5000) => {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchStatus = useCallback(async () => {
    try {
      const response = await getWhatsAppStatus();
      setStatus(response.data);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStatus();
    const timer = setInterval(fetchStatus, interval);
    return () => clearInterval(timer);
  }, [fetchStatus, interval]);

  return { status, loading, error, refresh: fetchStatus };
};

export default useWhatsAppStatus;
