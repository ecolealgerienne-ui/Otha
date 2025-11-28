import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User, ProviderProfile } from '../types';
import api from '../api/client';

interface AuthState {
  user: User | null;
  provider: ProviderProfile | null;
  isLoading: boolean;
  isAuthenticated: boolean;

  // Actions
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  fetchUser: () => Promise<void>;
  fetchProvider: () => Promise<void>;
  setUser: (user: User | null) => void;
  setProvider: (provider: ProviderProfile | null) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      provider: null,
      isLoading: false,
      isAuthenticated: false,

      login: async (email: string, password: string) => {
        set({ isLoading: true });
        try {
          const response = await api.login(email, password);
          set({
            user: response.user,
            isAuthenticated: true,
            isLoading: false,
          });

          // If user is PRO, fetch provider profile
          if (response.user.role === 'PRO') {
            const provider = await api.myProvider();
            set({ provider });
          }
        } catch (error) {
          set({ isLoading: false });
          throw error;
        }
      },

      logout: () => {
        api.logout();
        set({
          user: null,
          provider: null,
          isAuthenticated: false,
        });
      },

      fetchUser: async () => {
        const token = api.getAccessToken();
        if (!token) {
          set({ isAuthenticated: false, user: null });
          return;
        }

        set({ isLoading: true });
        try {
          const user = await api.getMe();
          set({
            user,
            isAuthenticated: true,
            isLoading: false,
          });

          // If user is PRO, fetch provider profile
          if (user.role === 'PRO') {
            const provider = await api.myProvider();
            set({ provider });
          }
        } catch {
          api.logout();
          set({
            user: null,
            provider: null,
            isAuthenticated: false,
            isLoading: false,
          });
        }
      },

      fetchProvider: async () => {
        const { user } = get();
        if (!user || user.role !== 'PRO') return;

        try {
          const provider = await api.myProvider();
          set({ provider });
        } catch {
          set({ provider: null });
        }
      },

      setUser: (user) => set({ user, isAuthenticated: !!user }),
      setProvider: (provider) => set({ provider }),
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);

// Helper hooks
export const useUser = () => useAuthStore((state) => state.user);
export const useProvider = () => useAuthStore((state) => state.provider);
export const useIsAdmin = () => useAuthStore((state) => state.user?.role === 'ADMIN');
export const useIsPro = () => useAuthStore((state) => state.user?.role === 'PRO');
export const useIsAuthenticated = () => useAuthStore((state) => state.isAuthenticated);
