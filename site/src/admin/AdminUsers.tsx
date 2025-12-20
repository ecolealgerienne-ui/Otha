import { useEffect, useState, useCallback } from 'react';
import {
  Search,
  User as UserIcon,
  Mail,
  Phone,
  MapPin,
  Heart,
  PawPrint,
  MessageSquare,
  RefreshCw,
  Copy,
  Shield,
  Ban,
  CheckCircle,
  Unlock,
  AlertTriangle,
  Clock,
  Edit3,
  X,
  Calendar,
  ShoppingBag,
  Home,
  Flag,
  History,
  ChevronRight,
  MapPinned,
  Save,
} from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { User, AdoptPost, AdoptConversation } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

// Types
interface UserQuotas {
  swipesUsed: number;
  swipesRemaining: number;
  postsUsed: number;
  postsRemaining: number;
}

interface UserFullProfile {
  user: User & {
    isBanned?: boolean;
    bannedAt?: string;
    bannedReason?: string;
    suspendedUntil?: string;
    sanctions?: any[];
  };
  pets: any[];
  bookings: any[];
  daycareBookings: any[];
  orders: any[];
  adoptPosts: AdoptPost[];
  adoptConversations: AdoptConversation[];
  flags: any[];
  stats: {
    totalPets: number;
    totalBookings: number;
    completedBookings: number;
    cancelledBookings: number;
    disputedBookings: number;
    totalDaycareBookings: number;
    completedDaycare: number;
    disputedDaycare: number;
    totalOrders: number;
    deliveredOrders: number;
    totalAdoptPosts: number;
    approvedAdoptPosts: number;
    activeFlags: number;
    totalFlags: number;
  };
}

type TabType = 'bookings' | 'daycare' | 'orders' | 'pets' | 'adoptions' | 'flags' | 'sanctions';

