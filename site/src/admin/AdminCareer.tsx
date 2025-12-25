import { useEffect, useState } from 'react';
import {
  Check, X, Clock, CheckCircle, XCircle, Archive, CheckCheck, ChevronDown, ChevronUp,
  MapPin, User, Mail, Phone, Briefcase, FileText, MessageSquare, DollarSign, Calendar,
  Building, Eye
} from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

type TabStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'ARCHIVED';
type PostType = 'REQUEST' | 'OFFER' | null;

interface CareerPost {
  id: string;
  type: 'REQUEST' | 'OFFER';
  status: TabStatus;
  title: string;
  publicBio: string;
  city?: string;
  domain?: string;
  duration?: string;
  fullName?: string;
  email?: string;
  phone?: string;
  detailedBio?: string;
  cvImageUrl?: string;
  salary?: string;
  requirements?: string;
  moderationNote?: string;
  createdAt: string;
  approvedAt?: string;
  rejectedAt?: string;
  archivedAt?: string;
  createdBy: {
    id: string;
    firstName?: string;
    lastName?: string;
    email?: string;
    phone?: string;
    photoUrl?: string;
    role?: string;
  };
  _count?: {
    conversations: number;
  };
}

interface ConversationMessage {
  id: string;
  content: string;
  createdAt: string;
  sender: {
    id: string;
    firstName?: string;
    lastName?: string;
    photoUrl?: string;
  };
}

interface Conversation {
  id: string;
  participantAnonymousName?: string;
  createdAt: string;
  updatedAt: string;
  participant: {
    id: string;
    firstName?: string;
    lastName?: string;
    email?: string;
    phone?: string;
    photoUrl?: string;
    role?: string;
  };
  messages: ConversationMessage[];
  _count: {
    messages: number;
  };
}

