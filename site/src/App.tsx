import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

// Auth
import { LoginPage } from './auth/LoginPage';
import { ProtectedRoute } from './shared/components/ProtectedRoute';

// Landing
import { LandingPage } from './landing';

// Contexts
import { ScannedPetProvider } from './contexts/ScannedPetContext';
import { LanguageProvider } from './i18n';

// Admin pages
import {
  AdminDashboard,
  AdminApplications,
  AdminUsers,
  AdminAdoptions,
  AdminEarnings,
} from './admin';

// Pro pages
import {
  ProDashboard,
  ProServices,
  ProAgenda,
  ProPatients,
  ProAvailability,
  ProDaycare,
  ProEarnings,
  ProSettings,
} from './pro';

// Import styles
import './index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: 1,
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <LanguageProvider>
        <ScannedPetProvider>
          <Router>
          <Routes>
          {/* Public routes */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />

          {/* Admin routes */}
          <Route
            path="/admin"
            element={
              <ProtectedRoute allowedRoles={['ADMIN']}>
                <AdminDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/applications"
            element={
              <ProtectedRoute allowedRoles={['ADMIN']}>
                <AdminApplications />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/users"
            element={
              <ProtectedRoute allowedRoles={['ADMIN']}>
                <AdminUsers />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/adoptions"
            element={
              <ProtectedRoute allowedRoles={['ADMIN']}>
                <AdminAdoptions />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/earnings"
            element={
              <ProtectedRoute allowedRoles={['ADMIN']}>
                <AdminEarnings />
              </ProtectedRoute>
            }
          />

          {/* Pro routes */}
          <Route
            path="/pro"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/services"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProServices />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/agenda"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProAgenda />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/patients"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProPatients />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/availability"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProAvailability />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/daycare"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProDaycare />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/earnings"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProEarnings />
              </ProtectedRoute>
            }
          />
          <Route
            path="/pro/settings"
            element={
              <ProtectedRoute allowedRoles={['PRO']}>
                <ProSettings />
              </ProtectedRoute>
            }
          />

          {/* Default redirect */}
          <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
          </Router>
        </ScannedPetProvider>
      </LanguageProvider>
    </QueryClientProvider>
  );
}

export default App;