export function AdminUsers() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRole, setSelectedRole] = useState<string>('USER');
  const [filterBanned, setFilterBanned] = useState<string>('');
  const [filterTrust, setFilterTrust] = useState<string>('');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  // Full profile data
  const [fullProfile, setFullProfile] = useState<UserFullProfile | null>(null);
  const [quotas, setQuotas] = useState<UserQuotas | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<TabType>('bookings');

  // UI States
  const [copied, setCopied] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // Modals
  const [showEditModal, setShowEditModal] = useState(false);
  const [showSanctionModal, setShowSanctionModal] = useState(false);
  const [sanctionType, setSanctionType] = useState<'warn' | 'suspend' | 'ban'>('warn');
  const [sanctionReason, setSanctionReason] = useState('');
  const [suspendDays, setSuspendDays] = useState(7);

  // Edit form
  const [editForm, setEditForm] = useState({
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    city: '',
  });

  useEffect(() => {
    fetchUsers();
  }, [searchQuery, selectedRole, filterBanned, filterTrust]);

  // Load full profile when user selected
  const loadUserDetails = useCallback(async (user: User) => {
    setDetailsLoading(true);
    try {
      const [profile, quotasData] = await Promise.all([
        api.adminGetUserFullProfile(user.id),
        api.adminGetUserQuotas(user.id),
      ]);
      setFullProfile(profile);
      setQuotas(quotasData);
      // Initialize edit form
      setEditForm({
        firstName: profile.user.firstName || '',
        lastName: profile.user.lastName || '',
        email: profile.user.email || '',
        phone: profile.user.phone || '',
        city: profile.user.city || '',
      });
    } catch (error) {
      console.error('Error loading user details:', error);
      setFullProfile(null);
      setQuotas(null);
    } finally {
      setDetailsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (selectedUser) {
      loadUserDetails(selectedUser);
    } else {
      setFullProfile(null);
      setQuotas(null);
    }
  }, [selectedUser, loadUserDetails]);

  async function fetchUsers() {
    setLoading(true);
    try {
      const data = await api.adminListUsers(
        searchQuery || undefined,
        50,
        0,
        selectedRole || undefined,
        filterBanned === 'true' ? true : filterBanned === 'false' ? false : undefined,
        filterTrust || undefined
      );
      setUsers(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching users:', error);
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    fetchUsers();
  };

  // Helpers
  const getDisplayName = (user: User) => {
    const firstName = user.firstName || '';
    const lastName = user.lastName || '';
    return [firstName, lastName].filter(Boolean).join(' ').trim() || '(Sans nom)';
  };

  const getAvatarLetter = (user: User) => {
    return (getDisplayName(user) || user.email || '?').charAt(0).toUpperCase();
  };

  const getRoleBadgeColor = (role: string) => {
    switch (role) {
      case 'ADMIN': return 'bg-purple-100 text-purple-700';
      case 'PRO': return 'bg-blue-100 text-blue-700';
      default: return 'bg-gray-100 text-gray-700';
    }
  };

  const getTrustStatusInfo = (status: string) => {
    switch (status) {
      case 'VERIFIED': return { label: 'Vérifié', color: 'bg-green-100 text-green-700 border-green-200', icon: CheckCircle };
      case 'RESTRICTED': return { label: 'Restreint', color: 'bg-red-100 text-red-700 border-red-200', icon: Ban };
      default: return { label: 'Nouveau', color: 'bg-blue-100 text-blue-700 border-blue-200', icon: UserIcon };
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'APPROVED': case 'COMPLETED': case 'DELIVERED': return 'bg-green-100 text-green-700';
      case 'REJECTED': case 'CANCELLED': case 'DISPUTED': return 'bg-red-100 text-red-700';
      case 'CONFIRMED': case 'IN_PROGRESS': case 'SHIPPED': return 'bg-blue-100 text-blue-700';
      default: return 'bg-yellow-100 text-yellow-700';
    }
  };

  const getSanctionTypeColor = (type: string) => {
    switch (type) {
      case 'WARNING': return 'bg-yellow-100 text-yellow-700';
      case 'SUSPENSION': return 'bg-orange-100 text-orange-700';
      case 'BAN': return 'bg-red-100 text-red-700';
      case 'UNBAN': case 'LIFT': return 'bg-green-100 text-green-700';
      default: return 'bg-gray-100 text-gray-700';
    }
  };

  async function copyToClipboard(text: string, type: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(type);
      setTimeout(() => setCopied(null), 2000);
    } catch { /* ignore */ }
  }

  // Actions
  const handleUpdateUser = async () => {
    if (!selectedUser) return;
    setActionLoading('edit');
    try {
      await api.adminUpdateUser(selectedUser.id, editForm);
      alert('Utilisateur mis à jour');
      setShowEditModal(false);
      loadUserDetails(selectedUser);
      fetchUsers();
    } catch (error: any) {
      alert(error?.response?.data?.message || 'Erreur lors de la mise à jour');
    } finally {
      setActionLoading(null);
    }
  };

  const handleSanction = async () => {
    if (!selectedUser || !sanctionReason.trim()) return;
    setActionLoading('sanction');
    try {
      if (sanctionType === 'warn') {
        await api.adminWarnUser(selectedUser.id, sanctionReason);
        alert('Avertissement émis');
      } else if (sanctionType === 'suspend') {
        await api.adminSuspendUser(selectedUser.id, sanctionReason, suspendDays);
        alert(`Utilisateur suspendu pour ${suspendDays} jour(s)`);
      } else if (sanctionType === 'ban') {
        await api.adminBanUser(selectedUser.id, sanctionReason);
        alert('Utilisateur banni');
      }
      setShowSanctionModal(false);
      setSanctionReason('');
      loadUserDetails(selectedUser);
      fetchUsers();
    } catch (error: any) {
      alert(error?.response?.data?.message || 'Erreur');
    } finally {
      setActionLoading(null);
    }
  };

  const handleUnban = async () => {
    if (!selectedUser) return;
    if (!confirm('Lever le ban de cet utilisateur ?')) return;
    setActionLoading('unban');
    try {
      await api.adminUnbanUser(selectedUser.id);
      alert('Ban levé');
      loadUserDetails(selectedUser);
      fetchUsers();
    } catch (error: any) {
      alert(error?.response?.data?.message || 'Erreur');
    } finally {
      setActionLoading(null);
    }
  };

  const handleLiftSuspension = async () => {
    if (!selectedUser) return;
    if (!confirm('Lever la suspension de cet utilisateur ?')) return;
    setActionLoading('lift');
    try {
      await api.adminLiftSuspension(selectedUser.id);
      alert('Suspension levée');
      loadUserDetails(selectedUser);
      fetchUsers();
    } catch (error: any) {
      alert(error?.response?.data?.message || 'Erreur');
    } finally {
      setActionLoading(null);
    }
  };

  const handleResetTrust = async () => {
    if (!selectedUser) return;
    if (!confirm('Réinitialiser le statut de confiance ?')) return;
    setActionLoading('trust');
    try {
      await api.adminResetUserTrustStatus(selectedUser.id);
      alert('Statut de confiance réinitialisé');
      loadUserDetails(selectedUser);
      fetchUsers();
    } catch (error: any) {
      alert(error?.response?.data?.message || 'Erreur');
    } finally {
      setActionLoading(null);
    }
  };

  const user = fullProfile?.user;
  const isBanned = user?.isBanned;
  const isSuspended = user?.suspendedUntil && new Date(user.suspendedUntil) > new Date();

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {selectedRole === 'USER' ? 'Clients' : selectedRole === 'PRO' ? 'Professionnels' : 'Utilisateurs'}
          </h1>
          <p className="text-gray-600 mt-1">Gestion complète des utilisateurs</p>
        </div>

        {/* Search and filters */}
        <Card>
          <form onSubmit={handleSearch} className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
              <Input
                placeholder="Rechercher nom, email, téléphone..."
                className="pl-10"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <select
              className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={selectedRole}
              onChange={(e) => setSelectedRole(e.target.value)}
            >
              <option value="">Tous les rôles</option>
              <option value="USER">Clients</option>
              <option value="PRO">Professionnels</option>
              <option value="ADMIN">Administrateurs</option>
            </select>
            <select
              className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={filterBanned}
              onChange={(e) => setFilterBanned(e.target.value)}
            >
              <option value="">Tous les statuts</option>
              <option value="true">Bannis</option>
              <option value="false">Non bannis</option>
            </select>
            <select
              className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={filterTrust}
              onChange={(e) => setFilterTrust(e.target.value)}
            >
              <option value="">Tous confiance</option>
              <option value="NEW">Nouveau</option>
              <option value="VERIFIED">Vérifié</option>
              <option value="RESTRICTED">Restreint</option>
            </select>
            <Button type="submit">Rechercher</Button>
          </form>
        </Card>

        {/* Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* List */}
          <div className="lg:col-span-1">
            {loading ? (
              <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
              </div>
            ) : users.length === 0 ? (
              <Card className="text-center py-12">
                <p className="text-gray-500">Aucun utilisateur trouvé</p>
              </Card>
            ) : (
              <div className="space-y-3 max-h-[70vh] overflow-y-auto">
                {users.map((u) => (
                  <Card
                    key={u.id}
                    className={`cursor-pointer transition-all ${
                      selectedUser?.id === u.id ? 'ring-2 ring-primary-500' : 'hover:shadow-md'
                    }`}
                    onClick={() => setSelectedUser(u)}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        {u.photoUrl ? (
                          <img src={u.photoUrl} alt={u.email} className="w-10 h-10 rounded-full object-cover" />
                        ) : (
                          <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
                            <span className="text-primary-700 font-bold">{getAvatarLetter(u)}</span>
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-2">
                            <p className="font-medium text-gray-900 truncate">{getDisplayName(u)}</p>
                            {(u as any).isBanned && (
                              <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-red-500 text-white">BAN</span>
                            )}
                            {(u as any).suspendedUntil && new Date((u as any).suspendedUntil) > new Date() && (
                              <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-orange-500 text-white">SUSP</span>
                            )}
                            {u.trustStatus === 'RESTRICTED' && (
                              <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-red-100 text-red-700">R</span>
                            )}
                            {u.trustStatus === 'VERIFIED' && (
                              <span className="flex-shrink-0 text-xs text-green-600">✓</span>
                            )}
                          </div>
                          <p className="text-xs text-gray-500 truncate">{u.email}</p>
                        </div>
                      </div>
                      <ChevronRight size={16} className="text-gray-400 flex-shrink-0" />
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </div>

          {/* Detail panel */}
          <div className="lg:col-span-2">
            {selectedUser && user ? (
              <div className="space-y-4">
                {/* User Info Card */}
                <Card>
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center space-x-4">
                      {user.photoUrl ? (
                        <img src={user.photoUrl} alt={user.email} className="w-16 h-16 rounded-full object-cover" />
                      ) : (
                        <div className="w-16 h-16 bg-primary-100 rounded-full flex items-center justify-center">
                          <span className="text-primary-700 font-bold text-2xl">{getAvatarLetter(user)}</span>
                        </div>
                      )}
                      <div>
                        <div className="flex items-center space-x-2">
                          <h3 className="text-xl font-bold text-gray-900">{getDisplayName(user)}</h3>
                          <span className={`text-xs px-2 py-0.5 rounded-full ${getRoleBadgeColor(user.role)}`}>
                            {user.role}
                          </span>
                          {isBanned && (
                            <span className="text-xs px-2 py-0.5 rounded-full bg-red-500 text-white">BANNI</span>
                          )}
                          {isSuspended && (
                            <span className="text-xs px-2 py-0.5 rounded-full bg-orange-500 text-white">SUSPENDU</span>
                          )}
                        </div>
                        <p className="text-sm text-gray-500">
                          Inscrit le {format(new Date(user.createdAt), 'dd MMMM yyyy', { locale: fr })}
                        </p>
                        <p className="text-xs text-gray-400 mt-1">ID: {user.id}</p>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={() => loadUserDetails(selectedUser)}
                        className="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100"
                        title="Rafraîchir"
                      >
                        <RefreshCw size={16} />
                      </button>
                      <button
                        onClick={() => setShowEditModal(true)}
                        className="p-2 text-blue-500 hover:text-blue-700 rounded-lg hover:bg-blue-50"
                        title="Modifier"
                      >
                        <Edit3 size={16} />
                      </button>
                    </div>
                  </div>

                  {/* Contact info */}
                  <div className="border-t pt-4 space-y-3">
                    <h4 className="font-semibold text-gray-900 mb-3">Coordonnées</h4>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <div className="flex items-center justify-between text-sm bg-gray-50 p-2 rounded">
                        <div className="flex items-center space-x-2">
                          <Mail size={16} className="text-gray-400" />
                          <span>{user.email}</span>
                        </div>
                        <button onClick={() => copyToClipboard(user.email, 'email')} className="text-gray-400 hover:text-gray-600">
                          <Copy size={14} />
                        </button>
                      </div>
                      {user.phone && (
                        <div className="flex items-center justify-between text-sm bg-gray-50 p-2 rounded">
                          <div className="flex items-center space-x-2">
                            <Phone size={16} className="text-gray-400" />
                            <span>{user.phone}</span>
                          </div>
                          <button onClick={() => copyToClipboard(user.phone!, 'phone')} className="text-gray-400 hover:text-gray-600">
                            <Copy size={14} />
                          </button>
                        </div>
                      )}
                      {user.city && (
                        <div className="flex items-center space-x-2 text-sm bg-gray-50 p-2 rounded">
                          <MapPin size={16} className="text-gray-400" />
                          <span>{user.city}</span>
                        </div>
                      )}
                      {(user.lat && user.lng) && (
                        <div className="flex items-center space-x-2 text-sm bg-gray-50 p-2 rounded">
                          <MapPinned size={16} className="text-blue-500" />
                          <span className="text-blue-600">
                            GPS: {user.lat.toFixed(4)}, {user.lng.toFixed(4)}
                          </span>
                          <a
                            href={`https://www.google.com/maps?q=${user.lat},${user.lng}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-blue-500 hover:underline text-xs"
                          >
                            Voir
                          </a>
                        </div>
                      )}
                    </div>
                  </div>
                </Card>

                {/* Stats Summary */}
                {fullProfile?.stats && (
                  <Card>
                    <h4 className="font-semibold text-gray-900 mb-3">Statistiques</h4>
                    <div className="grid grid-cols-4 gap-4">
                      <div className="text-center p-3 bg-blue-50 rounded-lg">
                        <p className="text-2xl font-bold text-blue-600">{fullProfile.stats.totalBookings}</p>
                        <p className="text-xs text-blue-600">RDV Véto</p>
                      </div>
                      <div className="text-center p-3 bg-purple-50 rounded-lg">
                        <p className="text-2xl font-bold text-purple-600">{fullProfile.stats.totalDaycareBookings}</p>
                        <p className="text-xs text-purple-600">Garderie</p>
                      </div>
                      <div className="text-center p-3 bg-green-50 rounded-lg">
                        <p className="text-2xl font-bold text-green-600">{fullProfile.stats.totalOrders}</p>
                        <p className="text-xs text-green-600">Commandes</p>
                      </div>
                      <div className="text-center p-3 bg-orange-50 rounded-lg">
                        <p className="text-2xl font-bold text-orange-600">{fullProfile.stats.activeFlags}</p>
                        <p className="text-xs text-orange-600">Flags actifs</p>
                      </div>
                    </div>
                  </Card>
                )}

                {/* Trust Status + Actions */}
                <Card>
                  <div className="flex items-center justify-between mb-4">
                    <h4 className="font-semibold text-gray-900 flex items-center">
                      <Shield size={18} className="mr-2 text-indigo-500" />
                      Statut & Actions
                    </h4>
                  </div>

                  {/* Trust Status */}
                  {(() => {
                    const trustInfo = getTrustStatusInfo(user.trustStatus || 'NEW');
                    const TrustIcon = trustInfo.icon;
                    return (
                      <div className={`p-3 rounded-lg border mb-4 ${trustInfo.color}`}>
                        <div className="flex items-center justify-between">
                          <div className="flex items-center space-x-3">
                            <TrustIcon size={20} />
                            <div>
                              <p className="font-bold">{trustInfo.label}</p>
                              {user.trustStatus === 'RESTRICTED' && user.restrictedUntil && (
                                <p className="text-xs opacity-75">
                                  Jusqu'au {format(new Date(user.restrictedUntil), 'dd/MM/yyyy HH:mm', { locale: fr })}
                                </p>
                              )}
                              {user.noShowCount !== undefined && user.noShowCount > 0 && (
                                <p className="text-xs opacity-75">No-shows: {user.noShowCount}</p>
                              )}
                            </div>
                          </div>
                          {(user.trustStatus === 'RESTRICTED' || user.trustStatus === 'NEW') && (
                            <Button
                              onClick={handleResetTrust}
                              disabled={actionLoading === 'trust'}
                              className="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-sm"
                            >
                              <Unlock size={14} />
                              Reset
                            </Button>
                          )}
                        </div>
                      </div>
                    );
                  })()}

                  {/* Ban/Suspension Status */}
                  {isBanned && (
                    <div className="p-3 rounded-lg border bg-red-50 border-red-200 mb-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <Ban size={20} className="text-red-600" />
                          <div>
                            <p className="font-bold text-red-700">Compte Banni</p>
                            {user.bannedAt && (
                              <p className="text-xs text-red-600">
                                Depuis le {format(new Date(user.bannedAt), 'dd/MM/yyyy', { locale: fr })}
                              </p>
                            )}
                            {user.bannedReason && (
                              <p className="text-xs text-red-600 mt-1">Raison: {user.bannedReason}</p>
                            )}
                          </div>
                        </div>
                        <Button
                          onClick={handleUnban}
                          disabled={actionLoading === 'unban'}
                          className="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-sm"
                        >
                          <Unlock size={14} />
                          Lever ban
                        </Button>
                      </div>
                    </div>
                  )}

                  {isSuspended && (
                    <div className="p-3 rounded-lg border bg-orange-50 border-orange-200 mb-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <Clock size={20} className="text-orange-600" />
                          <div>
                            <p className="font-bold text-orange-700">Compte Suspendu</p>
                            <p className="text-xs text-orange-600">
                              Jusqu'au {format(new Date(user.suspendedUntil!), 'dd/MM/yyyy HH:mm', { locale: fr })}
                            </p>
                          </div>
                        </div>
                        <Button
                          onClick={handleLiftSuspension}
                          disabled={actionLoading === 'lift'}
                          className="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-sm"
                        >
                          <Unlock size={14} />
                          Lever
                        </Button>
                      </div>
                    </div>
                  )}

                  {/* Action Buttons */}
                  {!isBanned && user.role !== 'ADMIN' && (
                    <div className="flex flex-wrap gap-2">
                      <Button
                        onClick={() => { setSanctionType('warn'); setShowSanctionModal(true); }}
                        className="flex items-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-sm"
                      >
                        <AlertTriangle size={14} />
                        Avertir
                      </Button>
                      <Button
                        onClick={() => { setSanctionType('suspend'); setShowSanctionModal(true); }}
                        className="flex items-center gap-2 bg-orange-500 hover:bg-orange-600 text-sm"
                      >
                        <Clock size={14} />
                        Suspendre
                      </Button>
                      <Button
                        onClick={() => { setSanctionType('ban'); setShowSanctionModal(true); }}
                        className="flex items-center gap-2 bg-red-500 hover:bg-red-600 text-sm"
                      >
                        <Ban size={14} />
                        Bannir
                      </Button>
                    </div>
                  )}
                </Card>

                {/* Tabs */}
                {detailsLoading ? (
                  <div className="flex items-center justify-center py-12">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" />
                  </div>
                ) : fullProfile && (
                  <>
                    <Card>
                      <div className="flex flex-wrap gap-2 border-b pb-3 mb-4">
                        {[
                          { key: 'bookings', label: 'RDV Véto', icon: Calendar, count: fullProfile.bookings.length },
                          { key: 'daycare', label: 'Garderie', icon: Home, count: fullProfile.daycareBookings.length },
                          { key: 'orders', label: 'Commandes', icon: ShoppingBag, count: fullProfile.orders.length },
                          { key: 'pets', label: 'Animaux', icon: PawPrint, count: fullProfile.pets.length },
                          { key: 'adoptions', label: 'Adoptions', icon: Heart, count: fullProfile.adoptPosts.length },
                          { key: 'flags', label: 'Flags', icon: Flag, count: fullProfile.flags.length },
                          { key: 'sanctions', label: 'Sanctions', icon: History, count: user.sanctions?.length || 0 },
                        ].map((tab) => (
                          <button
                            key={tab.key}
                            onClick={() => setActiveTab(tab.key as TabType)}
                            className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-colors ${
                              activeTab === tab.key
                                ? 'bg-primary-100 text-primary-700'
                                : 'text-gray-600 hover:bg-gray-100'
                            }`}
                          >
                            <tab.icon size={16} />
                            {tab.label}
                            <span className="bg-gray-200 text-gray-600 px-1.5 py-0.5 rounded text-xs">{tab.count}</span>
                          </button>
                        ))}
                      </div>

                      {/* Tab Content */}
                      <div className="max-h-[400px] overflow-y-auto">
                        {/* Bookings Tab */}
                        {activeTab === 'bookings' && (
                          <div className="space-y-2">
                            {fullProfile.bookings.length === 0 ? (
                              <p className="text-gray-500 text-center py-4">Aucun RDV</p>
                            ) : fullProfile.bookings.map((b: any) => (
                              <div key={b.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                                <div>
                                  <p className="font-medium">{b.service?.title || 'Service'}</p>
                                  <p className="text-xs text-gray-500">
                                    {b.provider?.displayName} • {format(new Date(b.scheduledAt), 'dd/MM/yyyy HH:mm')}
                                  </p>
                                  {b.referenceCode && <p className="text-xs text-gray-400">Réf: {b.referenceCode}</p>}
                                </div>
                                <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(b.status)}`}>
                                  {b.status}
                                </span>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Daycare Tab */}
                        {activeTab === 'daycare' && (
                          <div className="space-y-2">
                            {fullProfile.daycareBookings.length === 0 ? (
                              <p className="text-gray-500 text-center py-4">Aucune réservation garderie</p>
                            ) : fullProfile.daycareBookings.map((b: any) => (
                              <div key={b.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                                <div>
                                  <p className="font-medium">{b.pet?.name || 'Animal'}</p>
                                  <p className="text-xs text-gray-500">
                                    {b.provider?.displayName} • {format(new Date(b.startDate), 'dd/MM/yyyy')} → {format(new Date(b.endDate), 'dd/MM/yyyy')}
                                  </p>
                                  <p className="text-xs text-gray-400">{b.priceDa} DA {b.lateFeeDa ? `+ ${b.lateFeeDa} DA retard` : ''}</p>
                                </div>
                                <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(b.status)}`}>
                                  {b.status}
                                </span>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Orders Tab */}
                        {activeTab === 'orders' && (
                          <div className="space-y-2">
                            {fullProfile.orders.length === 0 ? (
                              <p className="text-gray-500 text-center py-4">Aucune commande</p>
                            ) : fullProfile.orders.map((o: any) => (
                              <div key={o.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                                <div>
                                  <p className="font-medium">{o.provider?.displayName || 'Animalerie'}</p>
                                  <p className="text-xs text-gray-500">
                                    {o.items?.length || 0} article(s) • {o.totalDa} DA
                                  </p>
                                  <p className="text-xs text-gray-400">{format(new Date(o.createdAt), 'dd/MM/yyyy HH:mm')}</p>
                                </div>
                                <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(o.status)}`}>
                                  {o.status}
                                </span>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Pets Tab */}
                        {activeTab === 'pets' && (
                          <div className="space-y-2">
                            {fullProfile.pets.length === 0 ? (
                              <p className="text-gray-500 text-center py-4">Aucun animal</p>
                            ) : fullProfile.pets.map((p: any) => (
                              <div key={p.id} className="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
                                {p.photoUrl ? (
                                  <img src={p.photoUrl} alt={p.name} className="w-12 h-12 rounded-lg object-cover" />
                                ) : (
                                  <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
                                    <PawPrint size={18} className="text-orange-500" />
                                  </div>
                                )}
                                <div>
                                  <p className="font-medium">{p.name}</p>
                                  <p className="text-xs text-gray-500">
                                    {p.species} {p.breed ? `• ${p.breed}` : ''} {p.gender !== 'UNKNOWN' ? `• ${p.gender}` : ''}
                                  </p>
                                  {p.birthDate && (
                                    <p className="text-xs text-gray-400">
                                      Né le {format(new Date(p.birthDate), 'dd/MM/yyyy')}
                                    </p>
                                  )}
                                </div>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Adoptions Tab */}
                        {activeTab === 'adoptions' && (
                          <div className="space-y-2">
                            {fullProfile.adoptPosts.length === 0 ? (
                              <p className="text-gray-500 text-center py-4">Aucune annonce</p>
                            ) : fullProfile.adoptPosts.map((p: any) => (
                              <div key={p.id} className="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
                                {p.images?.[0] ? (
                                  <img src={p.images[0]} alt={p.animalName} className="w-12 h-12 rounded-lg object-cover" />
                                ) : (
                                  <div className="w-12 h-12 bg-pink-100 rounded-lg flex items-center justify-center">
                                    <Heart size={18} className="text-pink-500" />
                                  </div>
                                )}
                                <div className="flex-1">
                                  <p className="font-medium">{p.animalName}</p>
                                  <p className="text-xs text-gray-500">{p.species} • {p.city}</p>
                                </div>
                                <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(p.status)}`}>
                                  {p.status}
                                </span>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Flags Tab */}
                        {activeTab === 'flags' && (
                          <div className="space-y-2">
                            {fullProfile.flags.length === 0 ? (
                              <p className="text-gray-500 text-center py-4">Aucun flag</p>
                            ) : fullProfile.flags.map((f: any) => (
                              <div key={f.id} className={`p-3 rounded-lg border ${f.resolved ? 'bg-gray-50 border-gray-200' : 'bg-red-50 border-red-200'}`}>
                                <div className="flex items-center justify-between">
                                  <div>
                                    <p className="font-medium">{f.type}</p>
                                    {f.note && <p className="text-xs text-gray-600 mt-1">{f.note}</p>}
                                    <p className="text-xs text-gray-400 mt-1">{format(new Date(f.createdAt), 'dd/MM/yyyy HH:mm')}</p>
                                  </div>
                                  <span className={`text-xs px-2 py-1 rounded-full ${f.resolved ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                                    {f.resolved ? 'Résolu' : 'Actif'}
                                  </span>
                                </div>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Sanctions Tab */}
                        {activeTab === 'sanctions' && (
                          <div className="space-y-2">
                            {(!user.sanctions || user.sanctions.length === 0) ? (
                              <p className="text-gray-500 text-center py-4">Aucune sanction</p>
                            ) : user.sanctions.map((s: any) => (
                              <div key={s.id} className={`p-3 rounded-lg border ${getSanctionTypeColor(s.type)}`}>
                                <div className="flex items-center justify-between">
                                  <div>
                                    <p className="font-bold">{s.type}</p>
                                    <p className="text-sm">{s.reason}</p>
                                    {s.duration && <p className="text-xs opacity-75">Durée: {s.duration} jour(s)</p>}
                                    <p className="text-xs opacity-75 mt-1">
                                      {format(new Date(s.issuedAt), 'dd/MM/yyyy HH:mm')}
                                    </p>
                                  </div>
                                  {s.liftedAt && (
                                    <span className="text-xs px-2 py-1 rounded-full bg-green-100 text-green-700">
                                      Levé
                                    </span>
                                  )}
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    </Card>

                    {/* Quotas */}
                    {quotas && (
                      <Card>
                        <h4 className="font-semibold text-gray-900 mb-4 flex items-center">
                          <Heart size={18} className="mr-2 text-pink-500" />
                          Quotas adoption
                        </h4>
                        <div className="grid grid-cols-2 gap-4">
                          <div className="p-4 bg-pink-50 rounded-lg border border-pink-100">
                            <p className="text-sm font-medium text-pink-700">Swipes</p>
                            <p className="text-2xl font-bold text-pink-600">
                              {quotas.swipesUsed} / {quotas.swipesUsed + quotas.swipesRemaining}
                            </p>
                          </div>
                          <div className="p-4 bg-blue-50 rounded-lg border border-blue-100">
                            <p className="text-sm font-medium text-blue-700">Annonces</p>
                            <p className="text-2xl font-bold text-blue-600">
                              {quotas.postsUsed} / {quotas.postsUsed + quotas.postsRemaining}
                            </p>
                          </div>
                        </div>
                      </Card>
                    )}
                  </>
                )}
              </div>
            ) : (
              <Card className="text-center py-16">
                <UserIcon size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez un utilisateur pour voir les détails</p>
              </Card>
            )}
          </div>
        </div>
      </div>

      {/* Edit Modal */}
      {showEditModal && selectedUser && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">Modifier l'utilisateur</h3>
              <button onClick={() => setShowEditModal(false)} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Prénom</label>
                <Input
                  value={editForm.firstName}
                  onChange={(e) => setEditForm({ ...editForm, firstName: e.target.value })}
                  placeholder="Prénom"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nom</label>
                <Input
                  value={editForm.lastName}
                  onChange={(e) => setEditForm({ ...editForm, lastName: e.target.value })}
                  placeholder="Nom"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <Input
                  value={editForm.email}
                  onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                  placeholder="Email"
                  type="email"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Téléphone</label>
                <Input
                  value={editForm.phone}
                  onChange={(e) => setEditForm({ ...editForm, phone: e.target.value })}
                  placeholder="Téléphone"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Ville</label>
                <Input
                  value={editForm.city}
                  onChange={(e) => setEditForm({ ...editForm, city: e.target.value })}
                  placeholder="Ville"
                />
              </div>
            </div>
            <div className="flex justify-end gap-3 mt-6">
              <Button onClick={() => setShowEditModal(false)} className="bg-gray-200 text-gray-700 hover:bg-gray-300">
                Annuler
              </Button>
              <Button
                onClick={handleUpdateUser}
                disabled={actionLoading === 'edit'}
                className="flex items-center gap-2"
              >
                <Save size={16} />
                Enregistrer
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Sanction Modal */}
      {showSanctionModal && selectedUser && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">
                {sanctionType === 'warn' && 'Avertissement'}
                {sanctionType === 'suspend' && 'Suspension'}
                {sanctionType === 'ban' && 'Bannissement'}
              </h3>
              <button onClick={() => setShowSanctionModal(false)} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Raison *</label>
                <textarea
                  value={sanctionReason}
                  onChange={(e) => setSanctionReason(e.target.value)}
                  placeholder="Expliquez la raison de cette sanction..."
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  rows={3}
                />
              </div>
              {sanctionType === 'suspend' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Durée (jours)</label>
                  <select
                    value={suspendDays}
                    onChange={(e) => setSuspendDays(Number(e.target.value))}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  >
                    <option value={1}>1 jour</option>
                    <option value={3}>3 jours</option>
                    <option value={7}>7 jours</option>
                    <option value={14}>14 jours</option>
                    <option value={30}>30 jours</option>
                    <option value={90}>90 jours</option>
                  </select>
                </div>
              )}
              {sanctionType === 'ban' && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-lg">
                  <p className="text-sm text-red-700">
                    <strong>Attention :</strong> Le bannissement est permanent. L'utilisateur ne pourra plus accéder à son compte.
                  </p>
                </div>
              )}
            </div>
            <div className="flex justify-end gap-3 mt-6">
              <Button onClick={() => setShowSanctionModal(false)} className="bg-gray-200 text-gray-700 hover:bg-gray-300">
                Annuler
              </Button>
              <Button
                onClick={handleSanction}
                disabled={actionLoading === 'sanction' || !sanctionReason.trim()}
                className={`flex items-center gap-2 ${
                  sanctionType === 'warn' ? 'bg-yellow-500 hover:bg-yellow-600' :
                  sanctionType === 'suspend' ? 'bg-orange-500 hover:bg-orange-600' :
                  'bg-red-500 hover:bg-red-600'
                }`}
              >
                {sanctionType === 'warn' && <AlertTriangle size={16} />}
                {sanctionType === 'suspend' && <Clock size={16} />}
                {sanctionType === 'ban' && <Ban size={16} />}
                Confirmer
              </Button>
            </div>
          </div>
        </div>
      )}
    </DashboardLayout>
  );
}
