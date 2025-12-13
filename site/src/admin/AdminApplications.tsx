import { useEffect, useState } from 'react';
import { Check, X, Eye, MapPin, Clock, CheckCircle, XCircle } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile } from '../types';

// Use lowercase status like Flutter app does
type TabStatus = 'pending' | 'approved' | 'rejected';

export function AdminApplications() {
  const [activeTab, setActiveTab] = useState<TabStatus>('pending');
  const [providers, setProviders] = useState<ProviderProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedProvider, setSelectedProvider] = useState<ProviderProfile | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  useEffect(() => {
    fetchProviders(activeTab);
  }, [activeTab]);

  async function fetchProviders(status: TabStatus) {
    setLoading(true);
    try {
      const data = await api.listProviderApplications(status, 100);
      // Ensure data is always an array
      setProviders(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching providers:', error);
      setProviders([]);
    } finally {
      setLoading(false);
    }
  }

  async function handleApprove(providerId: string) {
    setActionLoading(providerId);
    try {
      await api.approveProvider(providerId);
      setProviders((prev) => prev.filter((p) => p.id !== providerId));
      setSelectedProvider(null);
    } catch (error) {
      console.error('Error approving provider:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleReject(providerId: string) {
    setActionLoading(providerId);
    try {
      await api.rejectProvider(providerId);
      setProviders((prev) => prev.filter((p) => p.id !== providerId));
      setSelectedProvider(null);
    } catch (error) {
      console.error('Error rejecting provider:', error);
    } finally {
      setActionLoading(null);
    }
  }

  const tabs: { status: TabStatus; label: string; icon: React.ReactNode }[] = [
    { status: 'pending', label: 'En attente', icon: <Clock size={16} /> },
    { status: 'approved', label: 'Approuvées', icon: <CheckCircle size={16} /> },
    { status: 'rejected', label: 'Rejetées', icon: <XCircle size={16} /> },
  ];

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Demandes Pro</h1>
          <p className="text-gray-600 mt-1">Gérez les demandes d'inscription des professionnels</p>
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
                  {providers.length}
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
            ) : providers.length === 0 ? (
              <Card className="text-center py-12">
                <p className="text-gray-500">Aucune demande {activeTab === 'pending' ? 'en attente' : activeTab === 'approved' ? 'approuvée' : 'rejetée'}</p>
              </Card>
            ) : (
              <div className="space-y-4">
                {providers.map((provider) => (
                  <Card
                    key={provider.id}
                    className={`cursor-pointer transition-all ${
                      selectedProvider?.id === provider.id
                        ? 'ring-2 ring-primary-500'
                        : 'hover:shadow-md'
                    }`}
                    onClick={() => setSelectedProvider(provider)}
                  >
                    <div className="flex items-start justify-between">
                      <div className="flex items-start space-x-4">
                        {provider.avatarUrl ? (
                          <img
                            src={provider.avatarUrl}
                            alt={provider.displayName}
                            className="w-14 h-14 rounded-lg object-cover"
                          />
                        ) : (
                          <div className="w-14 h-14 bg-primary-100 rounded-lg flex items-center justify-center">
                            <span className="text-primary-700 font-bold text-xl">
                              {provider.displayName?.charAt(0) || '?'}
                            </span>
                          </div>
                        )}
                        <div>
                          <h3 className="font-semibold text-gray-900">{provider.displayName}</h3>
                          {provider.address && (
                            <p className="text-sm text-gray-500 flex items-center mt-1">
                              <MapPin size={14} className="mr-1" />
                              {provider.address}
                            </p>
                          )}
                          {Array.isArray(provider.specialties) && provider.specialties.length > 0 && (
                            <div className="flex flex-wrap gap-1 mt-2">
                              {provider.specialties.slice(0, 3).map((specialty: string) => (
                                <span
                                  key={specialty}
                                  className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded"
                                >
                                  {specialty}
                                </span>
                              ))}
                            </div>
                          )}
                        </div>
                      </div>

                      {activeTab === 'pending' && (
                        <div className="flex space-x-2">
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleApprove(provider.id);
                            }}
                            isLoading={actionLoading === provider.id}
                          >
                            <Check size={16} className="text-green-600" />
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleReject(provider.id);
                            }}
                            isLoading={actionLoading === provider.id}
                          >
                            <X size={16} className="text-red-600" />
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
            {selectedProvider ? (
              <Card className="sticky top-6">
                <h3 className="font-semibold text-gray-900 mb-4">Détails du profil</h3>

                {/* Avatar */}
                <div className="flex justify-center mb-4">
                  {selectedProvider.avatarUrl ? (
                    <img
                      src={selectedProvider.avatarUrl}
                      alt={selectedProvider.displayName}
                      className="w-24 h-24 rounded-xl object-cover"
                    />
                  ) : (
                    <div className="w-24 h-24 bg-primary-100 rounded-xl flex items-center justify-center">
                      <span className="text-primary-700 font-bold text-3xl">
                        {selectedProvider.displayName?.charAt(0) || '?'}
                      </span>
                    </div>
                  )}
                </div>

                <div className="space-y-3 text-sm">
                  <div>
                    <p className="text-gray-500">Nom</p>
                    <p className="font-medium">{selectedProvider.displayName}</p>
                  </div>

                  {selectedProvider.bio && (
                    <div>
                      <p className="text-gray-500">Bio</p>
                      <p className="text-gray-700">{selectedProvider.bio}</p>
                    </div>
                  )}

                  {selectedProvider.address && (
                    <div>
                      <p className="text-gray-500">Adresse</p>
                      <p className="font-medium">{selectedProvider.address}</p>
                    </div>
                  )}

                  {Array.isArray(selectedProvider.specialties) && selectedProvider.specialties.length > 0 && (
                    <div>
                      <p className="text-gray-500">Spécialités</p>
                      <div className="flex flex-wrap gap-1 mt-1">
                        {selectedProvider.specialties.map((specialty: string) => (
                          <span
                            key={specialty}
                            className="text-xs bg-primary-100 text-primary-700 px-2 py-1 rounded"
                          >
                            {specialty}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* AVN Cards */}
                  {(selectedProvider.avnCardFront || selectedProvider.avnCardBack) && (
                    <div>
                      <p className="text-gray-500 mb-2">Carte AVN</p>
                      <div className="grid grid-cols-2 gap-2">
                        {selectedProvider.avnCardFront && (
                          <a
                            href={selectedProvider.avnCardFront}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="block"
                          >
                            <img
                              src={selectedProvider.avnCardFront}
                              alt="AVN Front"
                              className="w-full h-20 object-cover rounded border hover:border-primary-500"
                            />
                            <p className="text-xs text-center text-gray-500 mt-1">Recto</p>
                          </a>
                        )}
                        {selectedProvider.avnCardBack && (
                          <a
                            href={selectedProvider.avnCardBack}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="block"
                          >
                            <img
                              src={selectedProvider.avnCardBack}
                              alt="AVN Back"
                              className="w-full h-20 object-cover rounded border hover:border-primary-500"
                            />
                            <p className="text-xs text-center text-gray-500 mt-1">Verso</p>
                          </a>
                        )}
                      </div>
                    </div>
                  )}
                </div>

                {activeTab === 'pending' && (
                  <div className="flex space-x-3 mt-6">
                    <Button
                      className="flex-1"
                      onClick={() => handleApprove(selectedProvider.id)}
                      isLoading={actionLoading === selectedProvider.id}
                    >
                      <Check size={16} className="mr-2" />
                      Approuver
                    </Button>
                    <Button
                      variant="danger"
                      className="flex-1"
                      onClick={() => handleReject(selectedProvider.id)}
                      isLoading={actionLoading === selectedProvider.id}
                    >
                      <X size={16} className="mr-2" />
                      Rejeter
                    </Button>
                  </div>
                )}
              </Card>
            ) : (
              <Card className="text-center py-12">
                <Eye size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez une demande pour voir les détails</p>
              </Card>
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
