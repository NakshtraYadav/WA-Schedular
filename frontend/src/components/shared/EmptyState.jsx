/**
 * EmptyState - Display when no data available
 */
import React from 'react';
import { cn } from '../../lib/utils';

const EmptyState = ({ icon: Icon, title, description, action, className }) => {
  return (
    <div
      data-testid="empty-state"
      className={cn(
        'flex flex-col items-center justify-center py-12 text-center',
        className
      )}
    >
      {Icon && (
        <div className="p-3 bg-zinc-800 rounded-full mb-4">
          <Icon className="h-8 w-8 text-zinc-500" />
        </div>
      )}
      <h3 className="text-lg font-medium text-zinc-300 mb-1">{title}</h3>
      {description && (
        <p className="text-sm text-zinc-500 max-w-sm mb-4">{description}</p>
      )}
      {action}
    </div>
  );
};

export default EmptyState;
