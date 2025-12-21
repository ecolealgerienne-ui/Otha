import { useEffect, useState } from 'react';
import { DollarSign, TrendingUp, Calendar, Search, Plus, Minus, X } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile, MonthlyEarnings } from '../types';
import { format, subMonths } from 'date-fns';
import { fr } from 'date-fns/locale';

interface CollectionModalData {
  month: string;
  monthLabel: string;
  totalCommission: number;
  collected: number;
  remaining: number;
}

export function AdminEarnings() {
  const [providers, setProviders] = useState<ProviderProfile[]>([]);
  const [selectedProvider, setSelectedProvider] = useState<ProviderProfile | null>(null);
  const [earnings, setEarnings] = useState<MonthlyEarnings[]>([]);
  const [loading, setLoading] = useState(true);
  const [earningsLoading, setEarningsLoading] = useState(false);
  const [stats, setStats] = useState<{
    totalBookings: number;
    totalAmount: number;
    totalCommission: number;
  } | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  // Modal state
  const [showCollectionModal, setShowCollectionModal] = useState(false);
  const [modalData, setModalData] = useState<CollectionModalData | null>(null);
  const [collectionAmount, setCollectionAmount] = useState('');
  const [collectionNote, setCollectionNote] = useState('');
  const [collectionMode, setCollectionMode] = useState<'set' | 'add' | 'subtract'>('set');
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    fetchProviders();
    fetchStats();
  }, []);

  async function fetchProviders() {
    setLoading(true);
    try {
      // Use lowercase status like Flutter app
      const data = await api.listProviderApplications('approved', 100);
      // Ensure data is always an array
      setProviders(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching providers:', error);
      setProviders([]);
    } finally {
      setLoading(false);
    }
  }

  async function fetchStats() {
    try {
      const from = format(subMonths(new Date(), 1), 'yyyy-MM-dd');
      const to = format(new Date(), 'yyyy-MM-dd');
      const data = await api.adminTraceabilityStats(from, to);
      setStats(data);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  }

  async function fetchProviderEarnings(providerId: string) {
    setEarningsLoading(true);
    try {
      const data = await api.adminHistoryMonthly(providerId, 12);
      // Ensure data is always an array
      setEarnings(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching earnings:', error);
      setEarnings([]);
    } finally {
      setEarningsLoading(false);
    }
  }

  const handleSelectProvider = (provider: ProviderProfile) => {
    setSelectedProvider(provider);
    fetchProviderEarnings(provider.id);
  };

  function openCollectionModal(earning: MonthlyEarnings) {
    const monthLabel = format(new Date(earning.month + '-01'), 'MMMM yyyy', { locale: fr });
    setModalData({
      month: earning.month,
      monthLabel,
      totalCommission: earning.totalCommission,
      collected: earning.collected ? earning.totalCommission : 0,
      remaining: earning.collected ? 0 : earning.totalCommission,
    });
    setCollectionAmount(earning.collected ? '' : earning.totalCommission.toString());
    setCollectionNote('');
    setCollectionMode('set');
    setShowCollectionModal(true);
  }

  async function handleCollectionSubmit() {
    if (!selectedProvider || !modalData) return;

    const amount = parseInt(collectionAmount, 10);
    if (isNaN(amount) || amount < 0) {
      alert('Veuillez entrer un montant valide');
      return;
    }

    setActionLoading(true);
    try {
      if (collectionMode === 'set') {
        await api.adminCollectMonth(selectedProvider.id, modalData.month, collectionNote || undefined, amount);
      } else if (collectionMode === 'add') {
        await api.adminAddCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
      } else if (collectionMode === 'subtract') {
        await api.adminSubtractCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
      }
      fetchProviderEarnings(selectedProvider.id);
      setShowCollectionModal(false);
    } catch (error) {
      console.error('Error with collection:', error);
      alert('Erreur lors de la collecte');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleCollectAll(month: string) {
    if (!selectedProvider) return;
    try {
      await api.adminCollectMonth(selectedProvider.id, month);
      fetchProviderEarnings(selectedProvider.id);
    } catch (error) {
      console.error('Error collecting:', error);
    }
  }

  async function handleUncollect(month: string) {
    if (!selectedProvider) return;
    try {
      await api.adminUncollectMonth(selectedProvider.id, month);
      fetchProviderEarnings(selectedProvider.id);
    } catch (error) {
      console.error('Error uncollecting:', error);
    }
  }

  const filteredProviders = providers.filter((p) =>
    p.displayName?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-DZ', {
      style: 'currency',
      currency: 'DZD',
    }).format(amount);
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Gains & Commissions</h1>
          <p className="text-gray-600 mt-1">Gérez les revenus des professionnels</p>
        </div>

        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card className="flex items-center space-x-4">
              <div className="p-3 rounded-lg bg-green-100">
                <DollarSign className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Revenus ce mois</p>
                <p className="text-xl font-bold text-gray-900">{formatCurrency(stats.totalAmount)}</p>
              </div>
            </Card>
            <Card className="flex items-center space-x-4">
              <div className="p-3 rounded-lg bg-blue-100">
                <TrendingUp className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Commissions</p>
                <p className="text-xl font-bold text-gray-900">{formatCurrency(stats.totalCommission)}</p>
              </div>
            </Card>
            <Card className="flex items-center space-x-4">
              <div className="p-3 rounded-lg bg-purple-100">
                <Calendar className="w-6 h-6 text-purple-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Réservations</p>
                <p className="text-xl font-bold text-gray-900">{stats.totalBookings}</p>
              </div>
            </Card>
          </div>
        )}

        {/* Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Providers list */}
          <div className="lg:col-span-1">
            <Card>
              <h3 className="font-semibold text-gray-900 mb-4">Professionnels</h3>

              <div className="relative mb-4">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                <Input
                  placeholder="Rechercher..."
                  className="pl-10"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>

              {loading ? (
                <div className="flex items-center justify-center h-32">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" />
                </div>
              ) : filteredProviders.length === 0 ? (
                <p className="text-gray-500 text-sm text-center py-4">Aucun professionnel trouvé</p>
              ) : (
                <div className="space-y-2 max-h-[500px] overflow-y-auto">
                  {filteredProviders.map((provider) => (
                    <button
                      key={provider.id}
                      className={`w-full text-left p-3 rounded-lg transition-colors ${
                        selectedProvider?.id === provider.id
                          ? 'bg-primary-50 border border-primary-200'
                          : 'bg-gray-50 hover:bg-gray-100'
                      }`}
                      onClick={() => handleSelectProvider(provider)}
                    >
                      <div className="flex items-center space-x-3">
                        {provider.avatarUrl ? (
                          <img
                            src={provider.avatarUrl}
                            alt={provider.displayName}
                            className="w-10 h-10 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
                            <span className="text-primary-700 font-medium">
                              {provider.displayName?.charAt(0) || '?'}
                            </span>
                          </div>
                        )}
                        <div>
                          <p className="font-medium text-gray-900">{provider.displayName}</p>
                          <p className="text-xs text-gray-500">{provider.address || 'Non renseigné'}</p>
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </Card>
          </div>

          {/* Earnings detail */}
          <div className="lg:col-span-2">
            {selectedProvider ? (
              <Card>
                <div className="flex items-center justify-between mb-6">
                  <div>
                    <h3 className="font-semibold text-gray-900">Historique des gains</h3>
                    <p className="text-sm text-gray-500">{selectedProvider.displayName}</p>
                  </div>
                </div>

                {earningsLoading ? (
                  <div className="flex items-center justify-center h-64">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
                  </div>
                ) : earnings.length === 0 ? (
                  <div className="text-center py-12">
                    <DollarSign size={48} className="text-gray-300 mx-auto mb-4" />
                    <p className="text-gray-500">Aucun historique de gains</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-200">
                          <th className="text-left py-3 px-4 text-sm font-medium text-gray-500">Mois</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">Réservations</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">Montant</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">Commission</th>
                          <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">Net</th>
                          <th className="text-center py-3 px-4 text-sm font-medium text-gray-500">Statut</th>
                          <th className="text-center py-3 px-4 text-sm font-medium text-gray-500">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        {earnings.map((earning) => (
                          <tr key={earning.month} className="border-b border-gray-100">
                            <td className="py-3 px-4">
                              <span className="font-medium text-gray-900">
                                {format(new Date(earning.month + '-01'), 'MMMM yyyy', { locale: fr })}
                              </span>
                            </td>
                            <td className="text-right py-3 px-4 text-gray-600">
                              {earning.bookingCount}
                            </td>
                            <td className="text-right py-3 px-4 text-gray-600">
                              {formatCurrency(earning.totalAmount)}
                            </td>
                            <td className="text-right py-3 px-4 text-gray-600">
                              {formatCurrency(earning.totalCommission)}
                            </td>
                            <td className="text-right py-3 px-4 font-medium text-gray-900">
                              {formatCurrency(earning.netAmount)}
                            </td>
                            <td className="text-center py-3 px-4">
                              {earning.collected ? (
                                <span className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded">
                                  Collecté
                                </span>
                              ) : (
                                <span className="text-xs bg-yellow-100 text-yellow-700 px-2 py-1 rounded">
                                  En attente
                                </span>
                              )}
                            </td>
                            <td className="text-center py-3 px-4">
                              <div className="flex items-center justify-center gap-1">
                                {earning.collected ? (
                                  <>
                                    <Button
                                      size="sm"
                                      variant="ghost"
                                      onClick={() => openCollectionModal(earning)}
                                      title="Modifier la collecte"
                                    >
                                      Modifier
                                    </Button>
                                    <Button
                                      size="sm"
                                      variant="ghost"
                                      className="text-red-600 hover:text-red-700"
                                      onClick={() => handleUncollect(earning.month)}
                                      title="Annuler la collecte"
                                    >
                                      Annuler
                                    </Button>
                                  </>
                                ) : (
                                  <>
                                    <Button
                                      size="sm"
                                      onClick={() => handleCollectAll(earning.month)}
                                      title="Collecter tout"
                                    >
                                      Tout
                                    </Button>
                                    <Button
                                      size="sm"
                                      variant="secondary"
                                      onClick={() => openCollectionModal(earning)}
                                      title="Collecter un montant spécifique"
                                    >
                                      Partiel
                                    </Button>
                                  </>
                                )}
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </Card>
            ) : (
              <Card className="text-center py-12">
                <DollarSign size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez un professionnel pour voir ses gains</p>
              </Card>
            )}
          </div>
        </div>
      </div>

      {/* Modal de collecte */}
      {showCollectionModal && modalData && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl shadow-2xl max-w-md w-full mx-4 p-6">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-gray-900">
                Collecte - {modalData.monthLabel}
              </h3>
              <button
                onClick={() => setShowCollectionModal(false)}
                className="p-1 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <X size={20} className="text-gray-500" />
              </button>
            </div>

            {/* Résumé */}
            <div className="bg-gray-50 rounded-lg p-4 mb-6">
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <span className="text-gray-500">Commission totale:</span>
                  <p className="font-semibold text-gray-900">{formatCurrency(modalData.totalCommission)}</p>
                </div>
                <div>
                  <span className="text-gray-500">Déjà collecté:</span>
                  <p className="font-semibold text-green-600">{formatCurrency(modalData.collected)}</p>
                </div>
              </div>
            </div>

            {/* Mode de collecte */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">Type d'opération</label>
              <div className="flex gap-2">
                <button
                  onClick={() => setCollectionMode('set')}
                  className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-colors ${
                    collectionMode === 'set'
                      ? 'bg-primary-100 text-primary-700 border-2 border-primary-500'
                      : 'bg-gray-100 text-gray-600 border-2 border-transparent hover:bg-gray-200'
                  }`}
                >
                  Définir
                </button>
                <button
                  onClick={() => setCollectionMode('add')}
                  className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-colors flex items-center justify-center gap-1 ${
                    collectionMode === 'add'
                      ? 'bg-green-100 text-green-700 border-2 border-green-500'
                      : 'bg-gray-100 text-gray-600 border-2 border-transparent hover:bg-gray-200'
                  }`}
                >
                  <Plus size={16} /> Ajouter
                </button>
                <button
                  onClick={() => setCollectionMode('subtract')}
                  className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-colors flex items-center justify-center gap-1 ${
                    collectionMode === 'subtract'
                      ? 'bg-red-100 text-red-700 border-2 border-red-500'
                      : 'bg-gray-100 text-gray-600 border-2 border-transparent hover:bg-gray-200'
                  }`}
                >
                  <Minus size={16} /> Retirer
                </button>
              </div>
            </div>

            {/* Montant */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                {collectionMode === 'set' ? 'Montant total collecté' :
                 collectionMode === 'add' ? 'Montant à ajouter' : 'Montant à retirer'} (DA)
              </label>
              <Input
                type="number"
                value={collectionAmount}
                onChange={(e) => setCollectionAmount(e.target.value)}
                placeholder="0"
                min="0"
                max={modalData.totalCommission}
              />
              {collectionMode === 'set' && (
                <div className="flex gap-2 mt-2">
                  <button
                    onClick={() => setCollectionAmount(modalData.totalCommission.toString())}
                    className="text-xs text-primary-600 hover:underline"
                  >
                    Tout ({formatCurrency(modalData.totalCommission)})
                  </button>
                  <button
                    onClick={() => setCollectionAmount(Math.floor(modalData.totalCommission / 2).toString())}
                    className="text-xs text-primary-600 hover:underline"
                  >
                    50% ({formatCurrency(Math.floor(modalData.totalCommission / 2))})
                  </button>
                </div>
              )}
            </div>

            {/* Note */}
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 mb-2">Note (optionnel)</label>
              <Input
                type="text"
                value={collectionNote}
                onChange={(e) => setCollectionNote(e.target.value)}
                placeholder="Ex: Paiement espèces..."
              />
            </div>

            {/* Actions */}
            <div className="flex gap-3">
              <Button
                variant="secondary"
                className="flex-1"
                onClick={() => setShowCollectionModal(false)}
              >
                Annuler
              </Button>
              <Button
                className="flex-1"
                onClick={handleCollectionSubmit}
                disabled={actionLoading || !collectionAmount}
              >
                {actionLoading ? 'En cours...' : 'Confirmer'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </DashboardLayout>
  );
}
