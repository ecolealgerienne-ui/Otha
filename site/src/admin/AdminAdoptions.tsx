import { useEffect, useState } from 'react';
import { Check, X, Heart, Clock, CheckCircle, XCircle, Archive, CheckCheck, ChevronLeft, ChevronRight, MapPin, RotateCcw, Info, User, Mail, Phone } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { AdoptPost, AdoptPostStatus } from '../types';

type TabStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'ARCHIVED';

export function AdminAdoptions() {
  const [activeTab, setActiveTab] = useState<TabStatus>('PENDING');
  const [posts, setPosts] = useState<AdoptPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [showDetails, setShowDetails] = useState(false);
  const [counts, setCounts] = useState<Record<string, number>>({});

  useEffect(() => {
    fetchPosts(activeTab);
  }, [activeTab]);

  useEffect(() => {
    setCurrentIndex(0);
    setCurrentImageIndex(0);
    setShowDetails(false);
  }, [activeTab]);

  async function fetchPosts(status: AdoptPostStatus) {
    setLoading(true);
    setError(null);
    try {
      const response = await api.adminAdoptList(status, 100);
      const allPosts = response?.data || [];
      setPosts(Array.isArray(allPosts) ? allPosts : []);
      if (response?.counts) {
        setCounts(response.counts);
      }
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('[AdminAdoptions] Error fetching posts:', err);
      setError(errorMessage);
      setPosts([]);
    } finally {
      setLoading(false);
    }
  }

  async function handleApprove(postId: string) {
    setActionLoading(postId);
    try {
      await api.adminAdoptApprove(postId);
      setPosts((prev) => prev.filter((p) => p.id !== postId));
      setCurrentImageIndex(0);
      setShowDetails(false);
      // Update counts
      setCounts(prev => ({
        ...prev,
        PENDING: Math.max(0, (prev.PENDING || 0) - 1),
        APPROVED: (prev.APPROVED || 0) + 1
      }));
    } catch (error) {
      console.error('Error approving post:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleReject(postId: string) {
    setActionLoading(postId);
    try {
      await api.adminAdoptReject(postId);
      setPosts((prev) => prev.filter((p) => p.id !== postId));
      setCurrentImageIndex(0);
      setShowDetails(false);
      setCounts(prev => ({
        ...prev,
        PENDING: Math.max(0, (prev.PENDING || 0) - 1),
        REJECTED: (prev.REJECTED || 0) + 1
      }));
    } catch (error) {
      console.error('Error rejecting post:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleArchive(postId: string) {
    setActionLoading(postId);
    try {
      await api.adminAdoptArchive(postId);
      setPosts((prev) => prev.filter((p) => p.id !== postId));
      setCounts(prev => ({
        ...prev,
        APPROVED: Math.max(0, (prev.APPROVED || 0) - 1),
        ARCHIVED: (prev.ARCHIVED || 0) + 1
      }));
    } catch (error) {
      console.error('Error archiving post:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleApproveAll() {
    setActionLoading('all');
    try {
      const result = await api.adminAdoptApproveAll();
      alert(`${result.count} annonces approuvées`);
      fetchPosts('PENDING');
    } catch (error) {
      console.error('Error approving all:', error);
    } finally {
      setActionLoading(null);
    }
  }

  const currentPost = posts[currentIndex];
  const images = currentPost?.images || [];

  const tabs: { status: TabStatus; label: string; icon: React.ReactNode }[] = [
    { status: 'PENDING', label: 'En attente', icon: <Clock size={16} /> },
    { status: 'APPROVED', label: 'Approuvées', icon: <CheckCircle size={16} /> },
    { status: 'REJECTED', label: 'Rejetées', icon: <XCircle size={16} /> },
    { status: 'ARCHIVED', label: 'Archivées', icon: <Archive size={16} /> },
  ];

  const getPostName = (post: AdoptPost) => post.name || post.animalName || post.title || 'Sans nom';
  const getPostLocation = (post: AdoptPost) => post.location || post.city;

  // Tinder-style card for PENDING
  const renderTinderCard = () => {
    if (!currentPost) {
      return (
        <div className="flex flex-col items-center justify-center h-[500px] bg-gradient-to-b from-gray-50 to-gray-100 rounded-3xl">
          <div className="w-24 h-24 bg-green-100 rounded-full flex items-center justify-center mb-4">
            <CheckCircle size={48} className="text-green-500" />
          </div>
          <h3 className="text-xl font-semibold text-gray-800 mb-2">Tout est traité !</h3>
          <p className="text-gray-500">Aucune annonce en attente de modération</p>
        </div>
      );
    }

    return (
      <div className="relative">
        {/* Card Stack Effect */}
        {posts.length > 1 && (
          <>
            <div className="absolute -bottom-2 left-4 right-4 h-[500px] bg-white rounded-3xl shadow-lg opacity-60 -z-10" />
            {posts.length > 2 && (
              <div className="absolute -bottom-4 left-8 right-8 h-[500px] bg-white rounded-3xl shadow-md opacity-30 -z-20" />
            )}
          </>
        )}

        {/* Main Card */}
        <div className="relative bg-white rounded-3xl shadow-2xl overflow-hidden">
          {/* Image Container */}
          <div className="relative h-[400px] bg-gray-200">
            {images.length > 0 ? (
              <img
                src={images[currentImageIndex]?.url}
                alt={getPostName(currentPost)}
                className="w-full h-full object-cover"
                onError={(e) => {
                  (e.target as HTMLImageElement).src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect fill="%23f3f4f6" width="100" height="100"/><text x="50" y="55" text-anchor="middle" fill="%239ca3af" font-size="40">🐾</text></svg>';
                }}
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary-100 to-primary-200">
                <Heart size={80} className="text-primary-300" />
              </div>
            )}

            {/* Image Navigation */}
            {images.length > 1 && (
              <>
                {/* Dots indicator */}
                <div className="absolute top-4 left-0 right-0 flex justify-center gap-1.5 px-4">
                  {images.map((_, idx) => (
                    <div
                      key={idx}
                      className={`h-1 flex-1 max-w-12 rounded-full transition-all ${
                        idx === currentImageIndex ? 'bg-white' : 'bg-white/40'
                      }`}
                    />
                  ))}
                </div>

                {/* Left/Right tap zones */}
                <button
                  className="absolute left-0 top-0 bottom-0 w-1/3 flex items-center justify-start pl-2"
                  onClick={() => setCurrentImageIndex(i => Math.max(0, i - 1))}
                >
                  {currentImageIndex > 0 && (
                    <div className="w-8 h-8 bg-black/20 backdrop-blur rounded-full flex items-center justify-center">
                      <ChevronLeft size={20} className="text-white" />
                    </div>
                  )}
                </button>
                <button
                  className="absolute right-0 top-0 bottom-0 w-1/3 flex items-center justify-end pr-2"
                  onClick={() => setCurrentImageIndex(i => Math.min(images.length - 1, i + 1))}
                >
                  {currentImageIndex < images.length - 1 && (
                    <div className="w-8 h-8 bg-black/20 backdrop-blur rounded-full flex items-center justify-center">
                      <ChevronRight size={20} className="text-white" />
                    </div>
                  )}
                </button>
              </>
            )}

            {/* Gradient overlay */}
            <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-black/70 to-transparent" />

            {/* Info overlay */}
            <div className="absolute bottom-0 left-0 right-0 p-5 text-white">
              <div className="flex items-end justify-between">
                <div>
                  <h2 className="text-2xl font-bold mb-1">{getPostName(currentPost)}</h2>
                  <div className="flex items-center gap-3 text-white/90">
                    <span className="bg-white/20 backdrop-blur px-3 py-1 rounded-full text-sm">
                      {currentPost.species}
                    </span>
                    {currentPost.sex && (
                      <span className="text-sm">{currentPost.sex === 'M' ? '♂ Mâle' : currentPost.sex === 'F' ? '♀ Femelle' : ''}</span>
                    )}
                  </div>
                  {getPostLocation(currentPost) && (
                    <div className="flex items-center gap-1 mt-2 text-white/80 text-sm">
                      <MapPin size={14} />
                      <span>{getPostLocation(currentPost)}</span>
                    </div>
                  )}
                </div>
                <button
                  onClick={() => setShowDetails(!showDetails)}
                  className="w-10 h-10 bg-white/20 backdrop-blur rounded-full flex items-center justify-center hover:bg-white/30 transition-colors"
                >
                  <Info size={20} />
                </button>
              </div>
            </div>

            {/* Counter badge */}
            <div className="absolute top-4 right-4 bg-black/40 backdrop-blur px-3 py-1 rounded-full text-white text-sm">
              {currentIndex + 1} / {posts.length}
            </div>
          </div>

          {/* Details Section (expandable) */}
          {showDetails && (
            <div className="p-5 border-t bg-gray-50 animate-in slide-in-from-top duration-200">
              {/* User info */}
              <div className="bg-white rounded-lg p-3 mb-4 border border-gray-200">
                <div className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
                  <User size={16} />
                  <span>Publié par</span>
                </div>
                {currentPost.createdBy ? (
                  <div className="space-y-1.5">
                    <p className="font-semibold text-gray-900">
                      {currentPost.createdBy.firstName || ''} {currentPost.createdBy.lastName || ''}
                      {!currentPost.createdBy.firstName && !currentPost.createdBy.lastName && 'Utilisateur anonyme'}
                    </p>
                    {currentPost.createdBy.email && (
                      <div className="flex items-center gap-2 text-sm text-gray-600">
                        <Mail size={14} />
                        <span>{currentPost.createdBy.email}</span>
                      </div>
                    )}
                    {currentPost.createdBy.phone && (
                      <div className="flex items-center gap-2 text-sm text-gray-600">
                        <Phone size={14} />
                        <span>{currentPost.createdBy.phone}</span>
                      </div>
                    )}
                    <p className="text-xs text-gray-400 font-mono">ID: {currentPost.createdBy.id}</p>
                  </div>
                ) : (
                  <p className="text-gray-400 text-sm">Informations non disponibles</p>
                )}
              </div>

              {/* Description */}
              {currentPost.description ? (
                <p className="text-gray-700">{currentPost.description}</p>
              ) : (
                <p className="text-gray-400 italic">Pas de description</p>
              )}
              {currentPost.age && (
                <p className="text-gray-600 mt-2">
                  <span className="font-medium">Âge:</span> {currentPost.age}
                </p>
              )}
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex items-center justify-center gap-6 py-6 bg-white">
            {/* Reject Button */}
            <button
              onClick={() => handleReject(currentPost.id)}
              disabled={actionLoading === currentPost.id}
              className="w-16 h-16 bg-white border-2 border-red-400 rounded-full flex items-center justify-center shadow-lg hover:scale-110 hover:bg-red-50 transition-all disabled:opacity-50 disabled:hover:scale-100"
            >
              {actionLoading === currentPost.id ? (
                <div className="w-6 h-6 border-2 border-red-400 border-t-transparent rounded-full animate-spin" />
              ) : (
                <X size={28} className="text-red-500" />
              )}
            </button>

            {/* Skip to next (if multiple) */}
            {posts.length > 1 && (
              <button
                onClick={() => {
                  setCurrentIndex(i => (i + 1) % posts.length);
                  setCurrentImageIndex(0);
                  setShowDetails(false);
                }}
                className="w-12 h-12 bg-white border-2 border-gray-300 rounded-full flex items-center justify-center shadow-md hover:scale-105 transition-all"
              >
                <RotateCcw size={20} className="text-gray-500" />
              </button>
            )}

            {/* Approve Button */}
            <button
              onClick={() => handleApprove(currentPost.id)}
              disabled={actionLoading === currentPost.id}
              className="w-16 h-16 bg-gradient-to-br from-green-400 to-green-500 rounded-full flex items-center justify-center shadow-lg hover:scale-110 hover:from-green-500 hover:to-green-600 transition-all disabled:opacity-50 disabled:hover:scale-100"
            >
              {actionLoading === currentPost.id ? (
                <div className="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <Check size={28} className="text-white" />
              )}
            </button>
          </div>
        </div>
      </div>
    );
  };

  // List view for other tabs
  const renderListView = () => {
    if (posts.length === 0) {
      return (
        <Card className="text-center py-16">
          <Heart size={64} className="text-gray-200 mx-auto mb-4" />
          <p className="text-gray-500 text-lg">Aucune annonce {
            activeTab === 'APPROVED' ? 'approuvée' :
            activeTab === 'REJECTED' ? 'rejetée' : 'archivée'
          }</p>
        </Card>
      );
    }

    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {posts.map((post) => (
          <div
            key={post.id}
            className="bg-white rounded-xl shadow-md overflow-hidden hover:shadow-lg transition-shadow"
          >
            {/* Image */}
            <div className="relative h-48 bg-gray-100">
              {post.images && post.images[0] ? (
                <img
                  src={post.images[0].url}
                  alt={getPostName(post)}
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    (e.target as HTMLImageElement).src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect fill="%23f3f4f6" width="100" height="100"/><text x="50" y="55" text-anchor="middle" fill="%239ca3af" font-size="40">🐾</text></svg>';
                  }}
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <Heart size={40} className="text-gray-300" />
                </div>
              )}

              {/* Status badge */}
              <div className={`absolute top-3 right-3 px-2 py-1 rounded-full text-xs font-medium ${
                activeTab === 'APPROVED' ? 'bg-green-100 text-green-700' :
                activeTab === 'REJECTED' ? 'bg-red-100 text-red-700' :
                'bg-gray-100 text-gray-700'
              }`}>
                {activeTab === 'APPROVED' ? 'Approuvée' :
                 activeTab === 'REJECTED' ? 'Rejetée' : 'Archivée'}
              </div>
            </div>

            {/* Content */}
            <div className="p-4">
              <div className="flex items-start justify-between mb-2">
                <div>
                  <h3 className="font-semibold text-gray-900">{getPostName(post)}</h3>
                  <span className="text-sm text-gray-500">{post.species}</span>
                </div>
              </div>

              {getPostLocation(post) && (
                <div className="flex items-center gap-1 text-gray-500 text-sm mb-2">
                  <MapPin size={14} />
                  <span>{getPostLocation(post)}</span>
                </div>
              )}

              {/* User info */}
              {post.createdBy && (
                <div className="flex items-center gap-2 text-xs text-gray-500 mb-3 bg-gray-50 rounded px-2 py-1.5">
                  <User size={12} />
                  <span className="truncate">
                    {post.createdBy.firstName || post.createdBy.lastName
                      ? `${post.createdBy.firstName || ''} ${post.createdBy.lastName || ''}`.trim()
                      : post.createdBy.email || 'Anonyme'}
                  </span>
                </div>
              )}

              {/* Actions */}
              <div className="flex gap-2">
                {activeTab === 'REJECTED' && (
                  <Button
                    size="sm"
                    className="flex-1"
                    onClick={() => handleApprove(post.id)}
                    isLoading={actionLoading === post.id}
                  >
                    <RotateCcw size={14} className="mr-1" />
                    Réapprouver
                  </Button>
                )}
                {activeTab === 'APPROVED' && (
                  <Button
                    size="sm"
                    variant="secondary"
                    className="flex-1"
                    onClick={() => handleArchive(post.id)}
                    isLoading={actionLoading === post.id}
                  >
                    <Archive size={14} className="mr-1" />
                    Archiver
                  </Button>
                )}
                {activeTab === 'ARCHIVED' && (
                  <Button
                    size="sm"
                    className="flex-1"
                    onClick={() => handleApprove(post.id)}
                    isLoading={actionLoading === post.id}
                  >
                    <RotateCcw size={14} className="mr-1" />
                    Restaurer
                  </Button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Modération Adoptions</h1>
            <p className="text-gray-600 mt-1">Gérez les annonces d'adoption</p>
          </div>
          {activeTab === 'PENDING' && posts.length > 1 && (
            <Button
              onClick={handleApproveAll}
              isLoading={actionLoading === 'all'}
            >
              <CheckCheck size={16} className="mr-2" />
              Tout approuver ({posts.length})
            </Button>
          )}
        </div>

        {/* Tabs */}
        <div className="flex flex-wrap gap-2">
          {tabs.map((tab) => {
            const count = counts[tab.status] || (activeTab === tab.status ? posts.length : 0);
            return (
              <button
                key={tab.status}
                onClick={() => setActiveTab(tab.status)}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-xl font-medium transition-all ${
                  activeTab === tab.status
                    ? 'bg-primary-600 text-white shadow-md'
                    : 'bg-white text-gray-600 hover:bg-gray-50 border border-gray-200'
                }`}
              >
                {tab.icon}
                <span>{tab.label}</span>
                {count > 0 && (
                  <span className={`px-2 py-0.5 rounded-full text-xs ${
                    activeTab === tab.status
                      ? 'bg-white/20 text-white'
                      : 'bg-gray-100 text-gray-600'
                  }`}>
                    {count}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Content */}
        {loading ? (
          <div className="flex items-center justify-center h-[500px]">
            <div className="text-center">
              <div className="w-16 h-16 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin mx-auto mb-4" />
              <p className="text-gray-500">Chargement des annonces...</p>
            </div>
          </div>
        ) : error ? (
          <Card className="text-center py-16">
            <XCircle size={64} className="text-red-300 mx-auto mb-4" />
            <p className="text-red-600 font-medium mb-2">Erreur de chargement</p>
            <p className="text-gray-500 text-sm mb-4">{error}</p>
            <Button onClick={() => fetchPosts(activeTab)} size="sm">
              Réessayer
            </Button>
          </Card>
        ) : activeTab === 'PENDING' ? (
          <div className="max-w-md mx-auto">
            {renderTinderCard()}
          </div>
        ) : (
          renderListView()
        )}
      </div>
    </DashboardLayout>
  );
}
