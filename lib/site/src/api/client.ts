import axios, { type AxiosInstance, type AxiosError, type InternalAxiosRequestConfig } from 'axios';
import type {
  User,
  AuthTokens,
  LoginResponse,
  ProviderProfile,
  Service,
  ProviderAvailability,
  ProviderTimeOff,
  Booking,
  BookingStatus,
  DaycareBooking,
  Pet,
  MedicalRecord,
  Vaccination,
  AdoptPost,
  AdoptConversation,
  AdoptMessage,
  MonthlyEarnings,
  Notification,
  ProviderStatus,
  AdoptPostStatus,
} from '../types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://api.piecespro.com/api/v1';

// Token storage keys
const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';

class ApiClient {
  private client: AxiosInstance;
  private isRefreshing = false;
  private refreshSubscribers: ((token: string) => void)[] = [];

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor - add auth token
    this.client.interceptors.request.use(
      (config: InternalAxiosRequestConfig) => {
        const token = this.getAccessToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor - handle 401 and refresh token
    this.client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

        if (error.response?.status === 401 && !originalRequest._retry) {
          if (this.isRefreshing) {
            return new Promise((resolve) => {
              this.refreshSubscribers.push((token: string) => {
                originalRequest.headers.Authorization = `Bearer ${token}`;
                resolve(this.client(originalRequest));
              });
            });
          }

          originalRequest._retry = true;
          this.isRefreshing = true;

          try {
            const newToken = await this.refreshToken();
            this.refreshSubscribers.forEach((cb) => cb(newToken));
            this.refreshSubscribers = [];
            originalRequest.headers.Authorization = `Bearer ${newToken}`;
            return this.client(originalRequest);
          } catch (refreshError) {
            this.logout();
            window.location.href = '/login';
            return Promise.reject(refreshError);
          } finally {
            this.isRefreshing = false;
          }
        }

        return Promise.reject(error);
      }
    );
  }

  // Token Management
  getAccessToken(): string | null {
    return localStorage.getItem(ACCESS_TOKEN_KEY);
  }

  getRefreshToken(): string | null {
    return localStorage.getItem(REFRESH_TOKEN_KEY);
  }

  setTokens(tokens: AuthTokens): void {
    localStorage.setItem(ACCESS_TOKEN_KEY, tokens.accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, tokens.refreshToken);
  }

  clearTokens(): void {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  }

  // ==================== AUTH ====================
  async login(email: string, password: string): Promise<LoginResponse> {
    const response = await this.client.post('/auth/login', { email, password });
    console.log('Raw login response:', response);
    console.log('Response data:', response.data);

    // Handle wrapped response (if backend wraps in { data: ... })
    const data = response.data?.data || response.data;

    const accessToken = data.accessToken || data.token;
    const refreshToken = data.refreshToken || data.refresh_token;

    if (accessToken) {
      this.setTokens({ accessToken, refreshToken: refreshToken || '' });
    }

    return data as LoginResponse;
  }

  async register(email: string, password: string, phone?: string): Promise<LoginResponse> {
    const { data } = await this.client.post<LoginResponse>('/auth/register', { email, password, phone });
    this.setTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
    return data;
  }

  async googleLogin(idToken: string): Promise<LoginResponse> {
    const { data } = await this.client.post<LoginResponse>('/auth/google', { idToken });
    this.setTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
    return data;
  }

  async refreshToken(): Promise<string> {
    const refreshToken = this.getRefreshToken();
    if (!refreshToken) throw new Error('No refresh token');

    const { data } = await axios.post<AuthTokens>(`${API_BASE_URL}/auth/refresh`, {
      refreshToken,
    });
    this.setTokens(data);
    return data.accessToken;
  }

  logout(): void {
    this.clearTokens();
  }

  // ==================== USER ====================
  async getMe(): Promise<User> {
    const { data } = await this.client.get<User>('/users/me');
    return data;
  }

  async updateMe(updates: Partial<User>): Promise<User> {
    const { data } = await this.client.patch<User>('/users/me', updates);
    return data;
  }

  // ==================== PROVIDER (PRO) ====================
  async myProvider(): Promise<ProviderProfile | null> {
    try {
      const { data } = await this.client.get<ProviderProfile>('/providers/me');
      return data;
    } catch {
      return null;
    }
  }

  async upsertMyProvider(profile: Partial<ProviderProfile>): Promise<ProviderProfile> {
    const { data } = await this.client.post<ProviderProfile>('/providers/me', profile);
    return data;
  }

  async reapplyMyProvider(): Promise<ProviderProfile> {
    const { data } = await this.client.post<ProviderProfile>('/providers/me/reapply');
    return data;
  }

  async setMyVisibility(visible: boolean): Promise<ProviderProfile> {
    const { data } = await this.client.patch<ProviderProfile>('/providers/me/visibility', { visible });
    return data;
  }

  // ==================== SERVICES ====================
  async myServices(): Promise<Service[]> {
    const { data } = await this.client.get<Service[]>('/providers/me/services');
    return data;
  }

  async createMyService(service: Omit<Service, 'id' | 'providerId' | 'createdAt' | 'updatedAt'>): Promise<Service> {
    const { data } = await this.client.post<Service>('/providers/me/services', service);
    return data;
  }

  async updateMyService(serviceId: string, updates: Partial<Service>): Promise<Service> {
    const { data } = await this.client.patch<Service>(`/providers/me/services/${serviceId}`, updates);
    return data;
  }

  async deleteMyService(serviceId: string): Promise<void> {
    await this.client.delete(`/providers/me/services/${serviceId}`);
  }

  // ==================== AVAILABILITY ====================
  async myWeekly(): Promise<ProviderAvailability[]> {
    const { data } = await this.client.get<ProviderAvailability[]>('/providers/me/availability');
    return data;
  }

  async setWeekly(entries: Omit<ProviderAvailability, 'id' | 'providerId'>[]): Promise<ProviderAvailability[]> {
    const { data } = await this.client.post<ProviderAvailability[]>('/providers/me/availability', { entries });
    return data;
  }

  async myTimeOffs(): Promise<ProviderTimeOff[]> {
    const { data } = await this.client.get<ProviderTimeOff[]>('/providers/me/time-offs');
    return data;
  }

  async addTimeOff(startsAt: string, endsAt: string, reason?: string): Promise<ProviderTimeOff> {
    const { data } = await this.client.post<ProviderTimeOff>('/providers/me/time-offs', {
      startsAt,
      endsAt,
      reason,
    });
    return data;
  }

  async deleteMyTimeOff(id: string): Promise<void> {
    await this.client.delete(`/providers/me/time-offs/${id}`);
  }

  // ==================== BOOKINGS ====================
  async myBookings(): Promise<Booking[]> {
    const { data } = await this.client.get<Booking[]>('/bookings/mine');
    return data;
  }

  async providerAgenda(fromIso: string, toIso: string, status?: BookingStatus): Promise<Booking[]> {
    const params = new URLSearchParams({ from: fromIso, to: toIso });
    if (status) params.append('status', status);
    const { data } = await this.client.get<Booking[]>(`/bookings/provider/me?${params}`);
    return data;
  }

  async providerSetStatus(bookingId: string, status: BookingStatus): Promise<Booking> {
    const { data } = await this.client.patch<Booking>(`/bookings/${bookingId}/status`, { status });
    return data;
  }

  async cancelBooking(bookingId: string): Promise<Booking> {
    const { data } = await this.client.post<Booking>(`/bookings/${bookingId}/cancel`);
    return data;
  }

  // ==================== DAYCARE ====================
  async myDaycareProviderBookings(): Promise<DaycareBooking[]> {
    const { data } = await this.client.get<DaycareBooking[]>('/daycare/provider/bookings');
    return data;
  }

  async markDaycareDropOff(bookingId: string): Promise<DaycareBooking> {
    const { data } = await this.client.patch<DaycareBooking>(`/daycare/bookings/${bookingId}/drop-off`);
    return data;
  }

  async markDaycarePickup(bookingId: string): Promise<DaycareBooking> {
    const { data } = await this.client.patch<DaycareBooking>(`/daycare/bookings/${bookingId}/pickup`);
    return data;
  }

  async updateDaycareStatus(bookingId: string, status: string): Promise<DaycareBooking> {
    const { data } = await this.client.patch<DaycareBooking>(`/daycare/bookings/${bookingId}/status`, { status });
    return data;
  }

  // ==================== PETS ====================
  async getProviderPatients(): Promise<Pet[]> {
    const { data } = await this.client.get<Pet[]>('/pets/provider/patients');
    return data;
  }

  async getPetMedicalRecords(petId: string): Promise<MedicalRecord[]> {
    const { data } = await this.client.get<MedicalRecord[]>(`/pets/${petId}/medical-records`);
    return data;
  }

  async getPetVaccinations(petId: string): Promise<Vaccination[]> {
    const { data } = await this.client.get<Vaccination[]>(`/pets/${petId}/vaccinations`);
    return data;
  }

  // ==================== EARNINGS ====================
  async myHistoryMonthly(months = 12): Promise<MonthlyEarnings[]> {
    const { data } = await this.client.get<MonthlyEarnings[]>(`/earnings/me/history-monthly?months=${months}`);
    return data;
  }

  async myEarnings(month: string): Promise<MonthlyEarnings> {
    const { data } = await this.client.get<MonthlyEarnings>(`/earnings/me/earnings?month=${month}`);
    return data;
  }

  // ==================== NOTIFICATIONS ====================
  async getNotifications(): Promise<Notification[]> {
    const { data } = await this.client.get<Notification[]>('/notifications');
    return data;
  }

  async getUnreadCount(): Promise<number> {
    const { data } = await this.client.get<{ count: number }>('/notifications/unread/count');
    return data.count;
  }

  async markNotificationRead(id: string): Promise<void> {
    await this.client.patch(`/notifications/${id}/read`);
  }

  async markAllNotificationsRead(): Promise<void> {
    await this.client.patch('/notifications/read-all');
  }

  // ==================== ADMIN: USERS ====================
  async adminListUsers(q?: string, limit = 20, offset = 0, role?: string): Promise<User[]> {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (q) params.append('q', q);
    if (role) params.append('role', role);
    const { data } = await this.client.get<User[]>(`/users/list?${params}`);
    return data;
  }

  // ==================== ADMIN: PROVIDERS ====================
  async listProviderApplications(
    status: ProviderStatus = 'PENDING',
    limit = 20,
    offset = 0
  ): Promise<ProviderProfile[]> {
    const params = new URLSearchParams({
      status,
      limit: String(limit),
      offset: String(offset),
    });
    const { data } = await this.client.get<ProviderProfile[]>(`/providers/admin/applications?${params}`);
    return data;
  }

  async approveProvider(providerId: string): Promise<ProviderProfile> {
    const { data } = await this.client.post<ProviderProfile>(`/providers/admin/applications/${providerId}/approve`);
    return data;
  }

  async rejectProvider(providerId: string): Promise<ProviderProfile> {
    const { data } = await this.client.post<ProviderProfile>(`/providers/admin/applications/${providerId}/reject`);
    return data;
  }

  async adminUpdateProvider(providerId: string, updates: Partial<ProviderProfile>): Promise<ProviderProfile> {
    const { data } = await this.client.patch<ProviderProfile>(`/providers/admin/${providerId}`, updates);
    return data;
  }

  // ==================== ADMIN: ADOPTION ====================
  async adminAdoptList(
    status: AdoptPostStatus = 'PENDING',
    limit = 20,
    cursor?: string
  ): Promise<{ data: AdoptPost[]; nextCursor?: string }> {
    const params = new URLSearchParams({ status, limit: String(limit) });
    if (cursor) params.append('cursor', cursor);
    const { data } = await this.client.get<{ data: AdoptPost[]; nextCursor?: string }>(
      `/admin/adopt/posts?${params}`
    );
    return data;
  }

  async adminAdoptApprove(postId: string): Promise<AdoptPost> {
    const { data } = await this.client.patch<AdoptPost>(`/admin/adopt/posts/${postId}/approve`);
    return data;
  }

  async adminAdoptReject(postId: string, reasons?: string[], note?: string): Promise<AdoptPost> {
    const { data } = await this.client.patch<AdoptPost>(`/admin/adopt/posts/${postId}/reject`, { reasons, note });
    return data;
  }

  async adminAdoptArchive(postId: string): Promise<AdoptPost> {
    const { data } = await this.client.patch<AdoptPost>(`/admin/adopt/posts/${postId}/archive`);
    return data;
  }

  async adminAdoptApproveAll(): Promise<{ count: number }> {
    const { data } = await this.client.patch<{ count: number }>('/admin/adopt/posts/approve-all');
    return data;
  }

  async adminAdoptGetConversations(limit = 20): Promise<AdoptConversation[]> {
    const { data } = await this.client.get<AdoptConversation[]>(`/admin/adopt/conversations?limit=${limit}`);
    return data;
  }

  async adminAdoptGetConversationDetails(conversationId: string): Promise<{
    conversation: AdoptConversation;
    messages: AdoptMessage[];
  }> {
    const { data } = await this.client.get<{ conversation: AdoptConversation; messages: AdoptMessage[] }>(
      `/admin/adopt/conversations/${conversationId}`
    );
    return data;
  }

  // ==================== ADMIN: EARNINGS ====================
  async adminHistoryMonthly(providerId: string, months = 12): Promise<MonthlyEarnings[]> {
    const { data } = await this.client.get<MonthlyEarnings[]>(
      `/earnings/admin/history-monthly?providerId=${providerId}&months=${months}`
    );
    return data;
  }

  async adminCollectMonth(providerId: string, month: string, note?: string): Promise<void> {
    await this.client.post('/earnings/admin/collect-month', { providerId, month, note });
  }

  async adminUncollectMonth(providerId: string, month: string): Promise<void> {
    await this.client.post('/earnings/admin/uncollect-month', { providerId, month });
  }

  async adminTraceabilityStats(from: string, to: string): Promise<{
    totalBookings: number;
    totalAmount: number;
    totalCommission: number;
  }> {
    const { data } = await this.client.get<{
      totalBookings: number;
      totalAmount: number;
      totalCommission: number;
    }>(`/bookings/admin/traceability?from=${from}&to=${to}`);
    return data;
  }

  // ==================== UPLOADS ====================
  async getPresignedUrl(
    filename: string,
    contentType: string
  ): Promise<{ uploadUrl: string; fileUrl: string; key: string }> {
    const { data } = await this.client.post<{ uploadUrl: string; fileUrl: string; key: string }>(
      '/uploads/presign',
      { filename, contentType }
    );
    return data;
  }

  async uploadToPresignedUrl(uploadUrl: string, file: File): Promise<void> {
    await axios.put(uploadUrl, file, {
      headers: { 'Content-Type': file.type },
    });
  }

  async confirmUpload(key: string): Promise<{ url: string }> {
    const { data } = await this.client.post<{ url: string }>('/uploads/confirm', { key });
    return data;
  }

  async uploadFile(file: File): Promise<string> {
    try {
      // Try S3 presigned upload first
      const { uploadUrl, key } = await this.getPresignedUrl(file.name, file.type);
      await this.uploadToPresignedUrl(uploadUrl, file);
      const { url } = await this.confirmUpload(key);
      return url;
    } catch {
      // Fallback to local upload
      const formData = new FormData();
      formData.append('file', file);
      const { data } = await this.client.post<{ url: string }>('/uploads/local', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      return data.url;
    }
  }
}

// Export singleton instance
export const api = new ApiClient();
export default api;
