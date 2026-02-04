/**
 * LoadingSpinner - Loading indicator
 */
import React from 'react';
import { Loader2 } from 'lucide-react';
import { cn } from '../../lib/utils';

const LoadingSpinner = ({ size = 'md', className, text }) => {
  const sizeClasses = {
    sm: 'h-4 w-4',
    md: 'h-6 w-6',
    lg: 'h-8 w-8',
    xl: 'h-12 w-12',
  };

  return (
    <div
      data-testid="loading-spinner"
      className={cn('flex items-center justify-center gap-2', className)}
    >
      <Loader2 className={cn('animate-spin text-emerald-400', sizeClasses[size])} />
      {text && <span className="text-zinc-400">{text}</span>}
    </div>
  );
};

export default LoadingSpinner;
