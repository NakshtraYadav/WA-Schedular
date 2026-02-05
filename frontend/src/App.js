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
          richColors
          closeButton
          duration={4000}
        />
      </BrowserRouter>
    </VersionProvider>
  );
}

export default App;
