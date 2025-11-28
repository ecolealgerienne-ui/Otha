import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

export function useRequireAuth(allowedRoles?: ('ADMIN' | 'PRO')[]) {
  const navigate = useNavigate();
  const { user, isAuthenticated, isLoading, fetchUser } = useAuthStore();

  useEffect(() => {
    if (!isAuthenticated) {
      fetchUser();
    }
  }, []);

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      navigate('/login');
    }

    if (!isLoading && isAuthenticated && user && allowedRoles) {
      if (!allowedRoles.includes(user.role as 'ADMIN' | 'PRO')) {
        // Redirect to appropriate dashboard based on role
        if (user.role === 'ADMIN') {
          navigate('/admin');
        } else if (user.role === 'PRO') {
          navigate('/pro');
        } else {
          navigate('/login');
        }
      }
    }
  }, [isLoading, isAuthenticated, user, allowedRoles, navigate]);

  return { user, isLoading, isAuthenticated };
}

export function useRequireAdmin() {
  return useRequireAuth(['ADMIN']);
}

export function useRequirePro() {
  return useRequireAuth(['PRO']);
}
