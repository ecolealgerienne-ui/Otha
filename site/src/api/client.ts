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
  Prescription,
  HealthStatsAggregated,
  DiseaseTracking,
  AdoptPost,
  AdoptConversation,
  AdoptMessage,
  MonthlyEarnings,
  Notification,
  AdoptPostStatus,
} from '../types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://api.vegece.com/api/v1';

// Token storage keys
const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';

class ApiClient {
  private _client: AxiosInstance;
  private isRefreshing = false;
  private refreshSubscribers: ((token: string) => void)[] = [];

  // Public getter for direct API access when needed
  get client(): AxiosInstance {
    return this._client;
  }

  constructor() {
    this._client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor - add auth token
    this._client.interceptors.request.use(
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
    this._client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

        if (error.response?.status === 401 && !originalRequest._retry) {
          if (this.isRefreshing) {
            return new Promise((resolve) => {
              this.refreshSubscribers.push((token: string) => {
                originalRequest.headers.Authorization = `Bearer ${token}`;
                resolve(this._client(originalRequest));
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
            return this._client(originalRequest);
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
    const response = await this._client.post('/auth/login', { email, password });
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
    const { data } = await this._client.post<LoginResponse>('/auth/register', { email, password, phone });
    this.setTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
    return data;
  }

  async googleLogin(idToken: string): Promise<LoginResponse> {
    const { data } = await this._client.post<LoginResponse>('/auth/google', { idToken });
    this.setTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
    return data;
  }

  async refreshToken(): Promise<string> {
    const refreshToken = this.getRefreshToken();
    if (!refreshToken) throw new Error('No refresh token');

    const response = await axios.post(`${API_BASE_URL}/auth/refresh`, {
      refreshToken,
    });

    // Handle wrapped response { success: true, data: { accessToken, refreshToken } }
    const data = response.data?.data || response.data;
    const tokens: AuthTokens = {
      accessToken: data.accessToken || data.token,
      refreshToken: data.refreshToken || data.refresh_token || refreshToken, // Keep old refresh token if not provided
    };

    console.log('🔄 Token refreshed successfully');
    this.setTokens(tokens);
    return tokens.accessToken;
  }

  logout(): void {
    this.clearTokens();
  }

  // ==================== USER ====================
  async getMe(): Promise<User> {
    const { data } = await this._client.get<User>('/users/me');
    return data;
  }

  async updateMe(updates: Partial<User>): Promise<User> {
    const { data } = await this._client.patch<User>('/users/me', updates);
    return data;
  }

  // ==================== PROVIDER (PRO) ====================
  async myProvider(): Promise<ProviderProfile | null> {
    try {
      const { data } = await this._client.get<ProviderProfile>('/providers/me');
      return data;
    } catch {
      return null;
    }
  }

  async upsertMyProvider(profile: Partial<ProviderProfile>): Promise<ProviderProfile> {
    const { data } = await this._client.post<ProviderProfile>('/providers/me', profile);
    return data;
  }

  async reapplyMyProvider(): Promise<ProviderProfile> {
    const { data } = await this._client.post<ProviderProfile>('/providers/me/reapply');
    return data;
  }

  async setMyVisibility(visible: boolean): Promise<ProviderProfile> {
    const { data } = await this._client.patch<ProviderProfile>('/providers/me/visibility', { visible });
    return data;
  }

  // ==================== SERVICES ====================
  async myServices(): Promise<Service[]> {
    const { data } = await this._client.get('/providers/me/services');
    // Handle wrapped response
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async createMyService(service: Omit<Service, 'id' | 'providerId' | 'createdAt' | 'updatedAt'>): Promise<Service> {
    const { data } = await this._client.post('/providers/me/services', service);
    return data?.data || data;
  }

  async updateMyService(serviceId: string, updates: Partial<Service>): Promise<Service> {
    const { data } = await this._client.patch(`/providers/me/services/${serviceId}`, updates);
    return data?.data || data;
  }

  async deleteMyService(serviceId: string): Promise<void> {
    await this._client.delete(`/providers/me/services/${serviceId}`);
  }

  // ==================== AVAILABILITY ====================
  async myWeekly(): Promise<{ entries: ProviderAvailability[] }> {
    const { data } = await this._client.get('/providers/me/availability');
    // Handle wrapped response - returns { entries: [...] }
    const result = data?.data || data;
    return result?.entries ? result : { entries: Array.isArray(result) ? result : [] };
  }

  async setWeekly(entries: { weekday: number; startMin: number; endMin: number }[]): Promise<ProviderAvailability[]> {
    const { data } = await this._client.post('/providers/me/availability', { entries });
    const result = data?.data || data;
    return Array.isArray(result) ? result : (result?.entries || []);
  }

  async myTimeOffs(): Promise<ProviderTimeOff[]> {
    const { data } = await this._client.get('/providers/me/time-offs');
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async addTimeOff(startsAt: string, endsAt: string, reason?: string): Promise<ProviderTimeOff> {
    const { data } = await this._client.post<ProviderTimeOff>('/providers/me/time-offs', {
      startsAt,
      endsAt,
      reason,
    });
    return data;
  }

  async deleteMyTimeOff(id: string): Promise<void> {
    await this._client.delete(`/providers/me/time-offs/${id}`);
  }

  // ==================== BOOKINGS ====================
  async myBookings(): Promise<Booking[]> {
    const { data } = await this._client.get<Booking[]>('/bookings/mine');
    return data;
  }

  async providerAgenda(fromIso: string, toIso: string, status?: BookingStatus): Promise<Booking[]> {
    const params = new URLSearchParams({ from: fromIso, to: toIso });
    if (status) params.append('status', status);
    const { data } = await this._client.get(`/bookings/provider/me?${params}`);
    // Handle wrapped response { data: [...] } or direct array
    return Array.isArray(data) ? data : (data?.data || []);
  }

  async providerSetStatus(bookingId: string, status: BookingStatus): Promise<Booking> {
    const { data } = await this._client.patch(`/bookings/${bookingId}/provider-status`, { status });
    return (data as { data?: Booking })?.data || data;
  }

  async cancelBooking(bookingId: string): Promise<Booking> {
    const { data } = await this._client.post(`/bookings/${bookingId}/cancel`);
    return (data as { data?: Booking })?.data || data;
  }

  // OTP verification (provider verifies client's OTP code)
  async verifyBookingOtp(bookingId: string, code: string): Promise<{ success: boolean; message?: string }> {
    const { data } = await this._client.post(`/bookings/${bookingId}/otp/verify`, { code });
    return (data as { data?: { success: boolean; message?: string } })?.data || data;
  }

  // Provider confirms booking with method (QR_SCAN or SIMPLE)
  async proConfirmBooking(bookingId: string, method: 'QR_SCAN' | 'SIMPLE' = 'SIMPLE'): Promise<Booking> {
    const { data } = await this._client.post(`/bookings/${bookingId}/pro-confirm`, { method });
    return (data as { data?: Booking })?.data || data;
  }

  // Get active booking for pet (used when scanning QR code)
  async getActiveBookingForPet(petId: string): Promise<Booking | null> {
    try {
      const { data } = await this._client.get(`/bookings/active-for-pet/${petId}`);
      return data?.data || data;
    } catch {
      return null;
    }
  }

  // Confirm booking by reference code (VGC-XXXXXX) - for vets without camera
  async confirmByReferenceCode(referenceCode: string): Promise<{
    success: boolean;
    message: string;
    booking: Booking;
    pet: Pet | null;
    pets: Pet[];
    accessToken: string | null;
  }> {
    const { data } = await this._client.post('/bookings/confirm-by-reference', { referenceCode });
    return data?.data || data;
  }

  // ==================== DAYCARE ====================
  async myDaycareProviderBookings(): Promise<DaycareBooking[]> {
    const { data } = await this._client.get<DaycareBooking[]>('/daycare/provider/bookings');
    return data;
  }

  async markDaycareDropOff(bookingId: string): Promise<DaycareBooking> {
    const { data } = await this._client.patch<DaycareBooking>(`/daycare/bookings/${bookingId}/drop-off`);
    return data;
  }

  async markDaycarePickup(bookingId: string): Promise<DaycareBooking> {
    const { data } = await this._client.patch<DaycareBooking>(`/daycare/bookings/${bookingId}/pickup`);
    return data;
  }

  async updateDaycareStatus(bookingId: string, status: string): Promise<DaycareBooking> {
    const { data } = await this._client.patch<DaycareBooking>(`/daycare/bookings/${bookingId}/status`, { status });
    return data;
  }

  // ==================== PETS ====================
  async getProviderPatients(): Promise<Pet[]> {
    const { data } = await this._client.get('/pets/provider/patients');
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async getPetMedicalRecords(petId: string): Promise<MedicalRecord[]> {
    const { data } = await this._client.get(`/pets/${petId}/medical-records`);
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async getPetVaccinations(petId: string): Promise<Vaccination[]> {
    const { data } = await this._client.get(`/pets/${petId}/vaccinations`);
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  // Access via QR code token
  async getPetByToken(token: string): Promise<{ pet: Pet; medicalRecords: MedicalRecord[]; vaccinations: Vaccination[] }> {
    const { data } = await this._client.get(`/pets/by-token/${token}`);
    const petData = data?.data || data;
    // Backend returns pet object directly with nested medicalRecords/vaccinations
    // Transform to expected { pet, medicalRecords, vaccinations } format
    if (petData && !petData.pet) {
      return {
        pet: petData,
        medicalRecords: petData.medicalRecords || [],
        vaccinations: petData.vaccinations || [],
      };
    }
    return petData;
  }

  async createMedicalRecordByToken(token: string, record: { title: string; type: string; description?: string; vetName?: string; temperatureC?: number; heartRate?: number; date?: string }): Promise<MedicalRecord> {
    const { data } = await this._client.post(`/pets/by-token/${token}/medical-records`, record);
    return data?.data || data;
  }

  async deleteMedicalRecord(recordId: string): Promise<void> {
    await this._client.delete(`/pets/medical-records/${recordId}`);
  }

  async createMedicalRecordForPet(petId: string, record: { title: string; type: string; description?: string; vetName?: string }): Promise<MedicalRecord> {
    const { data } = await this._client.post(`/pets/${petId}/medical-records`, record);
    return data?.data || data;
  }

  async createPrescriptionForPet(petId: string, prescription: { title: string; description?: string; imageUrl?: string }): Promise<Prescription> {
    // Use the token-based endpoint via a generated token
    const tokenResponse = await this._client.post(`/pets/${petId}/access-token`);
    const token = tokenResponse.data?.token || tokenResponse.data?.data?.token;
    if (!token) throw new Error('Could not generate access token');
    const { data } = await this._client.post(`/pets/by-token/${token}/prescriptions`, prescription);
    return data?.data || data;
  }

  async createDiseaseForPet(petId: string, disease: { name: string; description?: string; status?: string }): Promise<DiseaseTracking> {
    // Use the token-based endpoint via a generated token
    const tokenResponse = await this._client.post(`/pets/${petId}/access-token`);
    const token = tokenResponse.data?.token || tokenResponse.data?.data?.token;
    if (!token) throw new Error('Could not generate access token');
    const { data } = await this._client.post(`/pets/by-token/${token}/diseases`, disease);
    return data?.data || data;
  }

  // ==================== PRESCRIPTIONS ====================
  async getPetPrescriptions(petId: string): Promise<Prescription[]> {
    const { data } = await this._client.get(`/pets/${petId}/prescriptions`);
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async createPrescriptionByToken(
    token: string,
    prescription: { title: string; description?: string; imageUrl?: string }
  ): Promise<Prescription> {
    const { data } = await this._client.post(`/pets/by-token/${token}/prescriptions`, prescription);
    return data?.data || data;
  }

  async updatePrescription(
    prescriptionId: string,
    updates: { title?: string; description?: string; imageUrl?: string }
  ): Promise<Prescription> {
    const { data } = await this._client.patch(`/pets/prescriptions/${prescriptionId}`, updates);
    return data?.data || data;
  }

  async deletePrescription(prescriptionId: string): Promise<void> {
    await this._client.delete(`/pets/prescriptions/${prescriptionId}`);
  }

  // ==================== HEALTH STATS (aggregated from MedicalRecord) ====================
  async getPetHealthStats(petId: string): Promise<HealthStatsAggregated | null> {
    try {
      const { data } = await this._client.get(`/pets/${petId}/health-stats`);
      return data?.data || data;
    } catch {
      return null;
    }
  }

  // ==================== DISEASE TRACKING ====================
  async getPetDiseases(petId: string): Promise<DiseaseTracking[]> {
    const { data } = await this._client.get(`/pets/${petId}/diseases`);
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async createVaccinationByToken(
    token: string,
    vaccination: { name: string; date?: string; nextDueDate?: string; batchNumber?: string; veterinarian?: string; notes?: string }
  ): Promise<Vaccination> {
    const { data } = await this._client.post(`/pets/by-token/${token}/vaccinations`, vaccination);
    return data?.data || data;
  }

  async createTreatmentByToken(
    token: string,
    treatment: { name: string; startDate?: string; endDate?: string; frequency?: string; dosage?: string; notes?: string; attachments?: string[] }
  ): Promise<any> {
    const { data } = await this._client.post(`/pets/by-token/${token}/treatments`, treatment);
    return data?.data || data;
  }

  async createWeightRecordByToken(
    token: string,
    record: { weightKg: number; date?: string; context?: string }
  ): Promise<any> {
    const { data } = await this._client.post(`/pets/by-token/${token}/weight-records`, record);
    return data?.data || data;
  }

  // ==================== DISEASE TRACKING (by token) ====================
  async listDiseasesByToken(token: string): Promise<DiseaseTracking[]> {
    const { data } = await this._client.get(`/pets/by-token/${token}/diseases`);
    return data?.data || data || [];
  }

  async getDiseaseByToken(token: string, diseaseId: string): Promise<DiseaseTracking> {
    const { data } = await this._client.get(`/pets/by-token/${token}/diseases/${diseaseId}`);
    return data?.data || data;
  }

  async createDiseaseByToken(
    token: string,
    disease: {
      name: string;
      description?: string;
      status?: string;
      severity?: string;
      symptoms?: string;
      treatment?: string;
      images?: string[];
      notes?: string;
      diagnosisDate?: string;
    }
  ): Promise<DiseaseTracking> {
    const { data } = await this._client.post(`/pets/by-token/${token}/diseases`, disease);
    return data?.data || data;
  }

  async addProgressEntryByToken(
    token: string,
    diseaseId: string,
    entry: {
      notes: string;
      severity?: string;
      treatmentUpdate?: string;
      images?: string[];
      date?: string;
    }
  ): Promise<any> {
    const { data } = await this._client.post(`/pets/by-token/${token}/diseases/${diseaseId}/progress`, entry);
    return data?.data || data;
  }

  async updateDisease(
    diseaseId: string,
    updates: { name?: string; description?: string; status?: string; notes?: string; images?: string[] }
  ): Promise<DiseaseTracking> {
    const { data } = await this._client.patch(`/pets/diseases/${diseaseId}`, updates);
    return data?.data || data;
  }

  async deleteDisease(diseaseId: string): Promise<void> {
    await this._client.delete(`/pets/diseases/${diseaseId}`);
  }

  async generatePetAccessToken(petId: string): Promise<string> {
    const { data } = await this._client.post(`/pets/${petId}/access-token`);
    return data?.token || data?.data?.token;
  }

  /** PRO: Generate access token for a pet from a recent confirmed booking */
  async generateProPetAccessToken(petId: string): Promise<string> {
    const { data } = await this._client.post(`/pets/${petId}/pro-access-token`);
    return data?.token || data?.data?.token;
  }

  // ==================== SCANNED PET SYNC (Flutter <-> Website) ====================
  async getScannedPet(): Promise<{ pet: Pet | null; scannedAt: string | null; token?: string | null }> {
    const { data } = await this._client.get('/providers/me/scanned-pet');
    return data?.data || data;
  }

  async clearScannedPet(): Promise<void> {
    await this._client.delete('/providers/me/scanned-pet');
  }

  // ==================== EARNINGS ====================
  async myHistoryMonthly(months = 12): Promise<MonthlyEarnings[]> {
    const { data } = await this._client.get(`/earnings/me/history-monthly?months=${months}`);
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async myEarnings(month: string): Promise<MonthlyEarnings | null> {
    try {
      const { data } = await this._client.get(`/earnings/me/earnings?month=${month}`);
      return data?.data || data;
    } catch {
      return null;
    }
  }

  // ==================== NOTIFICATIONS ====================
  async getNotifications(): Promise<Notification[]> {
    const { data } = await this._client.get<Notification[]>('/notifications');
    return data;
  }

  async getUnreadCount(): Promise<number> {
    const { data } = await this._client.get<{ count: number }>('/notifications/unread/count');
    return data.count;
  }

  async markNotificationRead(id: string): Promise<void> {
    await this._client.patch(`/notifications/${id}/read`);
  }

  async markAllNotificationsRead(): Promise<void> {
    await this._client.patch('/notifications/read-all');
  }

  // ==================== ADMIN: USERS ====================
  async adminListUsers(q?: string, limit = 20, offset = 0, role?: string, isBanned?: boolean, trustStatus?: string): Promise<User[]> {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (q) params.append('q', q);
    if (role) params.append('role', role);
    if (isBanned !== undefined) params.append('isBanned', String(isBanned));
    if (trustStatus) params.append('trustStatus', trustStatus);
    const { data } = await this._client.get(`/admin/users?${params}`);
    // Handle wrapped response { data: [...] } or direct array
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  // Get full user profile with all data (admin)
  async adminGetUserFullProfile(userId: string): Promise<any> {
    const { data } = await this._client.get(`/admin/users/${userId}/full`);
    return data?.data || data;
  }

  // Update user info (admin)
  async adminUpdateUser(userId: string, updates: {
    firstName?: string;
    lastName?: string;
    email?: string;
    phone?: string;
    city?: string;
  }): Promise<User> {
    const { data } = await this._client.patch<User>(`/admin/users/${userId}`, updates);
    return data;
  }

  // Warn user (admin)
  async adminWarnUser(userId: string, reason: string, metadata?: any): Promise<{ ok: boolean; message: string; sanction: any }> {
    const { data } = await this._client.post(`/admin/users/${userId}/warn`, { reason, metadata });
    return data;
  }

  // Suspend user (admin)
  async adminSuspendUser(userId: string, reason: string, durationDays: number, metadata?: any): Promise<{ ok: boolean; message: string; user: User; sanction: any }> {
    const { data } = await this._client.post(`/admin/users/${userId}/suspend`, { reason, durationDays, metadata });
    return data;
  }

  // Ban user (admin)
  async adminBanUser(userId: string, reason: string, metadata?: any): Promise<{ ok: boolean; message: string; user: User; sanction: any }> {
    const { data } = await this._client.post(`/admin/users/${userId}/ban`, { reason, metadata });
    return data;
  }

  // Unban user (admin)
  async adminUnbanUser(userId: string, reason?: string): Promise<{ ok: boolean; message: string; user: User; sanction: any }> {
    const { data } = await this._client.post(`/admin/users/${userId}/unban`, { reason });
    return data;
  }

  // Lift suspension (admin)
  async adminLiftSuspension(userId: string, reason?: string): Promise<{ ok: boolean; message: string; user: User; sanction: any }> {
    const { data } = await this._client.post(`/admin/users/${userId}/lift-suspension`, { reason });
    return data;
  }

  // Get user sanctions history (admin)
  async adminGetUserSanctions(userId: string): Promise<any[]> {
    const { data } = await this._client.get(`/admin/users/${userId}/sanctions`);
    return data?.data || data || [];
  }

  // Get user petshop orders (admin)
  async adminGetUserOrders(userId: string): Promise<any[]> {
    const { data } = await this._client.get(`/admin/users/${userId}/orders`);
    return data?.data || data || [];
  }

  // Get user daycare bookings (admin)
  async adminGetUserDaycareBookings(userId: string): Promise<any[]> {
    const { data } = await this._client.get(`/admin/users/${userId}/daycare`);
    return data?.data || data || [];
  }

  // ==================== ADMIN: PROVIDERS ====================
  // Note: Use lowercase status ('pending', 'approved', 'rejected') like Flutter app
  async listProviderApplications(
    status: string = 'pending',
    limit = 20,
    offset = 0
  ): Promise<ProviderProfile[]> {
    const params = new URLSearchParams({
      status,
      limit: String(limit),
      offset: String(offset),
    });
    const { data } = await this._client.get(`/providers/admin/applications?${params}`);
    // Handle wrapped response { data: [...] } or direct array
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async approveProvider(providerId: string): Promise<ProviderProfile> {
    const { data } = await this._client.post<ProviderProfile>(`/providers/admin/applications/${providerId}/approve`);
    return data;
  }

  async rejectProvider(providerId: string): Promise<ProviderProfile> {
    const { data } = await this._client.post<ProviderProfile>(`/providers/admin/applications/${providerId}/reject`);
    return data;
  }

  async adminUpdateProvider(providerId: string, updates: Partial<ProviderProfile>): Promise<ProviderProfile> {
    const { data } = await this._client.patch<ProviderProfile>(`/providers/admin/${providerId}`, updates);
    return data;
  }

  // Get provider services (admin)
  async getProviderServices(providerId: string): Promise<Service[]> {
    const { data } = await this._client.get(`/providers/${providerId}/services`);
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  // Get user quotas (admin)
  async adminGetUserQuotas(userId: string): Promise<{ swipesUsed: number; swipesRemaining: number; postsUsed: number; postsRemaining: number }> {
    try {
      const { data } = await this._client.get(`/users/${userId}/quotas`);
      const result = data?.data || data;
      return result || { swipesUsed: 0, swipesRemaining: 5, postsUsed: 0, postsRemaining: 1 };
    } catch {
      return { swipesUsed: 0, swipesRemaining: 5, postsUsed: 0, postsRemaining: 1 };
    }
  }

  // Get user adopt conversations (admin)
  async adminGetUserAdoptConversations(userId: string): Promise<AdoptConversation[]> {
    try {
      const { data } = await this._client.get(`/users/${userId}/adopt-conversations`);
      const result = data?.data || data;
      return Array.isArray(result) ? result : [];
    } catch {
      return [];
    }
  }

  // Get user adopt posts (admin)
  async adminGetUserAdoptPosts(userId: string): Promise<AdoptPost[]> {
    try {
      const { data } = await this._client.get(`/users/${userId}/adopt-posts`);
      const result = data?.data || data;
      return Array.isArray(result) ? result : [];
    } catch {
      return [];
    }
  }

  // Get user pets (admin)
  async adminGetUserPets(userId: string): Promise<Pet[]> {
    try {
      const { data } = await this._client.get(`/users/${userId}/pets`);
      const result = data?.data || data;
      return Array.isArray(result) ? result : [];
    } catch {
      return [];
    }
  }

  // Get user bookings (admin)
  async adminGetUserBookings(userId: string): Promise<Booking[]> {
    try {
      const { data } = await this._client.get(`/users/${userId}/bookings`);
      const result = data?.data || data;
      return Array.isArray(result) ? result : [];
    } catch {
      return [];
    }
  }

  // Reset user trust status (admin) - fix accidental penalties
  async adminResetUserTrustStatus(userId: string): Promise<{ ok: boolean; message: string; user?: User }> {
    const { data } = await this._client.post(`/users/${userId}/reset-trust`);
    return data?.data || data;
  }

  // ==================== ADMIN: ADOPTION ====================
  async adminAdoptList(
    status: AdoptPostStatus = 'PENDING',
    limit = 20,
    cursor?: string
  ): Promise<{ data: AdoptPost[]; nextCursor?: string }> {
    const params = new URLSearchParams({ status, limit: String(limit) });
    if (cursor) params.append('cursor', cursor);
    const { data } = await this._client.get<{ data: AdoptPost[]; nextCursor?: string }>(
      `/admin/adopt/posts?${params}`
    );
    return data;
  }

  async adminAdoptApprove(postId: string): Promise<AdoptPost> {
    const { data } = await this._client.patch<AdoptPost>(`/admin/adopt/posts/${postId}/approve`);
    return data;
  }

  async adminAdoptReject(postId: string, reasons?: string[], note?: string): Promise<AdoptPost> {
    const { data } = await this._client.patch<AdoptPost>(`/admin/adopt/posts/${postId}/reject`, { reasons, note });
    return data;
  }

  async adminAdoptArchive(postId: string): Promise<AdoptPost> {
    const { data } = await this._client.patch<AdoptPost>(`/admin/adopt/posts/${postId}/archive`);
    return data;
  }

  async adminAdoptApproveAll(): Promise<{ count: number }> {
    const { data } = await this._client.patch<{ count: number }>('/admin/adopt/posts/approve-all');
    return data;
  }

  async adminAdoptGetConversations(limit = 20): Promise<AdoptConversation[]> {
    const { data } = await this._client.get<AdoptConversation[]>(`/admin/adopt/conversations?limit=${limit}`);
    return data;
  }

  async adminAdoptGetConversationDetails(conversationId: string): Promise<{
    conversation: AdoptConversation;
    messages: AdoptMessage[];
  }> {
    const { data } = await this._client.get<{ conversation: AdoptConversation; messages: AdoptMessage[] }>(
      `/admin/adopt/conversations/${conversationId}`
    );
    return data;
  }

  // ==================== ADMIN: EARNINGS ====================
  async adminHistoryMonthly(providerId: string, months = 12): Promise<MonthlyEarnings[]> {
    const { data } = await this._client.get(
      `/earnings/admin/history-monthly?providerId=${providerId}&months=${months}`
    );
    // Handle wrapped response { data: [...] } or direct array
    const result = data?.data || data;
    return Array.isArray(result) ? result : [];
  }

  async adminCollectMonth(providerId: string, month: string, note?: string): Promise<void> {
    await this._client.post('/earnings/admin/collect-month', { providerId, month, note });
  }

  async adminUncollectMonth(providerId: string, month: string): Promise<void> {
    await this._client.post('/earnings/admin/uncollect-month', { providerId, month });
  }

  async adminTraceabilityStats(from: string, to: string): Promise<{
    totalBookings: number;
    totalAmount: number;
    totalCommission: number;
  }> {
    const { data } = await this._client.get(`/bookings/admin/traceability?from=${from}&to=${to}`);
    // Handle wrapped response { data: {...} } or direct object
    const result = data?.data || data;
    return result || { totalBookings: 0, totalAmount: 0, totalCommission: 0 };
  }

  // ==================== UPLOADS ====================
  async getPresignedUrl(
    filename: string,
    contentType: string
  ): Promise<{ uploadUrl: string; publicUrl: string; key: string; needsConfirm: boolean }> {
    // Extract extension from filename
    const ext = filename.includes('.') ? filename.split('.').pop() : undefined;

    const { data } = await this._client.post(
      '/uploads/presign',
      { mimeType: contentType, ext, folder: 'uploads' }
    );

    // Handle wrapped response { data: { url, publicUrl, ... } }
    const result = data?.data || data;

    console.log('📤 Presign raw response:', result);

    // Map backend response to frontend expected format
    return {
      uploadUrl: result.url,
      publicUrl: result.publicUrl,
      key: result.key,
      needsConfirm: result.needsConfirm ?? false,
    };
  }

  async uploadToPresignedUrl(uploadUrl: string, file: File): Promise<void> {
    await axios.put(uploadUrl, file, {
      headers: { 'Content-Type': file.type },
    });
  }

  async confirmUpload(key: string): Promise<{ success: boolean; url?: string }> {
    const { data } = await this._client.post('/uploads/confirm', { key });
    // Handle wrapped response
    const result = data?.data || data;
    return result;
  }

  async uploadFile(file: File): Promise<string> {
    try {
      // Try S3 presigned upload first
      const { uploadUrl, publicUrl, key, needsConfirm } = await this.getPresignedUrl(file.name, file.type);

      console.log('📤 S3 presign response:', { uploadUrl: uploadUrl?.substring(0, 50) + '...', publicUrl, key, needsConfirm });

      if (!uploadUrl) {
        throw new Error('No uploadUrl in presign response');
      }

      await this.uploadToPresignedUrl(uploadUrl, file);
      console.log('📤 S3 PUT upload successful');

      // Confirm upload to set ACL if needed
      if (needsConfirm && key) {
        console.log('📤 Confirming upload for ACL...');
        await this.confirmUpload(key);
        console.log('📤 ACL confirmed');
      }

      console.log('📤 S3 upload complete, URL:', publicUrl);
      return publicUrl;
    } catch (s3Error) {
      console.error('❌ S3 upload failed:', s3Error);
      throw s3Error; // Don't fallback to local - S3 should always work
    }
  }

  // ==================== ADMIN: FLAGS ====================
  async adminGetFlags(options?: {
    resolved?: boolean;
    type?: string;
    userId?: string;
    limit?: number;
  }): Promise<any[]> {
    const params = new URLSearchParams();
    if (options?.resolved !== undefined) params.append('resolved', String(options.resolved));
    if (options?.type) params.append('type', options.type);
    if (options?.userId) params.append('userId', options.userId);
    if (options?.limit) params.append('limit', String(options.limit));
    const { data } = await this._client.get(`/admin/flags?${params}`);
    return data?.data || data || [];
  }

  async adminGetFlagStats(): Promise<{
    total: number;
    active: number;
    resolved: number;
    byType: { type: string; count: number }[];
  }> {
    const { data } = await this._client.get('/admin/flags/stats');
    return data?.data || data;
  }

  async adminGetFlag(id: string): Promise<any> {
    const { data } = await this._client.get(`/admin/flags/${id}`);
    return data?.data || data;
  }

  async adminCreateFlag(dto: {
    userId: string;
    type: string;
    bookingId?: string;
    note?: string;
  }): Promise<any> {
    const { data } = await this._client.post('/admin/flags', dto);
    return data?.data || data;
  }

  async adminResolveFlag(id: string, note?: string): Promise<any> {
    const { data } = await this._client.patch(`/admin/flags/${id}/resolve`, { note });
    return data?.data || data;
  }

  async adminUnresolveFlag(id: string): Promise<any> {
    const { data } = await this._client.patch(`/admin/flags/${id}/unresolve`);
    return data?.data || data;
  }

  async adminDeleteFlag(id: string): Promise<{ ok: boolean }> {
    const { data } = await this._client.delete(`/admin/flags/${id}`);
    return data?.data || data;
  }

  async adminGetUserFlags(userId: string): Promise<any[]> {
    const { data } = await this._client.get(`/admin/flags/user/${userId}`);
    return data?.data || data || [];
  }

  async adminGetDetailedFlagStats(): Promise<any> {
    const { data } = await this._client.get('/admin/flags/stats/detailed');
    return data?.data || data;
  }

  async adminRunFlagAnalysis(): Promise<{
    pros: { analyzed: number; flagged: number; flags: string[] };
    users: { analyzed: number; flagged: number; flags: string[] };
    totalNewFlags: number;
  }> {
    const { data } = await this._client.post('/admin/flags/analyze');
    return data?.data || data;
  }

  async adminAnalyzePro(userId: string): Promise<{ flagsCreated: number; messages: string[] }> {
    const { data } = await this._client.post(`/admin/flags/analyze/pro/${userId}`);
    return data?.data || data;
  }

  async adminAnalyzeUser(userId: string): Promise<{ flagsCreated: number; messages: string[] }> {
    const { data } = await this._client.post(`/admin/flags/analyze/user/${userId}`);
    return data?.data || data;
  }

  // ==================== ADMIN: DISPUTED BOOKINGS ====================
  async adminGetDisputedBookings(): Promise<any[]> {
    const { data } = await this._client.get('/daycare/admin/disputed-bookings');
    return data?.data || data || [];
  }

  async adminCancelDisputedBooking(bookingId: string): Promise<{ ok: boolean; message: string }> {
    const { data } = await this._client.post(`/daycare/admin/cancel-disputed/${bookingId}`);
    return data?.data || data;
  }

  // ==================== ADMIN: SUPPORT TICKETS ====================

  async adminGetSupportTickets(filters?: {
    status?: string;
    category?: string;
    priority?: string;
    userId?: string;
    limit?: number;
    offset?: number;
  }): Promise<{ tickets: any[]; total: number }> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.category) params.append('category', filters.category);
    if (filters?.priority) params.append('priority', filters.priority);
    if (filters?.userId) params.append('userId', filters.userId);
    if (filters?.limit) params.append('limit', String(filters.limit));
    if (filters?.offset) params.append('offset', String(filters.offset));

    const { data } = await this._client.get(`/admin/support/tickets?${params.toString()}`);
    return data?.data || data;
  }

  async adminGetSupportTicket(ticketId: string): Promise<any> {
    const { data } = await this._client.get(`/admin/support/tickets/${ticketId}`);
    return data?.data || data;
  }

  async adminSendSupportMessage(ticketId: string, content: string): Promise<any> {
    const { data } = await this._client.post(`/admin/support/tickets/${ticketId}/messages`, { content });
    return data?.data || data;
  }

  async adminAssignTicket(ticketId: string, adminId?: string): Promise<any> {
    const { data } = await this._client.patch(`/admin/support/tickets/${ticketId}/assign`, { adminId });
    return data?.data || data;
  }

  async adminUpdateTicketStatus(ticketId: string, status: string): Promise<any> {
    const { data } = await this._client.patch(`/admin/support/tickets/${ticketId}/status`, { status });
    return data?.data || data;
  }

  async adminUpdateTicketPriority(ticketId: string, priority: string): Promise<any> {
    const { data } = await this._client.patch(`/admin/support/tickets/${ticketId}/priority`, { priority });
    return data?.data || data;
  }

  async adminGetSupportStats(): Promise<any> {
    const { data } = await this._client.get('/admin/support/stats');
    return data?.data || data;
  }

  async adminGetSupportUnreadCount(): Promise<{ count: number }> {
    const { data } = await this._client.get('/admin/support/unread');
    return data?.data || data;
  }

  // ==================== ADMIN COMMISSIONS ====================
  async adminGetCommissions(q?: string, isApproved?: boolean): Promise<{
    providerId: string;
    userId: string;
    displayName: string;
    email: string;
    isApproved: boolean;
    vetCommissionDa: number;
    daycareHourlyCommissionDa: number;
    daycareDailyCommissionDa: number;
  }[]> {
    const params = new URLSearchParams();
    if (q) params.append('q', q);
    if (isApproved !== undefined) params.append('isApproved', String(isApproved));
    const { data } = await this._client.get(`/admin/commissions?${params}`);
    return data?.data || data || [];
  }

  async adminGetProviderCommission(providerId: string): Promise<{
    providerId: string;
    userId: string;
    displayName: string;
    email: string;
    isApproved: boolean;
    vetCommissionDa: number;
    daycareHourlyCommissionDa: number;
    daycareDailyCommissionDa: number;
  }> {
    const { data } = await this._client.get(`/admin/commissions/${providerId}`);
    return data?.data || data;
  }

  async adminUpdateCommission(providerId: string, commission: {
    vetCommissionDa?: number;
    daycareHourlyCommissionDa?: number;
    daycareDailyCommissionDa?: number;
  }): Promise<any> {
    const { data } = await this._client.patch(`/admin/commissions/${providerId}`, commission);
    return data?.data || data;
  }

  async adminResetCommission(providerId: string): Promise<any> {
    const { data } = await this._client.post(`/admin/commissions/${providerId}/reset`);
    return data?.data || data;
  }
}

// Export singleton instance
export const api = new ApiClient();
export default api;
