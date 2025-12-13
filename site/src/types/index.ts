// User & Auth Types
export type Role = 'USER' | 'PRO' | 'ADMIN';

export type TrustStatus = 'NEW' | 'VERIFIED' | 'RESTRICTED';

export interface User {
  id: string;
  email: string;
  phone?: string;
  firstName?: string;
  lastName?: string;
  displayName?: string;
  city?: string;
  lat?: number;
  lng?: number;
  photoUrl?: string;
  role: Role;
  isFirstBooking?: boolean;
  trustStatus?: TrustStatus;
  createdAt: string;
  updatedAt: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface LoginResponse {
  user: User;
  accessToken: string;
  refreshToken: string;
}

// Provider Types
export type ProviderStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export interface ProviderProfile {
  id: string;
  userId: string;
  displayName: string;
  bio?: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  specialties: any; // Can be string[] or a custom object with kind, mapsUrl, etc.
  avatarUrl?: string;
  address?: string;
  lat?: number;
  lng?: number;
  mapsUrl?: string;
  avnCardFront?: string;
  avnCardBack?: string;
  status: ProviderStatus;
  isApproved?: boolean;
  visible: boolean;
  timezone: string;
  user?: User;
  createdAt: string;
  updatedAt: string;
}

// Service Types
export interface Service {
  id: string;
  providerId: string;
  title: string;
  description?: string;
  durationMin: number;
  price: number;
  createdAt: string;
  updatedAt: string;
}

// Availability Types
export interface ProviderAvailability {
  id: string;
  providerId: string;
  weekday: number; // 0-6 (Sunday-Saturday)
  startTime?: string; // HH:mm (legacy)
  endTime?: string; // HH:mm (legacy)
  startMin?: number; // Minutes from midnight
  endMin?: number; // Minutes from midnight
}

export interface ProviderTimeOff {
  id: string;
  providerId: string;
  startsAt: string;
  endsAt: string;
  reason?: string;
}

// Booking Types
export type BookingStatus =
  | 'PENDING'
  | 'CONFIRMED'
  | 'CANCELLED'
  | 'COMPLETED'
  | 'AWAITING_CONFIRMATION'
  | 'PENDING_PRO_VALIDATION'
  | 'DISPUTED';

export interface Booking {
  id: string;
  userId: string;
  providerId: string;
  serviceId: string;
  petId?: string;
  scheduledAt: string;
  status: BookingStatus;
  notes?: string;
  otpCode?: string;
  confirmedAt?: string;
  completedAt?: string;
  cancelledAt?: string;
  user?: User;
  provider?: ProviderProfile;
  service?: Service;
  pet?: Pet;
  createdAt: string;
  updatedAt: string;
}

// Daycare Booking Types
export type DaycareStatus =
  | 'PENDING'
  | 'CONFIRMED'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'CANCELLED'
  | 'DISPUTED';

export interface DaycareBooking {
  id: string;
  userId: string;
  providerId: string;
  petId: string;
  scheduledDate: string;
  dropOffTime?: string;
  pickupTime?: string;
  status: DaycareStatus;
  notes?: string;
  lateFee?: number;
  user?: User;
  provider?: ProviderProfile;
  pet?: Pet;
  createdAt: string;
  updatedAt: string;
}

// Pet Types
export type PetSpecies = 'DOG' | 'CAT' | 'BIRD' | 'RABBIT' | 'OTHER';
export type PetGender = 'MALE' | 'FEMALE' | 'UNKNOWN';

export interface Pet {
  id: string;
  userId: string;
  name: string;
  species: PetSpecies;
  breed?: string;
  gender: PetGender;
  birthDate?: string;
  weight?: number;
  microchip?: string;
  bloodType?: string;
  photoUrl?: string;
  idNumber?: string;
  user?: User;
  createdAt: string;
  updatedAt: string;
}

export interface MedicalRecord {
  id: string;
  petId: string;
  type: string;
  title: string;
  description?: string;
  date: string;
  veterinarian?: string;
  attachments?: string[];
  createdAt: string;
}

export interface Vaccination {
  id: string;
  petId: string;
  name: string;
  date: string;
  nextDueDate?: string;
  veterinarian?: string;
  notes?: string;
}

// Prescription (Ordonnance) Types
export interface Prescription {
  id: string;
  petId: string;
  providerId: string;
  title: string;
  description?: string;
  imageUrl?: string;
  date: string;
  provider?: ProviderProfile;
  createdAt: string;
}

// Health Stats Types (aggregated format from MedicalRecord)
export interface HealthStatsAggregated {
  petId: string;
  weight: {
    data: Array<{ date: string; weightKg: number; source: string; context?: string; vetName?: string; notes?: string }>;
    current: number | null;
    min: number | null;
    max: number | null;
  };
  temperature: {
    data: Array<{ date: string; temperatureC: number; context?: string; vetName?: string }>;
    current: number | null;
    average: number | null;
  };
  heartRate: {
    data: Array<{ date: string; heartRate: number; context?: string; vetName?: string }>;
    current: number | null;
    average: number | null;
  };
}

// Disease Tracking Types
export interface DiseaseTracking {
  id: string;
  petId: string;
  providerId: string;
  name: string;
  description?: string;
  status: 'ACTIVE' | 'MONITORING' | 'RESOLVED';
  diagnosedDate: string;
  resolvedDate?: string;
  images?: string[];
  notes?: string;
  provider?: ProviderProfile;
  createdAt: string;
  updatedAt: string;
}

// Adoption Types
export type AdoptPostStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'ARCHIVED';

export interface AdoptPost {
  id: string;
  userId: string;
  name?: string;
  animalName?: string; // Backend may return this instead of name
  title?: string; // Backend may return this
  species: string;
  sex?: string;
  age?: string;
  description?: string;
  location?: string;
  city?: string; // Backend may return this instead of location
  status: AdoptPostStatus;
  images?: AdoptImage[];
  user?: User;
  createdAt: string;
  updatedAt: string;
}

export interface AdoptImage {
  id: string;
  postId: string;
  url: string;
  order: number;
}

export interface AdoptConversation {
  id: string;
  postId: string;
  ownerId: string;
  adopterId: string;
  ownerName: string;
  adopterName: string;
  isHiddenByOwner: boolean;
  isHiddenByAdopter: boolean;
  post?: AdoptPost;
  messages?: AdoptMessage[];
  lastMessage?: AdoptMessage;
  createdAt: string;
}

export interface AdoptMessage {
  id: string;
  conversationId: string;
  senderId: string;
  content: string;
  isRead: boolean;
  createdAt: string;
}

// Earnings Types
export interface ProviderEarning {
  id: string;
  providerId: string;
  bookingId: string;
  amount: number;
  commission: number;
  netAmount: number;
  month: string; // YYYY-MM
  createdAt: string;
}

export interface MonthlyEarnings {
  month: string;
  totalAmount: number;
  totalCommission: number;
  netAmount: number;
  bookingCount: number;
  collected: boolean;
  collectedAt?: string;
}

// Review Types
export interface Review {
  id: string;
  bookingId: string;
  userId: string;
  providerId: string;
  rating: number;
  comment?: string;
  user?: User;
  createdAt: string;
}

// Notification Types
export type NotificationType =
  | 'BOOKING_CREATED'
  | 'BOOKING_CONFIRMED'
  | 'BOOKING_CANCELLED'
  | 'BOOKING_COMPLETED'
  | 'PROVIDER_APPROVED'
  | 'PROVIDER_REJECTED'
  | 'ADOPT_APPROVED'
  | 'ADOPT_REJECTED'
  | 'NEW_MESSAGE';

export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  isRead: boolean;
  createdAt: string;
}

// API Response Types
export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

export interface ApiError {
  message: string;
  statusCode: number;
  error?: string;
}
