import { useEffect, useState, useCallback } from 'react';
import { Search, User as UserIcon, Mail, Phone, MapPin, Heart, PawPrint, MessageSquare, ChevronRight, RefreshCw, Copy, Shield, Ban, CheckCircle, Unlock } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { User, AdoptPost, AdoptConversation } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

interface UserQuotas {
  swipesUsed: number;
  swipesRemaining: number;
  postsUsed: number;
  postsRemaining: number;
}

export function AdminUsers() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRole, setSelectedRole] = useState<string>('USER');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  // User details (only what backend supports - like Flutter app)
  const [quotas, setQuotas] = useState<UserQuotas | null>(null);
  const [adoptPosts, setAdoptPosts] = useState<AdoptPost[]>([]);
  const [adoptConversations, setAdoptConversations] = useState<AdoptConversation[]>([]);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [copied, setCopied] = useState<string | null>(null);
  const [resetTrustLoading, setResetTrustLoading] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, [searchQuery, selectedRole]);

  // Load user details when selected (matching Flutter app endpoints)
  const loadUserDetails = useCallback(async (user: User) => {
    setDetailsLoading(true);
    console.log('[AdminUsers] Loading details for user:', user.id);
    try {
      // Only call endpoints that actually exist (same as Flutter app)
      const [quotasData, adoptPostsData, adoptConvsData] = await Promise.all([
        api.adminGetUserQuotas(user.id),
        api.adminGetUserAdoptPosts(user.id),
        api.adminGetUserAdoptConversations(user.id),
      ]);

      console.log('[AdminUsers] quotasData:', quotasData);
      console.log('[AdminUsers] adoptPostsData:', adoptPostsData);
      console.log('[AdminUsers] adoptConvsData:', adoptConvsData);

      setQuotas(quotasData);
      setAdoptPosts(Array.isArray(adoptPostsData) ? adoptPostsData : []);
      setAdoptConversations(Array.isArray(adoptConvsData) ? adoptConvsData : []);
    } catch (error) {
      console.error('[AdminUsers] Error loading user details:', error);
      setQuotas(null);
      setAdoptPosts([]);
      setAdoptConversations([]);
    } finally {
      setDetailsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (selectedUser) {
      loadUserDetails(selectedUser);
    } else {
      setQuotas(null);
      setAdoptPosts([]);
      setAdoptConversations([]);
    }
  }, [selectedUser, loadUserDetails]);

  async function fetchUsers() {
    setLoading(true);
    try {
      const data = await api.adminListUsers(
        searchQuery || undefined,
        50,
        0,
        selectedRole || undefined
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

  const getRoleBadgeColor = (role: string) => {
    switch (role) {
      case 'ADMIN':
        return 'bg-purple-100 text-purple-700';
      case 'PRO':
        return 'bg-blue-100 text-blue-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  const getTrustStatusInfo = (status: string) => {
    switch (status) {
      case 'VERIFIED':
        return { label: 'Vérifié', color: 'bg-green-100 text-green-700 border-green-200', icon: CheckCircle };
      case 'RESTRICTED':
        return { label: 'Restreint', color: 'bg-red-100 text-red-700 border-red-200', icon: Ban };
      default:
        return { label: 'Nouveau', color: 'bg-blue-100 text-blue-700 border-blue-200', icon: UserIcon };
    }
  };

  const handleResetTrust = async () => {
    if (!selectedUser) return;

    const confirmed = window.confirm(
      `Réinitialiser le statut de confiance de ${getDisplayName(selectedUser)} ?\n\n` +
      `Cette action va:\n` +
      `• Remettre le statut à "VERIFIED"\n` +
      `• Décrémenter le compteur de no-show\n` +
      `• Lever la restriction de compte`
    );

    if (!confirmed) return;

    setResetTrustLoading(true);
    try {
      const result = await api.adminResetUserTrustStatus(selectedUser.id);
      // Update with user returned from backend (source of truth)
      const updatedUser = result.user || { ...selectedUser, trustStatus: 'VERIFIED', restrictedUntil: null, noShowCount: Math.max(0, (selectedUser.noShowCount || 0) - 1) };
      setSelectedUser(updatedUser);
      // Also update the user in the list to keep them in sync
      setUsers(prev => prev.map(u => u.id === selectedUser.id ? updatedUser : u));
      alert('✅ Statut de confiance réinitialisé à VERIFIED');
    } catch (error) {
      console.error('Error resetting trust status:', error);
      alert('Erreur lors de la réinitialisation du statut');
    } finally {
      setResetTrustLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'APPROVED':
        return 'bg-green-100 text-green-700';
      case 'REJECTED':
        return 'bg-red-100 text-red-700';
      case 'ARCHIVED':
        return 'bg-gray-100 text-gray-700';
      case 'CONFIRMED':
        return 'bg-green-100 text-green-700';
      case 'CANCELLED':
        return 'bg-red-100 text-red-700';
      case 'COMPLETED':
        return 'bg-blue-100 text-blue-700';
      default:
        return 'bg-yellow-100 text-yellow-700';
    }
  };

  async function copyToClipboard(text: string, type: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(type);
      setTimeout(() => setCopied(null), 2000);
    } catch {
      // Fallback
    }
  }

  // Build display name helper
  const getDisplayName = (user: User) => {
    const firstName = user.firstName || '';
    const lastName = user.lastName || '';
    return [firstName, lastName].filter(Boolean).join(' ').trim() || '(Sans nom)';
  };

  const getAvatarLetter = (user: User) => {
    return (getDisplayName(user) || user.email || '?').charAt(0).toUpperCase();
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {selectedRole === 'USER' ? 'Clients' : selectedRole === 'PRO' ? 'Professionnels' : 'Utilisateurs'}
          </h1>
          <p className="text-gray-600 mt-1">Gérez les utilisateurs de la plateforme</p>
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
              <option value="USER">Utilisateurs</option>
              <option value="PRO">Professionnels</option>
              <option value="ADMIN">Administrateurs</option>
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
                {users.map((user) => (
                  <Card
                    key={user.id}
                    className={`cursor-pointer transition-all ${
                      selectedUser?.id === user.id
                        ? 'ring-2 ring-primary-500'
                        : 'hover:shadow-md'
                    }`}
                    onClick={() => setSelectedUser(user)}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        {user.photoUrl ? (
                          <img
                            src={user.photoUrl}
                            alt={user.email}
                            className="w-10 h-10 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
                            <span className="text-primary-700 font-bold">
                              {getAvatarLetter(user)}
                            </span>
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-2">
                            <p className="font-medium text-gray-900 truncate">
                              {getDisplayName(user)}
                            </p>
                            {/* Trust status badge */}
                            {user.trustStatus === 'RESTRICTED' && (
                              <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-red-100 text-red-700">
                                🚫
                              </span>
                            )}
                            {user.trustStatus === 'VERIFIED' && (
                              <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-green-100 text-green-700">
                                ✓
                              </span>
                            )}
                          </div>
                          <p className="text-xs text-gray-500 truncate">{user.email}</p>
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
            {selectedUser ? (
              <div className="space-y-4">
                {/* User Info Card */}
                <Card>
                  <div className="flex items-start space-x-4 mb-4">
                    {selectedUser.photoUrl ? (
                      <img
                        src={selectedUser.photoUrl}
                        alt={selectedUser.email}
                        className="w-16 h-16 rounded-full object-cover"
                      />
                    ) : (
                      <div className="w-16 h-16 bg-primary-100 rounded-full flex items-center justify-center">
                        <span className="text-primary-700 font-bold text-2xl">
                          {getAvatarLetter(selectedUser)}
                        </span>
                      </div>
                    )}
                    <div className="flex-1">
                      <div className="flex items-center space-x-2">
                        <h3 className="text-xl font-bold text-gray-900">{getDisplayName(selectedUser)}</h3>
                        <span className={`text-xs px-2 py-0.5 rounded-full ${getRoleBadgeColor(selectedUser.role)}`}>
                          {selectedUser.role}
                        </span>
                      </div>
                      <p className="text-sm text-gray-500 mt-1">
                        Inscrit le {format(new Date(selectedUser.createdAt), 'dd MMMM yyyy', { locale: fr })}
                      </p>
                    </div>
                    <button
                      onClick={() => loadUserDetails(selectedUser)}
                      className="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100"
                      title="Rafraîchir"
                    >
                      <RefreshCw size={16} />
                    </button>
                  </div>

                  {/* Contact info */}
                  <div className="border-t pt-4 space-y-3">
                    <h4 className="font-semibold text-gray-900 mb-3">Coordonnées</h4>

                    <div className="flex items-center justify-between text-sm">
                      <div className="flex items-center space-x-2">
                        <Mail size={16} className="text-gray-400" />
                        <span>{selectedUser.email}</span>
                      </div>
                      <button onClick={() => copyToClipboard(selectedUser.email, 'email')} className="text-gray-400 hover:text-gray-600">
                        <Copy size={14} />
                        {copied === 'email' && <span className="ml-1 text-green-600 text-xs">Copié!</span>}
                      </button>
                    </div>

                    {selectedUser.phone && (
                      <div className="flex items-center justify-between text-sm">
                        <div className="flex items-center space-x-2">
                          <Phone size={16} className="text-gray-400" />
                          <span>{selectedUser.phone}</span>
                        </div>
                        <button onClick={() => copyToClipboard(selectedUser.phone!, 'phone')} className="text-gray-400 hover:text-gray-600">
                          <Copy size={14} />
                          {copied === 'phone' && <span className="ml-1 text-green-600 text-xs">Copié!</span>}
                        </button>
                      </div>
                    )}

                    {selectedUser.city && (
                      <div className="flex items-center space-x-2 text-sm">
                        <MapPin size={16} className="text-gray-400" />
                        <span>{selectedUser.city}</span>
                      </div>
                    )}
                  </div>
                </Card>

                {/* Trust Status Card */}
                <Card>
                  <h4 className="font-semibold text-gray-900 mb-4 flex items-center">
                    <Shield size={18} className="mr-2 text-indigo-500" />
                    Statut de confiance
                  </h4>

                  {(() => {
                    const trustInfo = getTrustStatusInfo(selectedUser.trustStatus || 'NEW');
                    const TrustIcon = trustInfo.icon;
                    return (
                      <div className={`p-4 rounded-lg border ${trustInfo.color}`}>
                        <div className="flex items-center justify-between">
                          <div className="flex items-center space-x-3">
                            <TrustIcon size={24} />
                            <div>
                              <p className="font-bold text-lg">{trustInfo.label}</p>
                              {selectedUser.trustStatus === 'RESTRICTED' && selectedUser.restrictedUntil && (
                                <p className="text-sm opacity-75">
                                  Jusqu'au {format(new Date(selectedUser.restrictedUntil), 'dd/MM/yyyy', { locale: fr })}
                                </p>
                              )}
                            </div>
                          </div>
                          {(selectedUser.trustStatus === 'RESTRICTED' || selectedUser.trustStatus === 'NEW') && (
                            <Button
                              onClick={handleResetTrust}
                              disabled={resetTrustLoading}
                              className="flex items-center gap-2 bg-green-600 hover:bg-green-700"
                            >
                              {resetTrustLoading ? (
                                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                              ) : (
                                <Unlock size={16} />
                              )}
                              {selectedUser.trustStatus === 'RESTRICTED' ? 'Lever restriction' : 'Passer à Verified'}
                            </Button>
                          )}
                        </div>
                        {selectedUser.noShowCount !== undefined && selectedUser.noShowCount > 0 && (
                          <p className="mt-3 text-sm opacity-75">
                            No-shows: {selectedUser.noShowCount}
                          </p>
                        )}
                      </div>
                    );
                  })()}
                </Card>

                {detailsLoading ? (
                  <div className="flex items-center justify-center py-12">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" />
                  </div>
                ) : (
                  <>
                    {/* Quotas Card */}
                    <Card>
                      <h4 className="font-semibold text-gray-900 mb-4 flex items-center">
                        <Heart size={18} className="mr-2 text-pink-500" />
                        Quotas adoption
                      </h4>

                      <div className="grid grid-cols-2 gap-4">
                        {/* Swipes quota */}
                        <div className="p-4 bg-pink-50 rounded-lg border border-pink-100">
                          <div className="flex items-center space-x-2 mb-2">
                            <Heart size={16} className="text-pink-500" />
                            <span className="text-sm font-medium text-pink-700">Swipes (likes)</span>
                          </div>
                          <p className="text-2xl font-bold text-pink-600">
                            {quotas?.swipesUsed || 0} / {(quotas?.swipesUsed || 0) + (quotas?.swipesRemaining || 5)}
                          </p>
                          <div className="mt-2 h-2 bg-pink-200 rounded-full overflow-hidden">
                            <div
                              className="h-full bg-pink-500 rounded-full transition-all"
                              style={{
                                width: `${Math.min(100, ((quotas?.swipesUsed || 0) / ((quotas?.swipesUsed || 0) + (quotas?.swipesRemaining || 5))) * 100)}%`
                              }}
                            />
                          </div>
                        </div>

                        {/* Posts quota */}
                        <div className="p-4 bg-blue-50 rounded-lg border border-blue-100">
                          <div className="flex items-center space-x-2 mb-2">
                            <PawPrint size={16} className="text-blue-500" />
                            <span className="text-sm font-medium text-blue-700">Annonces</span>
                          </div>
                          <p className="text-2xl font-bold text-blue-600">
                            {quotas?.postsUsed || 0} / {(quotas?.postsUsed || 0) + (quotas?.postsRemaining || 1)}
                          </p>
                          <div className="mt-2 h-2 bg-blue-200 rounded-full overflow-hidden">
                            <div
                              className="h-full bg-blue-500 rounded-full transition-all"
                              style={{
                                width: `${Math.min(100, ((quotas?.postsUsed || 0) / ((quotas?.postsUsed || 0) + (quotas?.postsRemaining || 1))) * 100)}%`
                              }}
                            />
                          </div>
                        </div>
                      </div>
                    </Card>

                    {/* Adopt Posts Card */}
                    <Card>
                      <h4 className="font-semibold text-gray-900 mb-4 flex items-center">
                        <PawPrint size={18} className="mr-2 text-orange-500" />
                        Annonces adoption ({adoptPosts.length})
                      </h4>

                      {adoptPosts.length === 0 ? (
                        <p className="text-gray-500 text-sm text-center py-4">Aucune annonce</p>
                      ) : (
                        <div className="space-y-2">
                          {adoptPosts.map((post) => {
                            const postName = post.animalName || post.name || post.title || 'Animal';
                            const postLocation = post.city || post.location || '';
                            return (
                              <div key={post.id} className="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
                                {post.images?.[0]?.url ? (
                                  <img src={post.images[0].url} alt={postName} className="w-12 h-12 rounded-lg object-cover" />
                                ) : (
                                  <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
                                    <PawPrint size={18} className="text-orange-500" />
                                  </div>
                                )}
                                <div className="flex-1 min-w-0">
                                  <p className="font-medium text-gray-900 truncate">{postName}</p>
                                  <p className="text-xs text-gray-500">{post.species}{postLocation ? ` • ${postLocation}` : ''}</p>
                                </div>
                                <span className={`text-xs px-2 py-0.5 rounded-full ${getStatusColor(post.status)}`}>
                                  {post.status}
                                </span>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </Card>

                    {/* Conversations Card */}
                    <Card>
                      <h4 className="font-semibold text-gray-900 mb-4 flex items-center">
                        <MessageSquare size={18} className="mr-2 text-indigo-500" />
                        Conversations adoption ({adoptConversations.length})
                      </h4>

                      {adoptConversations.length === 0 ? (
                        <p className="text-gray-500 text-sm text-center py-4">Aucune conversation</p>
                      ) : (
                        <div className="space-y-2">
                          {adoptConversations.slice(0, 5).map((conv) => {
                            const post = conv.post as Record<string, unknown> | undefined;
                            const animalName = (post?.animalName as string) || (post?.title as string) || 'Animal';
                            const isOwner = conv.ownerId === selectedUser?.id;

                            return (
                              <div key={conv.id} className="p-3 bg-gray-50 rounded-lg">
                                <div className="flex items-center justify-between">
                                  <div>
                                    <p className="font-medium text-gray-900 text-sm">{animalName}</p>
                                    <p className="text-xs text-gray-500">
                                      {isOwner ? 'Propriétaire' : 'Adoptant'}
                                    </p>
                                  </div>
                                  <span className={`text-xs px-2 py-0.5 rounded-full ${
                                    isOwner ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700'
                                  }`}>
                                    {isOwner ? 'Proprio' : 'Adoptant'}
                                  </span>
                                </div>
                              </div>
                            );
                          })}
                          {adoptConversations.length > 5 && (
                            <p className="text-xs text-gray-500 text-center">+{adoptConversations.length - 5} autres</p>
                          )}
                        </div>
                      )}
                    </Card>
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
    </DashboardLayout>
  );
}
