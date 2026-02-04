/**
 * Layout component - Main app layout wrapper
 */
import React from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import { cn } from '../../lib/utils';

const Layout = () => {
  return (
    <div className="min-h-screen bg-zinc-950" data-testid="main-layout">
      <Sidebar />
      <main className="ml-64 min-h-screen p-6 transition-all duration-300">
        <Outlet />
      </main>
    </div>
  );
};

export default Layout;
