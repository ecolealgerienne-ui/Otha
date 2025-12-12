import { useEffect, useState, type ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import api from '../../api/client';

interface ProtectedRouteProps {
  children: ReactNode;
  allowedRoles?: ('ADMIN' | 'PRO')[];
}

export function ProtectedRoute({ children, allowedRoles }: ProtectedRouteProps) {
  const location = useLocation();
  const { user, isAuthenticated, isLoading, fetchUser } = useAuthStore();
  const [hasChecked, setHasChecked] = useState(false);

  console.log('ProtectedRoute render:', { isAuthenticated, isLoading, hasChecked, user: user?.email, path: location.pathname });

  useEffect(() => {
    const checkAuth = async () => {
      // Only check if we have a token and haven't checked yet
      const token = api.getAccessToken();
      console.log('ProtectedRoute checkAuth:', { token: token ? 'exists' : 'missing', isAuthenticated, hasChecked });

      if (token && !isAuthenticated && !hasChecked) {
        console.log('Calling fetchUser...');
        await fetchUser();
      }
      setHasChecked(true);
    };
    checkAuth();
  }, []);

  // Show loading while checking auth (only if we have a token)
  if (isLoading || (!hasChecked && api.getAccessToken())) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
      </div>
    );
  }

  // Not authenticated - redirect to login
  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Check role if specified
  if (allowedRoles && user && !allowedRoles.includes(user.role as 'ADMIN' | 'PRO')) {
    // Redirect to appropriate dashboard
    if (user.role === 'ADMIN') {
      return <Navigate to="/admin" replace />;
    } else if (user.role === 'PRO') {
      return <Navigate to="/pro" replace />;
    } else {
      return <Navigate to="/login" replace />;
    }
  }

  return <>{children}</>;
}
