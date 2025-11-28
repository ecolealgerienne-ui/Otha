import { useEffect, useState } from 'react';
import { DollarSign, TrendingUp, Calendar, ArrowUp, ArrowDown } from 'lucide-react';
import { Card } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { MonthlyEarnings } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

export function ProEarnings() {
  const [earnings, setEarnings] = useState<MonthlyEarnings[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchEarnings();
  }, []);

  async function fetchEarnings() {
    setLoading(true);
    try {
      const data = await api.myHistoryMonthly(12);
      setEarnings(data);
    } catch (error) {
      console.error('Error fetching earnings:', error);
    } finally {
      setLoading(false);
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-DZ', {
      style: 'currency',
      currency: 'DZD',
    }).format(amount);
  };

  const totalEarnings = earnings.reduce((sum, e) => sum + e.netAmount, 0);
  const totalCommission = earnings.reduce((sum, e) => sum + e.totalCommission, 0);
  const totalBookings = earnings.reduce((sum, e) => sum + e.bookingCount, 0);
  const currentMonth = earnings[0];
  const previousMonth = earnings[1];

  const percentChange = previousMonth && previousMonth.netAmount > 0
    ? ((currentMonth?.netAmount || 0) - previousMonth.netAmount) / previousMonth.netAmount * 100
    : 0;

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Mes Gains</h1>
          <p className="text-gray-600 mt-1">Suivez vos revenus et commissions</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">Ce mois</p>
                <p className="text-2xl font-bold text-gray-900">
                  {formatCurrency(currentMonth?.netAmount || 0)}
                </p>
              </div>
              <div className={`p-3 rounded-lg ${percentChange >= 0 ? 'bg-green-100' : 'bg-red-100'}`}>
                {percentChange >= 0 ? (
                  <ArrowUp className="w-6 h-6 text-green-600" />
                ) : (
                  <ArrowDown className="w-6 h-6 text-red-600" />
                )}
              </div>
            </div>
            {previousMonth && (
              <p className={`text-sm mt-2 ${percentChange >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {percentChange >= 0 ? '+' : ''}{percentChange.toFixed(1)}% vs mois dernier
              </p>
            )}
          </Card>

          <Card>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">Total (12 mois)</p>
                <p className="text-2xl font-bold text-gray-900">{formatCurrency(totalEarnings)}</p>
              </div>
              <div className="p-3 rounded-lg bg-blue-100">
                <DollarSign className="w-6 h-6 text-blue-600" />
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">Commissions</p>
                <p className="text-2xl font-bold text-gray-900">{formatCurrency(totalCommission)}</p>
              </div>
              <div className="p-3 rounded-lg bg-orange-100">
                <TrendingUp className="w-6 h-6 text-orange-600" />
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">Réservations</p>
                <p className="text-2xl font-bold text-gray-900">{totalBookings}</p>
              </div>
              <div className="p-3 rounded-lg bg-purple-100">
                <Calendar className="w-6 h-6 text-purple-600" />
              </div>
            </div>
          </Card>
        </div>

        {/* Monthly breakdown */}
        <Card>
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Historique mensuel</h2>

          {earnings.length === 0 ? (
            <div className="text-center py-8">
              <DollarSign size={48} className="text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500">Aucun historique de gains</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200">
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-500">Mois</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">
                      Réservations
                    </th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">
                      Montant brut
                    </th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">
                      Commission
                    </th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-500">
                      Net
                    </th>
                    <th className="text-center py-3 px-4 text-sm font-medium text-gray-500">
                      Statut
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {earnings.map((earning, index) => (
                    <tr
                      key={earning.month}
                      className={`border-b border-gray-100 ${index === 0 ? 'bg-primary-50' : ''}`}
                    >
                      <td className="py-4 px-4">
                        <span className="font-medium text-gray-900">
                          {format(new Date(earning.month + '-01'), 'MMMM yyyy', { locale: fr })}
                        </span>
                        {index === 0 && (
                          <span className="ml-2 text-xs bg-primary-100 text-primary-700 px-2 py-0.5 rounded">
                            En cours
                          </span>
                        )}
                      </td>
                      <td className="text-right py-4 px-4 text-gray-600">
                        {earning.bookingCount}
                      </td>
                      <td className="text-right py-4 px-4 text-gray-600">
                        {formatCurrency(earning.totalAmount)}
                      </td>
                      <td className="text-right py-4 px-4 text-gray-600">
                        {formatCurrency(earning.totalCommission)}
                      </td>
                      <td className="text-right py-4 px-4 font-semibold text-gray-900">
                        {formatCurrency(earning.netAmount)}
                      </td>
                      <td className="text-center py-4 px-4">
                        {earning.collected ? (
                          <span className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded">
                            Payé
                          </span>
                        ) : index === 0 ? (
                          <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                            En cours
                          </span>
                        ) : (
                          <span className="text-xs bg-yellow-100 text-yellow-700 px-2 py-1 rounded">
                            En attente
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </DashboardLayout>
  );
}
