/**
 * Sidebar component
 */
import React, { useState, useEffect } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { cn } from '../../lib/utils';
import { useVersionContext } from '../../context';
import { getWhatsAppStatus, checkForUpdates } from '../../api';
import {
  LayoutDashboard,
  Users,
  FileText,
  Clock,
  History,
  Settings,
  Smartphone,
  Wrench,
  ChevronLeft,
  ChevronRight,
  ArrowUpCircle
} from 'lucide-react';

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/contacts', icon: Users, label: 'Contacts' },
  { to: '/templates', icon: FileText, label: 'Templates' },
  { to: '/scheduler', icon: Clock, label: 'Scheduler' },
  { to: '/history', icon: History, label: 'History' },
  { to: '/settings', icon: Settings, label: 'Settings' },
  { to: '/connect', icon: Smartphone, label: 'Connect' },
  { to: '/diagnostics', icon: Wrench, label: 'Diagnostics' },
];

const Sidebar = () => {
  const location = useLocation();
  const { version } = useVersionContext();
  const [collapsed, setCollapsed] = useState(false);
  const [waStatus, setWaStatus] = useState(null);
  const [updateAvailable, setUpdateAvailable] = useState(false);

  useEffect(() => {
    const checkStatus = async () => {
      try {
        const [statusRes, updateRes] = await Promise.all([
          getWhatsAppStatus(),
          checkForUpdates()
        ]);
        setWaStatus(statusRes.data);
        setUpdateAvailable(updateRes.data?.has_update);
      } catch (e) {
        console.error('Status check failed:', e);
      }
    };
    checkStatus();
    const interval = setInterval(checkStatus, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <aside
      data-testid="sidebar"
      className={cn(
        'fixed left-0 top-0 h-full bg-zinc-900 border-r border-zinc-800 z-50 transition-all duration-300 flex flex-col',
        collapsed ? 'w-16' : 'w-64'
      )}
    >
      {/* Header */}
      <div className="p-4 border-b border-zinc-800 flex items-center justify-between">
        {!collapsed && (
          <div className="flex items-center gap-2">
            <Smartphone className="h-6 w-6 text-emerald-400" />
            <span className="font-semibold text-white">WA Scheduler</span>
          </div>
        )}
        <button
          data-testid="sidebar-toggle"
          onClick={() => setCollapsed(!collapsed)}
          className="p-1 hover:bg-zinc-800 rounded transition-colors"
        >
          {collapsed ? (
            <ChevronRight className="h-5 w-5 text-zinc-400" />
          ) : (
            <ChevronLeft className="h-5 w-5 text-zinc-400" />
          )}
        </button>
      </div>

      {/* Status indicator */}
      <div className={cn('p-3 border-b border-zinc-800', collapsed && 'flex justify-center')}>
        <div
          data-testid="wa-status-indicator"
          className={cn(
            'flex items-center gap-2 px-3 py-2 rounded-lg',
            waStatus?.isReady ? 'bg-emerald-900/30' : 'bg-red-900/30'
          )}
        >
          <div
            className={cn(
              'w-2 h-2 rounded-full',
              waStatus?.isReady ? 'bg-emerald-400' : 'bg-red-400'
            )}
          />
          {!collapsed && (
            <span className={cn('text-sm', waStatus?.isReady ? 'text-emerald-400' : 'text-red-400')}>
              {waStatus?.isReady ? 'Connected' : 'Disconnected'}
            </span>
          )}
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            data-testid={`nav-${item.label.toLowerCase()}`}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2 rounded-lg transition-colors',
                isActive
                  ? 'bg-emerald-600 text-white'
                  : 'text-zinc-400 hover:bg-zinc-800 hover:text-white',
                collapsed && 'justify-center'
              )
            }
            title={collapsed ? item.label : undefined}
          >
            <item.icon className="h-5 w-5 flex-shrink-0" />
            {!collapsed && <span>{item.label}</span>}
          </NavLink>
        ))}
      </nav>

      {/* Footer with version */}
      <div className="p-3 border-t border-zinc-800">
        {updateAvailable && (
          <NavLink
            to="/settings"
            data-testid="update-available"
            className="flex items-center gap-2 px-3 py-2 mb-2 bg-amber-900/30 text-amber-400 rounded-lg hover:bg-amber-900/50 transition-colors"
          >
            <ArrowUpCircle className="h-4 w-4" />
            {!collapsed && <span className="text-sm">Update Available</span>}
          </NavLink>
        )}
        {!collapsed && version && (
          <div className="text-xs text-zinc-500 text-center">
            v{version.version}
          </div>
        )}
      </div>
    </aside>
  );
};

export default Sidebar;
