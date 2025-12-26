import { useEffect, useState } from 'react';
import { DollarSign, TrendingUp, Calendar, Search, Plus, Minus, X, AlertTriangle, Stethoscope, Home, ShoppingBag } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile, MonthlyEarnings } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

type ProviderKind = 'vet' | 'petshop' | 'daycare';

const kindConfig: Record<ProviderKind, { label: string; icon: typeof Stethoscope; color: string; bgColor: string }> = {
  vet: { label: 'Vétérinaires', icon: Stethoscope, color: 'text-blue-600', bgColor: 'bg-blue-100' },
  petshop: { label: 'Petshops', icon: ShoppingBag, color: 'text-purple-600', bgColor: 'bg-purple-100' },
  daycare: { label: 'Garderies', icon: Home, color: 'text-green-600', bgColor: 'bg-green-100' },
};

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
  const [selectedKind, setSelectedKind] = useState<ProviderKind>('vet');
  const [globalStats, setGlobalStats] = useState<{
    totalProviders: number;
    totalBookings: number;
    totalOrders?: number;
    totalRevenue?: number;
    totalCommissionGenerated: number;
    totalCollected: number;
    totalRemaining: number;
  } | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  // Modal state
  const [showCollectionModal, setShowCollectionModal] = useState(false);
  const [modalData, setModalData] = useState<CollectionModalData | null>(null);
  const [collectionAmount, setCollectionAmount] = useState('');
  const [collectionNote, setCollectionNote] = useState('');
  const [collectionMode, setCollectionMode] = useState<'set' | 'add' | 'subtract'>('set');
  const [actionLoading, setActionLoading] = useState(false);

  // Track unpaid months per provider
  const [unpaidMonthsMap, setUnpaidMonthsMap] = useState<Record<string, number>>({});

  useEffect(() => {
    fetchProviders();
    fetchGlobalStats();
  }, [selectedKind]);

  async function fetchProviders() {
    setLoading(true);
    setSelectedProvider(null);
    setEarnings([]);
    try {
      // Use lowercase status like Flutter app
      const data = await api.listProviderApplications('approved', 100);
      // Ensure data is always an array
      const allProviders = Array.isArray(data) ? data : [];

      // Filter by selected kind
      const filteredProviders = allProviders.filter((p: ProviderProfile) => {
        const spec = p.specialties as any;
        const kind = (spec?.kind ?? 'vet').toString().toLowerCase();
        return kind === selectedKind;
      });

      setProviders(filteredProviders);

      // Précharger les mois impayés pour les providers filtrés
      fetchAllUnpaidMonths(filteredProviders);
    } catch (error) {
      console.error('Error fetching providers:', error);
      setProviders([]);
    } finally {
      setLoading(false);
    }
  }

  async function fetchAllUnpaidMonths(providersList: ProviderProfile[]) {
    // Charger les earnings de tous les providers en parallèle
    const unpaidMap: Record<string, number> = {};

    await Promise.all(
      providersList.map(async (provider) => {
        try {
          let data: any[];
          if (selectedKind === 'petshop') {
            data = await api.adminPetshopHistoryMonthly(provider.id, 12);
          } else if (selectedKind === 'daycare') {
            data = await api.adminDaycareHistoryMonthly(provider.id, 12);
          } else {
            data = await api.adminHistoryMonthly(provider.id, 12);
          }
          const earningsData = Array.isArray(data) ? data : [];

          const unpaidCount = earningsData.filter((e: MonthlyEarnings & { collectedAmount?: number }) => {
            const collectedAmount = e.collectedAmount ?? (e.collected ? e.totalCommission : 0);
            return e.totalCommission > 0 && collectedAmount < e.totalCommission;
          }).length;

          unpaidMap[provider.id] = unpaidCount;
        } catch (error) {
          console.error(`Error fetching earnings for provider ${provider.id}:`, error);
          unpaidMap[provider.id] = 0;
        }
      })
    );

    setUnpaidMonthsMap(unpaidMap);
  }

  async function fetchGlobalStats() {
    try {
      let data: any;
      if (selectedKind === 'petshop') {
        data = await api.adminPetshopGlobalStats(12);
      } else if (selectedKind === 'daycare') {
        data = await api.adminDaycareGlobalStats(12);
      } else {
        data = await api.adminGlobalStats(12);
      }
      setGlobalStats(data);
    } catch (error) {
      console.error('Error fetching global stats:', error);
    }
  }

  async function fetchProviderEarnings(providerId: string) {
    setEarningsLoading(true);
    try {
      let data: any[];
      if (selectedKind === 'petshop') {
        data = await api.adminPetshopHistoryMonthly(providerId, 12);
      } else if (selectedKind === 'daycare') {
        data = await api.adminDaycareHistoryMonthly(providerId, 12);
      } else {
        data = await api.adminHistoryMonthly(providerId, 12);
      }
      // Ensure data is always an array
      const earningsData = Array.isArray(data) ? data : [];
      setEarnings(earningsData);

      // Calculate unpaid months (months with commission > 0 and not fully collected)
      const unpaidCount = earningsData.filter((e: MonthlyEarnings & { collectedAmount?: number }) => {
        const collectedAmount = e.collectedAmount ?? (e.collected ? e.totalCommission : 0);
        return e.totalCommission > 0 && collectedAmount < e.totalCommission;
      }).length;

      setUnpaidMonthsMap((prev) => ({ ...prev, [providerId]: unpaidCount }));
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

  function openCollectionModal(earning: MonthlyEarnings & { collectedAmount?: number }) {
    const monthLabel = format(new Date(earning.month + '-01'), 'MMMM yyyy', { locale: fr });
    const collectedAmount = earning.collectedAmount ?? (earning.collected ? earning.totalCommission : 0);
    const remaining = Math.max(0, earning.totalCommission - collectedAmount);
    setModalData({
      month: earning.month,
      monthLabel,
      totalCommission: earning.totalCommission,
      collected: collectedAmount,
      remaining,
    });
    setCollectionAmount(remaining > 0 ? remaining.toString() : '');
    setCollectionNote('');
    setCollectionMode(collectedAmount > 0 ? 'add' : 'set');
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
        if (selectedKind === 'petshop') {
          await api.adminPetshopCollectMonth(selectedProvider.id, modalData.month, collectionNote || undefined, amount);
        } else if (selectedKind === 'daycare') {
          await api.adminDaycareCollectMonth(selectedProvider.id, modalData.month, collectionNote || undefined, amount);
        } else {
          await api.adminCollectMonth(selectedProvider.id, modalData.month, collectionNote || undefined, amount);
        }
      } else if (collectionMode === 'add') {
        if (selectedKind === 'petshop') {
          await api.adminPetshopAddCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
        } else if (selectedKind === 'daycare') {
          await api.adminDaycareAddCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
        } else {
          await api.adminAddCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
        }
      } else if (collectionMode === 'subtract') {
        if (selectedKind === 'petshop') {
          await api.adminPetshopSubtractCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
        } else if (selectedKind === 'daycare') {
          await api.adminDaycareSubtractCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
        } else {
          await api.adminSubtractCollection(selectedProvider.id, modalData.month, amount, collectionNote || undefined);
        }
      }
      fetchProviderEarnings(selectedProvider.id);
      fetchGlobalStats(); // Rafraîchir les totaux globaux
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
      if (selectedKind === 'petshop') {
        await api.adminPetshopCollectMonth(selectedProvider.id, month);
      } else if (selectedKind === 'daycare') {
        await api.adminDaycareCollectMonth(selectedProvider.id, month);
      } else {
        await api.adminCollectMonth(selectedProvider.id, month);
      }
      fetchProviderEarnings(selectedProvider.id);
      fetchGlobalStats(); // Rafraîchir les totaux globaux
    } catch (error) {
      console.error('Error collecting:', error);
    }
  }

  async function handleUncollect(month: string) {
    if (!selectedProvider) return;
    try {
      if (selectedKind === 'petshop') {
        await api.adminPetshopUncollectMonth(selectedProvider.id, month);
      } else if (selectedKind === 'daycare') {
        await api.adminDaycareUncollectMonth(selectedProvider.id, month);
      } else {
        await api.adminUncollectMonth(selectedProvider.id, month);
      }
      fetchProviderEarnings(selectedProvider.id);
      fetchGlobalStats(); // Rafraîchir les totaux globaux
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

  const KindIcon = kindConfig[selectedKind].icon;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Gains & Commissions</h1>
          <p className="text-gray-600 mt-1">Gérez les revenus des professionnels</p>
        </div>

        {/* Kind tabs */}
        <div className="flex gap-2 flex-wrap">
          {(Object.keys(kindConfig) as ProviderKind[]).map((kind) => {
            const config = kindConfig[kind];
            const Icon = config.icon;
            const isActive = selectedKind === kind;
            return (
              <button
                key={kind}
                onClick={() => setSelectedKind(kind)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all ${
                  isActive
                    ? `${config.bgColor} ${config.color} ring-2 ring-offset-1`
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                <Icon className="w-5 h-5" />
                {config.label}
              </button>
            );
          })}
        </div>

        {/* Stats globales */}
        {globalStats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <Card className="flex items-center space-x-4">
              <div className="p-3 rounded-lg bg-blue-100">
                <TrendingUp className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Commission générée</p>
                <p className="text-xl font-bold text-gray-900">{formatCurrency(globalStats.totalCommissionGenerated)}</p>
              </div>
            </Card>
            <Card className="flex items-center space-x-4">
              <div className="p-3 rounded-lg bg-green-100">
                <DollarSign className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Total collecté</p>
                <p className="text-xl font-bold text-green-700">{formatCurrency(globalStats.totalCollected)}</p>
              </div>
            </Card>
            <Card className="flex items-center space-x-4">
              <div className="p-3 rounded-lg bg-orange-100">
                <AlertTriangle className="w-6 h-6 text-orange-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Reste à collecter</p>
                <p className="text-xl font-bold text-orange-700">{formatCurrency(globalStats.totalRemaining)}</p>
              </div>
            </Card>
            <Card className="flex items-center space-x-4">
              <div className={`p-3 rounded-lg ${kindConfig[selectedKind].bgColor}`}>
                <KindIcon className={`w-6 h-6 ${kindConfig[selectedKind].color}`} />
              </div>
              <div>
                <p className="text-sm text-gray-500">
                  {selectedKind === 'petshop' ? 'Commandes' : 'Réservations'}
                </p>
                <p className="text-xl font-bold text-gray-900">
                  {selectedKind === 'petshop' ? (globalStats.totalOrders ?? 0) : globalStats.totalBookings}
                </p>
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
                  {filteredProviders.map((provider) => {
                    const unpaidMonths = unpaidMonthsMap[provider.id] || 0;
                    return (
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
                          <div className="flex-1">
                            <div className="flex items-center gap-2">
                              <p className="font-medium text-gray-900">{provider.displayName}</p>
                              {unpaidMonths > 0 && (
                                <div className="flex items-center gap-1 px-1.5 py-0.5 bg-red-100 text-red-700 rounded text-xs font-medium" title={`${unpaidMonths} mois impayé(s)`}>
                                  <AlertTriangle size={12} />
                                  <span>{unpaidMonths}</span>
                                </div>
                              )}
                            </div>
                            <p className="text-xs text-gray-500">{provider.address || 'Non renseigné'}</p>
                          </div>
                        </div>
                      </button>
                    );
                  })}
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

                {/* Totaux du provider sélectionné */}
                {!earningsLoading && earnings.length > 0 && (
                  <div className="grid grid-cols-3 gap-4 mb-6">
                    <div className="bg-blue-50 rounded-lg p-4">
                      <p className="text-sm text-blue-600 font-medium">Commission générée</p>
                      <p className="text-xl font-bold text-blue-900">
                        {formatCurrency(earnings.reduce((sum, e) => sum + e.totalCommission, 0))}
                      </p>
                    </div>
                    <div className="bg-green-50 rounded-lg p-4">
                      <p className="text-sm text-green-600 font-medium">Total collecté</p>
                      <p className="text-xl font-bold text-green-900">
                        {formatCurrency(earnings.reduce((sum, e) => {
                          const ext = e as MonthlyEarnings & { collectedAmount?: number };
                          return sum + (ext.collectedAmount ?? (e.collected ? e.totalCommission : 0));
                        }, 0))}
                      </p>
                    </div>
                    <div className="bg-orange-50 rounded-lg p-4">
                      <p className="text-sm text-orange-600 font-medium">Reste à collecter</p>
                      <p className="text-xl font-bold text-orange-900">
                        {formatCurrency(
                          earnings.reduce((sum, e) => sum + e.totalCommission, 0) -
                          earnings.reduce((sum, e) => {
                            const ext = e as MonthlyEarnings & { collectedAmount?: number };
                            return sum + (ext.collectedAmount ?? (e.collected ? e.totalCommission : 0));
                          }, 0)
                        )}
                      </p>
                    </div>
                  </div>
                )}

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
                        {earnings.map((earning) => {
                          const ext = earning as MonthlyEarnings & { collectedAmount?: number };
                          const collectedAmount = ext.collectedAmount ?? (earning.collected ? earning.totalCommission : 0);
                          const isPartial = collectedAmount > 0 && collectedAmount < earning.totalCommission;
                          return (
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
                                  ✓ {formatCurrency(collectedAmount)}
                                </span>
                              ) : isPartial ? (
                                <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                                  Partiel: {formatCurrency(collectedAmount)}
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
                        );
                        })}
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
                  onClick={() => setCollectionMode('subtract')}
                  className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-colors flex items-center justify-center gap-1 ${
                    collectionMode === 'subtract'
                      ? 'bg-red-100 text-red-700 border-2 border-red-500'
                      : 'bg-gray-100 text-gray-600 border-2 border-transparent hover:bg-gray-200'
                  }`}
                >
                  <Minus size={16} /> Retirer
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
              </div>
            </div>

            {/* Montant */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                {collectionMode === 'set' ? 'Nouveau total collecté' :
                 collectionMode === 'subtract' ? 'Montant à retirer' : 'Montant à ajouter'} (DA)
              </label>
              <Input
                type="number"
                value={collectionAmount}
                onChange={(e) => setCollectionAmount(e.target.value)}
                placeholder="0"
                min="0"
                max={collectionMode === 'subtract' ? modalData.collected : modalData.totalCommission}
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
              {collectionMode === 'subtract' && modalData.collected > 0 && (
                <div className="flex gap-2 mt-2">
                  <button
                    onClick={() => setCollectionAmount(modalData.collected.toString())}
                    className="text-xs text-red-600 hover:underline"
                  >
                    Tout retirer ({formatCurrency(modalData.collected)})
                  </button>
                </div>
              )}
            </div>

            {/* Calcul du nouveau total */}
            {collectionAmount && parseInt(collectionAmount, 10) > 0 && (
              <div className="mb-4 p-3 bg-blue-50 rounded-lg border border-blue-200">
                <div className="text-sm">
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-600">Actuellement collecté:</span>
                    <span className="font-medium">{formatCurrency(modalData.collected)}</span>
                  </div>
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-600">
                      {collectionMode === 'set' ? 'Nouveau montant:' :
                       collectionMode === 'subtract' ? 'Retrait:' : 'Ajout:'}
                    </span>
                    <span className={`font-medium ${collectionMode === 'subtract' ? 'text-red-600' : collectionMode === 'add' ? 'text-green-600' : ''}`}>
                      {collectionMode === 'subtract' ? '-' : collectionMode === 'add' ? '+' : ''}{formatCurrency(parseInt(collectionAmount, 10))}
                    </span>
                  </div>
                  <div className="flex justify-between pt-2 border-t border-blue-200">
                    <span className="font-semibold text-gray-800">Nouveau total:</span>
                    <span className="font-bold text-blue-700">
                      {formatCurrency(
                        collectionMode === 'set' ? parseInt(collectionAmount, 10) :
                        collectionMode === 'subtract' ? Math.max(0, modalData.collected - parseInt(collectionAmount, 10)) :
                        Math.min(modalData.totalCommission, modalData.collected + parseInt(collectionAmount, 10))
                      )}
                    </span>
                  </div>
                  <div className="flex justify-between mt-1">
                    <span className="text-xs text-gray-500">Restant à collecter:</span>
                    <span className="text-xs font-medium text-orange-600">
                      {formatCurrency(
                        modalData.totalCommission - (
                          collectionMode === 'set' ? parseInt(collectionAmount, 10) :
                          collectionMode === 'subtract' ? Math.max(0, modalData.collected - parseInt(collectionAmount, 10)) :
                          Math.min(modalData.totalCommission, modalData.collected + parseInt(collectionAmount, 10))
                        )
                      )}
                    </span>
                  </div>
                </div>
              </div>
            )}

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
