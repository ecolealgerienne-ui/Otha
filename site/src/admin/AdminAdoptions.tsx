import { useEffect, useState } from 'react';
import { Check, X, Eye, Heart, Clock, CheckCircle, XCircle, Archive, CheckCheck } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { AdoptPost, AdoptPostStatus } from '../types';

type TabStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'ARCHIVED';

export function AdminAdoptions() {
  const [activeTab, setActiveTab] = useState<TabStatus>('PENDING');
  const [posts, setPosts] = useState<AdoptPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedPost, setSelectedPost] = useState<AdoptPost | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  useEffect(() => {
    fetchPosts(activeTab);
  }, [activeTab]);

  async function fetchPosts(status: AdoptPostStatus) {
    setLoading(true);
    try {
      const data = await api.adminAdoptList(status, 50);
      // Handle different response formats and ensure array
      const posts = data?.data || data;
      setPosts(Array.isArray(posts) ? posts : []);
    } catch (error) {
      console.error('Error fetching posts:', error);
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
      setSelectedPost(null);
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
      setSelectedPost(null);
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
      setSelectedPost(null);
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
      alert(`${result.count} posts approuvés`);
      fetchPosts('PENDING');
    } catch (error) {
      console.error('Error approving all:', error);
    } finally {
      setActionLoading(null);
    }
  }

  const tabs: { status: TabStatus; label: string; icon: React.ReactNode }[] = [
    { status: 'PENDING', label: 'En attente', icon: <Clock size={16} /> },
    { status: 'APPROVED', label: 'Approuvées', icon: <CheckCircle size={16} /> },
    { status: 'REJECTED', label: 'Rejetées', icon: <XCircle size={16} /> },
    { status: 'ARCHIVED', label: 'Archivées', icon: <Archive size={16} /> },
  ];

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Adoptions</h1>
            <p className="text-gray-600 mt-1">Modérez les annonces d'adoption</p>
          </div>
          {activeTab === 'PENDING' && posts.length > 0 && (
            <Button
              onClick={handleApproveAll}
              isLoading={actionLoading === 'all'}
            >
              <CheckCheck size={16} className="mr-2" />
              Tout approuver
            </Button>
          )}
        </div>

        {/* Tabs */}
        <div className="flex space-x-2 border-b border-gray-200">
          {tabs.map((tab) => (
            <button
              key={tab.status}
              onClick={() => setActiveTab(tab.status)}
              className={`flex items-center space-x-2 px-4 py-3 border-b-2 transition-colors ${
                activeTab === tab.status
                  ? 'border-primary-600 text-primary-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab.icon}
              <span>{tab.label}</span>
              {activeTab === tab.status && (
                <span className="bg-primary-100 text-primary-700 text-xs px-2 py-0.5 rounded-full">
                  {posts.length}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* List */}
          <div className="lg:col-span-2">
            {loading ? (
              <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
              </div>
            ) : posts.length === 0 ? (
              <Card className="text-center py-12">
                <Heart size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Aucune annonce {
                  activeTab === 'PENDING' ? 'en attente' :
                  activeTab === 'APPROVED' ? 'approuvée' :
                  activeTab === 'REJECTED' ? 'rejetée' : 'archivée'
                }</p>
              </Card>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {posts.map((post) => (
                  <Card
                    key={post.id}
                    padding="none"
                    className={`cursor-pointer overflow-hidden transition-all ${
                      selectedPost?.id === post.id
                        ? 'ring-2 ring-primary-500'
                        : 'hover:shadow-md'
                    }`}
                    onClick={() => setSelectedPost(post)}
                  >
                    {/* Image */}
                    <div className="h-40 bg-gray-100">
                      {post.images && post.images[0] ? (
                        <img
                          src={post.images[0].url}
                          alt={post.name}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <Heart size={48} className="text-gray-300" />
                        </div>
                      )}
                    </div>

                    {/* Content */}
                    <div className="p-4">
                      <div className="flex items-center justify-between mb-2">
                        <h3 className="font-semibold text-gray-900">{post.name}</h3>
                        <span className="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded">
                          {post.species}
                        </span>
                      </div>
                      {post.location && (
                        <p className="text-sm text-gray-500">{post.location}</p>
                      )}

                      {activeTab === 'PENDING' && (
                        <div className="flex space-x-2 mt-3">
                          <Button
                            size="sm"
                            className="flex-1"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleApprove(post.id);
                            }}
                            isLoading={actionLoading === post.id}
                          >
                            <Check size={14} className="mr-1" />
                            Approuver
                          </Button>
                          <Button
                            size="sm"
                            variant="danger"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleReject(post.id);
                            }}
                            isLoading={actionLoading === post.id}
                          >
                            <X size={14} />
                          </Button>
                        </div>
                      )}
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </div>

          {/* Detail panel */}
          <div className="lg:col-span-1">
            {selectedPost ? (
              <Card className="sticky top-6">
                <h3 className="font-semibold text-gray-900 mb-4">Détails de l'annonce</h3>

                {/* Images gallery */}
                {selectedPost.images && selectedPost.images.length > 0 && (
                  <div className="mb-4">
                    <img
                      src={selectedPost.images[0].url}
                      alt={selectedPost.name}
                      className="w-full h-48 object-cover rounded-lg"
                    />
                    {selectedPost.images.length > 1 && (
                      <div className="flex space-x-2 mt-2">
                        {selectedPost.images.slice(1, 4).map((img) => (
                          <img
                            key={img.id}
                            src={img.url}
                            alt=""
                            className="w-16 h-16 object-cover rounded"
                          />
                        ))}
                      </div>
                    )}
                  </div>
                )}

                <div className="space-y-3 text-sm">
                  <div>
                    <p className="text-gray-500">Nom</p>
                    <p className="font-medium">{selectedPost.name}</p>
                  </div>

                  <div>
                    <p className="text-gray-500">Espèce</p>
                    <p className="font-medium">{selectedPost.species}</p>
                  </div>

                  {selectedPost.sex && (
                    <div>
                      <p className="text-gray-500">Sexe</p>
                      <p className="font-medium">{selectedPost.sex}</p>
                    </div>
                  )}

                  {selectedPost.age && (
                    <div>
                      <p className="text-gray-500">Âge</p>
                      <p className="font-medium">{selectedPost.age}</p>
                    </div>
                  )}

                  {selectedPost.location && (
                    <div>
                      <p className="text-gray-500">Localisation</p>
                      <p className="font-medium">{selectedPost.location}</p>
                    </div>
                  )}

                  {selectedPost.description && (
                    <div>
                      <p className="text-gray-500">Description</p>
                      <p className="text-gray-700">{selectedPost.description}</p>
                    </div>
                  )}
                </div>

                {activeTab === 'PENDING' && (
                  <div className="flex space-x-3 mt-6">
                    <Button
                      className="flex-1"
                      onClick={() => handleApprove(selectedPost.id)}
                      isLoading={actionLoading === selectedPost.id}
                    >
                      <Check size={16} className="mr-2" />
                      Approuver
                    </Button>
                    <Button
                      variant="danger"
                      className="flex-1"
                      onClick={() => handleReject(selectedPost.id)}
                      isLoading={actionLoading === selectedPost.id}
                    >
                      <X size={16} className="mr-2" />
                      Rejeter
                    </Button>
                  </div>
                )}

                {activeTab === 'APPROVED' && (
                  <Button
                    variant="secondary"
                    className="w-full mt-6"
                    onClick={() => handleArchive(selectedPost.id)}
                    isLoading={actionLoading === selectedPost.id}
                  >
                    <Archive size={16} className="mr-2" />
                    Archiver
                  </Button>
                )}
              </Card>
            ) : (
              <Card className="text-center py-12">
                <Eye size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez une annonce pour voir les détails</p>
              </Card>
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
