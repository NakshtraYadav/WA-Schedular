/**
 * PageHeader - Consistent page header component
 */
import React from 'react';
import { cn } from '../../lib/utils';

const PageHeader = ({ title, description, action, className }) => {
  return (
    <div
      data-testid="page-header"
      className={cn('flex items-center justify-between mb-6', className)}
    >
      <div>
        <h1 className="text-2xl font-bold text-white">{title}</h1>
        {description && (
          <p className="text-zinc-400 mt-1">{description}</p>
        )}
      </div>
      {action && <div>{action}</div>}
    </div>
  );
};

export default PageHeader;
