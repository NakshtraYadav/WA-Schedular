/**
 * StatusBadge - Displays status with color coding
 */
import React from 'react';
import { cn } from '../../lib/utils';

const statusColors = {
  success: 'bg-emerald-900/30 text-emerald-400 border-emerald-800',
  error: 'bg-red-900/30 text-red-400 border-red-800',
  warning: 'bg-amber-900/30 text-amber-400 border-amber-800',
  info: 'bg-blue-900/30 text-blue-400 border-blue-800',
  default: 'bg-zinc-800 text-zinc-400 border-zinc-700',
};

const StatusBadge = ({ status, children, className }) => {
  const colorClass = statusColors[status] || statusColors.default;

  return (
    <span
      data-testid="status-badge"
      className={cn(
        'inline-flex items-center gap-1.5 px-2 py-1 text-xs font-medium rounded-full border',
        colorClass,
        className
      )}
    >
      {children}
    </span>
  );
};

export default StatusBadge;
