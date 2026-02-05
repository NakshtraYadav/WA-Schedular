/**
 * App.js - Main application component
 * Uses modular routing with layout components
 */
import "./App.css";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Toaster } from "sonner";
import { VersionProvider } from "./context";
import { Layout } from "./components/layout";

// Pages
import Dashboard from "./pages/Dashboard";
import Contacts from "./pages/Contacts";
import Templates from "./pages/Templates";
import Scheduler from "./pages/Scheduler";
import MessageHistory from "./pages/MessageHistory";
import Settings from "./pages/Settings";
import Connect from "./pages/Connect";
import Diagnostics from "./pages/Diagnostics";

function App() {
  return (
    <VersionProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Layout />}>
            <Route index element={<Dashboard />} />
            <Route path="contacts" element={<Contacts />} />
            <Route path="templates" element={<Templates />} />
            <Route path="scheduler" element={<Scheduler />} />
            <Route path="history" element={<MessageHistory />} />
            <Route path="settings" element={<Settings />} />
            <Route path="connect" element={<Connect />} />
            <Route path="diagnostics" element={<Diagnostics />} />
          </Route>
        </Routes>
        <Toaster 
          position="top-right"
          closeButton
          duration={4000}
          theme="dark"
          toastOptions={{
            style: {
              background: 'hsl(240 6% 10%)',
              border: '1px solid hsl(240 4% 16%)',
              color: 'hsl(0 0% 98%)',
            },
            classNames: {
              toast: 'group',
              success: 'bg-emerald-950 border-emerald-800 text-emerald-100',
              error: 'bg-red-950 border-red-800 text-red-100',
              warning: 'bg-amber-950 border-amber-800 text-amber-100',
              info: 'bg-zinc-900 border-zinc-700 text-zinc-100',
            },
          }}
        />
      </BrowserRouter>
    </VersionProvider>
  );
}

export default App;