export function AdminCareer() {
  const [activeTab, setActiveTab] = useState<TabStatus>('PENDING');
  const [typeFilter, setTypeFilter] = useState<PostType>(null);
  const [posts, setPosts] = useState<CareerPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [expandedPost, setExpandedPost] = useState<string | null>(null);
  const [selectedPost, setSelectedPost] = useState<CareerPost | null>(null);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loadingConversations, setLoadingConversations] = useState(false);
  const [expandedConversation, setExpandedConversation] = useState<string | null>(null);

  useEffect(() => {
    fetchPosts();
  }, [activeTab, typeFilter]);

  async function fetchPosts() {
    setLoading(true);
    setError(null);
    try {
      const response = await api.adminCareerList(activeTab, typeFilter || undefined, 100);
      const allPosts = response?.data || [];
      setPosts(Array.isArray(allPosts) ? allPosts : []);
      if (response?.counts) {
        setCounts(response.counts);
      }
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('[AdminCareer] Error fetching posts:', err);
      setError(errorMessage);
      setPosts([]);
    } finally {
      setLoading(false);
    }
  }

  async function handleApprove(postId: string) {
    setActionLoading(postId);
    try {
      await api.adminCareerApprove(postId);
      setPosts((prev) => prev.filter((p) => p.id !== postId));
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

  async function handleReject(postId: string, note?: string) {
    setActionLoading(postId);
    try {
      await api.adminCareerReject(postId, undefined, note);
      setPosts((prev) => prev.filter((p) => p.id !== postId));
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
      await api.adminCareerArchive(postId);
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
      const result = await api.adminCareerApproveAll();
      alert(`${result.count} annonces approuvees`);
      fetchPosts();
    } catch (error) {
      console.error('Error approving all:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function loadConversations(post: CareerPost) {
    setSelectedPost(post);
    setLoadingConversations(true);
    try {
      const convs = await api.adminCareerGetPostConversations(post.id);
      setConversations(convs || []);
    } catch (error) {
      console.error('Error loading conversations:', error);
      setConversations([]);
    } finally {
      setLoadingConversations(false);
    }
  }

  const tabs: { status: TabStatus; label: string; icon: React.ReactNode }[] = [
    { status: 'PENDING', label: 'En attente', icon: <Clock size={16} /> },
    { status: 'APPROVED', label: 'Approuvees', icon: <CheckCircle size={16} /> },
    { status: 'REJECTED', label: 'Rejetees', icon: <XCircle size={16} /> },
    { status: 'ARCHIVED', label: 'Archivees', icon: <Archive size={16} /> },
  ];

  const typeFilters: { value: PostType; label: string }[] = [
    { value: null, label: 'Tous' },
    { value: 'REQUEST', label: 'Demandes' },
    { value: 'OFFER', label: 'Offres' },
  ];

  const getTypeBadge = (type: 'REQUEST' | 'OFFER') => (
    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
      type === 'REQUEST'
        ? 'bg-purple-100 text-purple-700'
        : 'bg-green-100 text-green-700'
    }`}>
      {type === 'REQUEST' ? 'Demande' : 'Offre'}
    </span>
  );

  const formatDate = (dateStr: string) => {
    try {
      return format(new Date(dateStr), 'dd MMM yyyy HH:mm', { locale: fr });
    } catch {
      return dateStr;
    }
  };

  const renderPostCard = (post: CareerPost) => {
    const isExpanded = expandedPost === post.id;
    const isLoading = actionLoading === post.id;

    return (
      <Card key={post.id} className="mb-4 overflow-hidden">
        {/* Header */}
        <div className="p-4 border-b bg-gray-50">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-2">
                {getTypeBadge(post.type)}
                <span className="text-sm text-gray-500">
                  {formatDate(post.createdAt)}
                </span>
                {post._count && post._count.conversations > 0 && (
                  <span className="flex items-center gap-1 text-sm text-blue-600">
                    <MessageSquare size={14} />
                    {post._count.conversations} conv.
                  </span>
                )}
              </div>
              <h3 className="text-lg font-semibold text-gray-900">{post.title}</h3>
            </div>
            <button
              onClick={() => setExpandedPost(isExpanded ? null : post.id)}
              className="p-2 hover:bg-gray-200 rounded-full transition-colors"
            >
              {isExpanded ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
            </button>
          </div>

          {/* Quick info tags */}
          <div className="flex flex-wrap gap-2 mt-3">
            {post.city && (
              <span className="flex items-center gap-1 text-sm text-gray-600 bg-white px-2 py-1 rounded">
                <MapPin size={14} />
                {post.city}
              </span>
            )}
            {post.domain && (
              <span className="flex items-center gap-1 text-sm text-gray-600 bg-white px-2 py-1 rounded">
                <Briefcase size={14} />
                {post.domain}
              </span>
            )}
            {post.duration && (
              <span className="flex items-center gap-1 text-sm text-gray-600 bg-white px-2 py-1 rounded">
                <Calendar size={14} />
                {post.duration}
              </span>
            )}
            {post.salary && (
              <span className="flex items-center gap-1 text-sm text-gray-600 bg-white px-2 py-1 rounded">
                <DollarSign size={14} />
                {post.salary}
              </span>
            )}
          </div>
        </div>

        {/* Body - Always visible */}
        <div className="p-4">
          <p className="text-gray-700 whitespace-pre-wrap">{post.publicBio}</p>
        </div>

        {/* Expanded details */}
        {isExpanded && (
          <div className="border-t bg-gray-50 p-4 space-y-4">
            {/* Creator info */}
            <div className="bg-white rounded-lg p-4 border">
              <h4 className="font-medium text-gray-700 mb-3 flex items-center gap-2">
                <User size={16} />
                Publie par
              </h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="flex items-center gap-3">
                  {post.createdBy.photoUrl ? (
                    <img
                      src={post.createdBy.photoUrl}
                      alt=""
                      className="w-12 h-12 rounded-full object-cover"
                    />
                  ) : (
                    <div className="w-12 h-12 rounded-full bg-gray-200 flex items-center justify-center">
                      <User size={24} className="text-gray-400" />
                    </div>
                  )}
                  <div>
                    <p className="font-semibold">
                      {post.createdBy.firstName || ''} {post.createdBy.lastName || ''}
                      {!post.createdBy.firstName && !post.createdBy.lastName && 'Anonyme'}
                    </p>
                    <p className="text-xs text-gray-400 font-mono">{post.createdBy.id}</p>
                  </div>
                </div>
                <div className="space-y-1">
                  {post.createdBy.email && (
                    <p className="flex items-center gap-2 text-sm text-gray-600">
                      <Mail size={14} />
                      {post.createdBy.email}
                    </p>
                  )}
                  {post.createdBy.phone && (
                    <p className="flex items-center gap-2 text-sm text-gray-600">
                      <Phone size={14} />
                      {post.createdBy.phone}
                    </p>
                  )}
                  {post.createdBy.role && (
                    <p className="flex items-center gap-2 text-sm text-gray-600">
                      <Building size={14} />
                      {post.createdBy.role}
                    </p>
                  )}
                </div>
              </div>
            </div>

            {/* Private info (for REQUEST type) */}
            {post.type === 'REQUEST' && (post.fullName || post.email || post.phone || post.detailedBio) && (
              <div className="bg-white rounded-lg p-4 border">
                <h4 className="font-medium text-gray-700 mb-3 flex items-center gap-2">
                  <FileText size={16} />
                  Informations privees (candidat)
                </h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {post.fullName && (
                    <p className="flex items-center gap-2 text-sm">
                      <User size={14} className="text-gray-400" />
                      <span className="font-medium">Nom:</span> {post.fullName}
                    </p>
                  )}
                  {post.email && (
                    <p className="flex items-center gap-2 text-sm">
                      <Mail size={14} className="text-gray-400" />
                      <span className="font-medium">Email:</span> {post.email}
                    </p>
                  )}
                  {post.phone && (
                    <p className="flex items-center gap-2 text-sm">
                      <Phone size={14} className="text-gray-400" />
                      <span className="font-medium">Tel:</span> {post.phone}
                    </p>
                  )}
                </div>
                {post.detailedBio && (
                  <div className="mt-3 pt-3 border-t">
                    <p className="text-sm font-medium text-gray-600 mb-1">Bio detaillee:</p>
                    <p className="text-sm text-gray-700 whitespace-pre-wrap">{post.detailedBio}</p>
                  </div>
                )}
                {post.cvImageUrl && (
                  <div className="mt-3 pt-3 border-t">
                    <p className="text-sm font-medium text-gray-600 mb-2">CV (image):</p>
                    <img
                      src={post.cvImageUrl}
                      alt="CV"
                      className="max-w-full max-h-96 rounded-lg border"
                    />
                  </div>
                )}
              </div>
            )}

            {/* Offer info */}
            {post.type === 'OFFER' && post.requirements && (
              <div className="bg-white rounded-lg p-4 border">
                <h4 className="font-medium text-gray-700 mb-3 flex items-center gap-2">
                  <FileText size={16} />
                  Prerequis de l'offre
                </h4>
                <p className="text-sm text-gray-700 whitespace-pre-wrap">{post.requirements}</p>
              </div>
            )}

            {/* Moderation note */}
            {post.moderationNote && (
              <div className="bg-yellow-50 rounded-lg p-4 border border-yellow-200">
                <h4 className="font-medium text-yellow-700 mb-2">Note de moderation:</h4>
                <p className="text-sm text-yellow-800">{post.moderationNote}</p>
              </div>
            )}

            {/* Conversations button */}
            {post._count && post._count.conversations > 0 && (
              <Button
                variant="secondary"
                onClick={() => loadConversations(post)}
                className="w-full"
              >
                <MessageSquare size={16} className="mr-2" />
                Voir les {post._count.conversations} conversation(s)
              </Button>
            )}
          </div>
        )}

        {/* Actions */}
        <div className="border-t p-4 flex flex-wrap gap-2 bg-white">
          {activeTab === 'PENDING' && (
            <>
              <Button
                onClick={() => handleApprove(post.id)}
                isLoading={isLoading}
                className="flex-1"
              >
                <Check size={16} className="mr-1" />
                Approuver
              </Button>
              <Button
                variant="secondary"
                onClick={() => {
                  const note = prompt('Raison du refus (optionnel):');
                  handleReject(post.id, note || undefined);
                }}
                isLoading={isLoading}
                className="flex-1"
              >
                <X size={16} className="mr-1" />
                Refuser
              </Button>
            </>
          )}
          {activeTab === 'APPROVED' && (
            <Button
              variant="secondary"
              onClick={() => handleArchive(post.id)}
              isLoading={isLoading}
              className="flex-1"
            >
              <Archive size={16} className="mr-1" />
              Archiver
            </Button>
          )}
          {activeTab === 'REJECTED' && (
            <Button
              onClick={() => handleApprove(post.id)}
              isLoading={isLoading}
              className="flex-1"
            >
              <Check size={16} className="mr-1" />
              Reapprouver
            </Button>
          )}
          {activeTab === 'ARCHIVED' && (
            <Button
              onClick={() => handleApprove(post.id)}
              isLoading={isLoading}
              className="flex-1"
            >
              <Check size={16} className="mr-1" />
              Restaurer
            </Button>
          )}
          <Button
            variant="secondary"
            onClick={() => setExpandedPost(isExpanded ? null : post.id)}
          >
            <Eye size={16} className="mr-1" />
            {isExpanded ? 'Reduire' : 'Details'}
          </Button>
        </div>
      </Card>
    );
  };

  // Conversations modal
  const renderConversationsModal = () => {
    if (!selectedPost) return null;

    return (
      <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
        <div className="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
          {/* Modal Header */}
          <div className="p-4 border-b bg-gray-50 flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold">Conversations</h2>
              <p className="text-sm text-gray-500">{selectedPost.title}</p>
            </div>
            <button
              onClick={() => {
                setSelectedPost(null);
                setConversations([]);
                setExpandedConversation(null);
              }}
              className="p-2 hover:bg-gray-200 rounded-full"
            >
              <X size={20} />
            </button>
          </div>

          {/* Modal Content */}
          <div className="flex-1 overflow-y-auto p-4">
            {loadingConversations ? (
              <div className="flex items-center justify-center py-12">
                <div className="w-8 h-8 border-2 border-primary-600 border-t-transparent rounded-full animate-spin" />
              </div>
            ) : conversations.length === 0 ? (
              <div className="text-center py-12 text-gray-500">
                <MessageSquare size={48} className="mx-auto mb-4 text-gray-300" />
                <p>Aucune conversation</p>
              </div>
            ) : (
              <div className="space-y-4">
                {conversations.map((conv) => (
                  <div key={conv.id} className="border rounded-lg overflow-hidden">
                    {/* Conversation header */}
                    <button
                      onClick={() => setExpandedConversation(
                        expandedConversation === conv.id ? null : conv.id
                      )}
                      className="w-full p-4 bg-gray-50 hover:bg-gray-100 flex items-center justify-between text-left"
                    >
                      <div className="flex items-center gap-3">
                        {conv.participant.photoUrl ? (
                          <img
                            src={conv.participant.photoUrl}
                            alt=""
                            className="w-10 h-10 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center">
                            <User size={20} className="text-gray-400" />
                          </div>
                        )}
                        <div>
                          <p className="font-medium">
                            {conv.participant.firstName || ''} {conv.participant.lastName || ''}
                            {conv.participantAnonymousName && (
                              <span className="text-gray-400 text-sm ml-2">
                                ({conv.participantAnonymousName})
                              </span>
                            )}
                          </p>
                          <div className="flex items-center gap-2 text-xs text-gray-500">
                            {conv.participant.email && <span>{conv.participant.email}</span>}
                            {conv.participant.role && (
                              <span className={`px-1.5 py-0.5 rounded ${
                                conv.participant.role === 'PRO' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100'
                              }`}>
                                {conv.participant.role}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-sm text-gray-500">
                          {conv._count.messages} messages
                        </span>
                        {expandedConversation === conv.id ? (
                          <ChevronUp size={20} />
                        ) : (
                          <ChevronDown size={20} />
                        )}
                      </div>
                    </button>

                    {/* Messages */}
                    {expandedConversation === conv.id && (
                      <div className="p-4 border-t bg-white max-h-96 overflow-y-auto">
                        {conv.messages.length === 0 ? (
                          <p className="text-center text-gray-400 py-4">Aucun message</p>
                        ) : (
                          <div className="space-y-3">
                            {conv.messages.map((msg) => {
                              const isPostOwner = msg.sender.id === selectedPost?.createdBy.id;
                              return (
                                <div
                                  key={msg.id}
                                  className={`flex ${isPostOwner ? 'justify-end' : 'justify-start'}`}
                                >
                                  <div className={`max-w-[80%] ${
                                    isPostOwner
                                      ? 'bg-primary-100 text-primary-900'
                                      : 'bg-gray-100 text-gray-900'
                                  } rounded-lg px-4 py-2`}>
                                    <div className="flex items-center gap-2 mb-1">
                                      <span className="text-xs font-medium">
                                        {msg.sender.firstName || 'Anonyme'}
                                      </span>
                                      <span className="text-xs text-gray-500">
                                        {formatDate(msg.createdAt)}
                                      </span>
                                    </div>
                                    <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Annonces Carriere</h1>
            <p className="text-gray-600 mt-1">Gerez les annonces d'emploi et de stage</p>
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

        {/* Type filter */}
        <div className="flex gap-2">
          {typeFilters.map((filter) => (
            <button
              key={filter.value || 'all'}
              onClick={() => setTypeFilter(filter.value)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                typeFilter === filter.value
                  ? 'bg-gray-800 text-white'
                  : 'bg-white text-gray-600 hover:bg-gray-100 border'
              }`}
            >
              {filter.label}
            </button>
          ))}
        </div>

        {/* Content */}
        {loading ? (
          <div className="flex items-center justify-center h-64">
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
            <Button onClick={fetchPosts} size="sm">
              Reessayer
            </Button>
          </Card>
        ) : posts.length === 0 ? (
          <Card className="text-center py-16">
            <Briefcase size={64} className="text-gray-200 mx-auto mb-4" />
            <p className="text-gray-500 text-lg">
              Aucune annonce {
                activeTab === 'PENDING' ? 'en attente' :
                activeTab === 'APPROVED' ? 'approuvee' :
                activeTab === 'REJECTED' ? 'rejetee' : 'archivee'
              }
              {typeFilter && ` (${typeFilter === 'REQUEST' ? 'demandes' : 'offres'})`}
            </p>
          </Card>
        ) : (
          <div className="space-y-4">
            {posts.map(renderPostCard)}
          </div>
        )}

        {/* Conversations Modal */}
        {renderConversationsModal()}
      </div>
    </DashboardLayout>
  );
}
