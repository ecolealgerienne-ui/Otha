import { useEffect, useState } from 'react';
import { DollarSign, TrendingUp, Calendar, Search } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile, MonthlyEarnings } from '../types';
import { format, subMonths } from 'date-fns';
import { fr } from 'date-fns/locale';

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

  useEffect(() => {
    fetchProviders();
    fetchStats();
  }, []);

  async function fetchProviders() {
    setLoading(true);
    try {
      const data = await api.listProviderApplications('APPROVED', 100);
      setProviders(data);
    } catch (error) {
      console.error('Error fetching providers:', error);
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
      setEarnings(data);
    } catch (error) {
      console.error('Error fetching earnings:', error);
    } finally {
      setEarningsLoading(false);
    }
  }

  const handleSelectProvider = (provider: ProviderProfile) => {
    setSelectedProvider(provider);
    fetchProviderEarnings(provider.id);
  };

  async function handleCollect(month: string) {
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
                              {earning.collected ? (
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => handleUncollect(earning.month)}
                                >
                                  Annuler
                                </Button>
                              ) : (
                                <Button
                                  size="sm"
                                  onClick={() => handleCollect(earning.month)}
                                >
                                  Collecter
                                </Button>
                              )}
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
    </DashboardLayout>
  );
}
