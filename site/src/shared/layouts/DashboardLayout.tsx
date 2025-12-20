import { useState, type ReactNode } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  Menu,
  X,
  LayoutDashboard,
  Users,
  Calendar,
  Settings,
  LogOut,
  Bell,
  DollarSign,
  Heart,
  Briefcase,
  Clock,
  Stethoscope,
  Flag,
  MessageSquare,
  Percent,
} from 'lucide-react';
import { useAuthStore, useIsAdmin, useIsPro } from '../../store/authStore';

interface NavItem {
  icon: ReactNode;
  label: string;
  path: string;
}

interface DashboardLayoutProps {
  children: ReactNode;
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuthStore();
  const isAdmin = useIsAdmin();
  const isPro = useIsPro();

  const adminNavItems: NavItem[] = [
    { icon: <LayoutDashboard size={20} />, label: 'Dashboard', path: '/admin' },
    { icon: <Briefcase size={20} />, label: 'Demandes Pro', path: '/admin/applications' },
    { icon: <Users size={20} />, label: 'Utilisateurs', path: '/admin/users' },
    { icon: <Heart size={20} />, label: 'Adoptions', path: '/admin/adoptions' },
    { icon: <DollarSign size={20} />, label: 'Gains', path: '/admin/earnings' },
    { icon: <Percent size={20} />, label: 'Commissions', path: '/admin/commissions' },
    { icon: <Flag size={20} />, label: 'Flags', path: '/admin/flags' },
    { icon: <MessageSquare size={20} />, label: 'Support', path: '/admin/support' },
  ];

  const proNavItems: NavItem[] = [
    { icon: <LayoutDashboard size={20} />, label: 'Dashboard', path: '/pro' },
    { icon: <Stethoscope size={20} />, label: 'Services', path: '/pro/services' },
    { icon: <Calendar size={20} />, label: 'Agenda', path: '/pro/agenda' },
    { icon: <Users size={20} />, label: 'Patients', path: '/pro/patients' },
    { icon: <Clock size={20} />, label: 'Disponibilités', path: '/pro/availability' },
    { icon: <DollarSign size={20} />, label: 'Gains', path: '/pro/earnings' },
    { icon: <Settings size={20} />, label: 'Paramètres', path: '/pro/settings' },
  ];

  const navItems = isAdmin ? adminNavItems : isPro ? proNavItems : [];

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile sidebar backdrop */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed top-0 left-0 z-50 h-full w-64 bg-white border-r border-gray-200 transform transition-transform duration-200 ease-in-out lg:translate-x-0 ${
          sidebarOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Logo */}
        <div className="flex items-center justify-between h-16 px-6 border-b border-gray-200">
          <Link to={isAdmin ? '/admin' : '/pro'} className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-gradient-to-br from-[#F36C6C] to-[#FF9D9D] rounded-lg flex items-center justify-center shadow-sm">
              <span className="text-white font-bold text-lg">V</span>
            </div>
            <span className="font-semibold text-gray-900">Vegece {isAdmin ? 'Admin' : 'Pro'}</span>
          </Link>
          <button
            className="lg:hidden text-gray-500 hover:text-gray-700"
            onClick={() => setSidebarOpen(false)}
          >
            <X size={24} />
          </button>
        </div>

        {/* Navigation */}
        <nav className="p-4 space-y-1">
          {navItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center space-x-3 px-4 py-3 rounded-lg transition-colors ${
                  isActive
                    ? 'bg-primary-50 text-primary-700'
                    : 'text-gray-600 hover:bg-gray-100'
                }`}
                onClick={() => setSidebarOpen(false)}
              >
                {item.icon}
                <span className="font-medium">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* User section */}
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200">
          <div className="flex items-center space-x-3 mb-4">
            <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
              <span className="text-primary-700 font-medium">
                {user?.email?.charAt(0).toUpperCase()}
              </span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">{user?.email}</p>
              <p className="text-xs text-gray-500">{user?.role}</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center space-x-2 w-full px-4 py-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
          >
            <LogOut size={20} />
            <span>Déconnexion</span>
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="lg:ml-64">
        {/* Top bar */}
        <header className="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-4 lg:px-6">
          <button
            className="lg:hidden text-gray-500 hover:text-gray-700"
            onClick={() => setSidebarOpen(true)}
          >
            <Menu size={24} />
          </button>

          <div className="flex-1" />

          <div className="flex items-center space-x-4">
            <button className="relative text-gray-500 hover:text-gray-700">
              <Bell size={24} />
              <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full text-xs text-white flex items-center justify-center">
                3
              </span>
            </button>
          </div>
        </header>

        {/* Page content */}
        <main className="p-4 lg:p-6">{children}</main>
      </div>
    </div>
  );
}
