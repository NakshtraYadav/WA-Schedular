import "./App.css";
import { BrowserRouter, Routes, Route, NavLink, useLocation } from "react-router-dom";
import { useState, useEffect, createContext, useContext, useCallback } from "react";
import { Toaster } from "./components/ui/sonner";
import { 
  LayoutDashboard, 
  Users, 
  MessageSquare, 
  Calendar, 
  History, 
  Settings,
  Radio,
  MessageCircle,
  Activity,
  ArrowUpCircle
} from "lucide-react";
import { getAppVersion, checkForUpdates } from "./lib/api";
import { toast } from "sonner";

// Pages
import Dashboard from "./pages/Dashboard";
import Contacts from "./pages/Contacts";
import Templates from "./pages/Templates";
import Scheduler from "./pages/Scheduler";
import MessageHistory from "./pages/MessageHistory";
import SettingsPage from "./pages/Settings";
import Connect from "./pages/Connect";
import Diagnostics from "./pages/Diagnostics";

const navItems = [
  { path: "/", icon: LayoutDashboard, label: "Dashboard" },
  { path: "/contacts", icon: Users, label: "Contacts" },
  { path: "/templates", icon: MessageSquare, label: "Templates" },
  { path: "/scheduler", icon: Calendar, label: "Scheduler" },
  { path: "/history", icon: History, label: "History" },
  { path: "/settings", icon: Settings, label: "Settings" },
];

// Version Context
const VersionContext = createContext(null);

export const useVersion = () => useContext(VersionContext);

function VersionProvider({ children }) {
  const [versionInfo, setVersionInfo] = useState(null);
  const [updateAvailable, setUpdateAvailable] = useState(false);
  const [updateInfo, setUpdateInfo] = useState(null);
  const [initialized, setInitialized] = useState(false);

  const checkVersion = useCallback(async () => {
    try {
      const [versionRes, updateRes] = await Promise.all([
        getAppVersion(),
        checkForUpdates()
      ]);
      setVersionInfo(versionRes.data);
      setUpdateInfo(updateRes.data);
      
      if (updateRes.data?.has_update) {
        setUpdateAvailable(true);
      }
      return updateRes.data?.has_update;
    } catch (e) {
      console.error("Failed to check version:", e);
      return false;
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    
    const init = async () => {
      const hasUpdate = await checkVersion();
      if (mounted && hasUpdate && !initialized) {
        toast.info("Update available! Go to Settings to install.", {
          duration: 5000,
          action: {
            label: "View",
            onClick: () => window.location.href = "/settings"
          }
        });
      }
      if (mounted) setInitialized(true);
    };
    
    init();
    
    // Check every 30 minutes
    const interval = setInterval(checkVersion, 30 * 60 * 1000);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, [checkVersion, initialized]);

  return (
    <VersionContext.Provider value={{ versionInfo, updateAvailable, updateInfo, checkVersion }}>
      {children}
    </VersionContext.Provider>
  );
}

function Sidebar() {
  const location = useLocation();
  const { versionInfo, updateAvailable } = useVersion() || {};
  
  return (
    <aside className="fixed left-0 top-0 w-64 h-screen bg-card border-r border-border flex flex-col">
      <div className="p-6 border-b border-border">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg bg-primary/20 flex items-center justify-center">
            <MessageCircle className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="font-heading font-bold text-lg text-foreground">WA Scheduler</h1>
            <p className="text-xs text-muted-foreground">Command Center</p>
          </div>
        </div>
      </div>
      
      <nav className="flex-1 p-4 space-y-1">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          const showUpdateBadge = item.path === "/settings" && updateAvailable;
          return (
            <NavLink
              key={item.path}
              to={item.path}
              data-testid={`nav-${item.label.toLowerCase()}`}
              className={`flex items-center gap-3 px-4 py-3 rounded-md transition-all duration-200 ${
                isActive
                  ? "bg-primary/10 text-primary border-r-2 border-primary"
                  : "text-muted-foreground hover:text-foreground hover:bg-accent/50"
              }`}
            >
              <item.icon className="w-5 h-5" />
              <span className="font-medium">{item.label}</span>
              {showUpdateBadge && (
                <span className="ml-auto flex h-5 w-5 items-center justify-center rounded-full bg-green-500 animate-pulse">
                  <ArrowUpCircle className="w-3 h-3 text-white" />
                </span>
              )}
            </NavLink>
          );
        })}
      </nav>
      
      <div className="p-4 border-t border-border space-y-2">
        <NavLink
          to="/connect"
          data-testid="nav-connect"
          className={({ isActive }) => `flex items-center gap-3 px-4 py-3 rounded-md transition-all duration-200 ${
            isActive
              ? "bg-primary text-primary-foreground btn-glow"
              : "bg-secondary text-secondary-foreground hover:bg-secondary/80"
          }`}
        >
          <Radio className="w-5 h-5" />
          <span className="font-medium">WhatsApp Status</span>
        </NavLink>
        <NavLink
          to="/diagnostics"
          data-testid="nav-diagnostics"
          className={({ isActive }) => `flex items-center gap-3 px-4 py-3 rounded-md transition-all duration-200 ${
            isActive
              ? "bg-orange-500 text-white"
              : "bg-muted text-muted-foreground hover:bg-muted/80 hover:text-foreground"
          }`}
        >
          <Activity className="w-5 h-5" />
          <span className="font-medium">Diagnostics</span>
        </NavLink>
      </div>
      
      {/* Version Badge */}
      <div className="p-4 border-t border-border">
        <div className="flex items-center justify-between text-xs">
          <span className="text-muted-foreground">Version</span>
          <span className="font-mono text-foreground">
            {versionInfo?.version || "..."} 
            {versionInfo?.git_sha && versionInfo.git_sha !== "unknown" && (
              <span className="text-muted-foreground ml-1">({versionInfo.git_sha})</span>
            )}
          </span>
        </div>
        {updateAvailable && (
          <NavLink 
            to="/settings" 
            className="mt-2 flex items-center gap-2 text-xs text-green-500 hover:text-green-400 transition-colors"
          >
            <ArrowUpCircle className="w-3 h-3" />
            Update available
          </NavLink>
        )}
      </div>
    </aside>
  );
}

function Layout({ children }) {
  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <main className="ml-64 p-8">
        {children}
      </main>
    </div>
  );
}

function App() {
  return (
    <div className="App">
      <BrowserRouter>
        <VersionProvider>
          <Layout>
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/contacts" element={<Contacts />} />
              <Route path="/templates" element={<Templates />} />
              <Route path="/scheduler" element={<Scheduler />} />
              <Route path="/history" element={<MessageHistory />} />
              <Route path="/settings" element={<SettingsPage />} />
              <Route path="/connect" element={<Connect />} />
              <Route path="/diagnostics" element={<Diagnostics />} />
            </Routes>
          </Layout>
        </VersionProvider>
      </BrowserRouter>
      <Toaster position="top-right" />
    </div>
  );
}

export default App;
