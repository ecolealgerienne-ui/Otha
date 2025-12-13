import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Users, Briefcase, Heart, DollarSign, Clock, TrendingUp, UserPlus, AlertCircle, RefreshCw } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile, AdoptPost } from '../types';
import { format, subMonths } from 'date-fns';

interface StatCardProps {
  icon: React.ReactNode;
  label: string;
  value: string | number;
  color: string;
  link?: string;
  badge?: number;
}

function StatCard({ icon, label, value, color, link, badge }: StatCardProps) {
  const content = (
    <Card className="flex items-center space-x-4 relative">
      <div className={`p-3 rounded-lg ${color}`}>
        {icon}
      </div>
      <div>
        <p className="text-sm text-gray-500">{label}</p>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
      </div>
      {badge !== undefined && badge > 0 && (
        <span className="absolute top-2 right-2 bg-yellow-500 text-white text-xs font-bold px-2 py-0.5 rounded-full">
          {badge}
        </span>
      )}
    </Card>
  );

  if (link) {
    return <Link to={link}>{content}</Link>;
  }
  return content;
}

// Format currency in DZD
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('fr-DZ', {
    style: 'currency',
    currency: 'DZD',
    maximumFractionDigits: 0,
  }).format(amount);
}

export function AdminDashboard() {
  const [recentProviders, setRecentProviders] = useState<ProviderProfile[]>([]);
  const [pendingAdoptions, setPendingAdoptions] = useState<AdoptPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Stats counters
  const [clientsCount, setClientsCount] = useState<number>(0);
  const [prosApprovedCount, setProsApprovedCount] = useState<number>(0);
  const [pendingCount, setPendingCount] = useState<number>(0);
  const [rejectedCount, setRejectedCount] = useState<number>(0);
  const [signups30d, setSignups30d] = useState<number>(0);
  const [traceabilityStats, setTraceabilityStats] = useState<{
    totalBookings: number;
    totalAmount: number;
    totalCommission: number;
  } | null>(null);

  const fetchData = async () => {
    setLoading(true);
    setError(null);

    try {
      // Fetch all data in parallel with individual error handling
      const [
        providers,
        adoptions,
        approvedProviders,
        allPendingProviders,
        allRejectedProviders,
        clients,
        stats,
      ] = await Promise.all([
        api.listProviderApplications('PENDING', 5).catch((e) => { console.error('Pending providers error:', e); return []; }),
        api.adminAdoptList('PENDING', 5).catch((e) => { console.error('Adoptions error:', e); return { data: [] }; }),
        api.listProviderApplications('APPROVED', 1000).catch((e) => { console.error('Approved providers error:', e); return []; }),
        api.listProviderApplications('PENDING', 1000).catch((e) => { console.error('All pending error:', e); return []; }),
        api.listProviderApplications('REJECTED', 1000).catch((e) => { console.error('Rejected error:', e); return []; }),
        api.adminListUsers(undefined, 1000, 0, 'USER').catch((e) => { console.error('Users error:', e); return []; }),
        api.adminTraceabilityStats(
          format(subMonths(new Date(), 1), 'yyyy-MM-dd'),
          format(new Date(), 'yyyy-MM-dd')
        ).catch((e) => { console.error('Traceability error:', e); return null; }),
      ]);

      setRecentProviders(providers || []);
      setPendingAdoptions(adoptions?.data || []);
      setProsApprovedCount(approvedProviders?.length || 0);
      setPendingCount(allPendingProviders?.length || 0);
      setRejectedCount(allRejectedProviders?.length || 0);
      setClientsCount(clients?.length || 0);
      setTraceabilityStats(stats);

      // Calculate signups in last 30 days
      if (clients && Array.isArray(clients)) {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const recentSignups = clients.filter((user) => {
          const createdAt = user.createdAt ? new Date(user.createdAt) : null;
          return createdAt && createdAt > thirtyDaysAgo;
        });
        setSignups30d(recentSignups.length);
      }
    } catch (err) {
      console.error('Error fetching dashboard data:', err);
      setError('Erreur lors du chargement des données');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
        </div>
      </DashboardLayout>
    );
  }

  if (error) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center h-64 space-y-4">
          <AlertCircle className="w-12 h-12 text-red-500" />
          <p className="text-gray-600">{error}</p>
          <Button onClick={fetchData}>
            <RefreshCw size={16} className="mr-2" />
            Réessayer
          </Button>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard Admin</h1>
          <p className="text-gray-600 mt-1">Vue d'ensemble de la plateforme</p>
        </div>

        {/* Stats cards - Row 1 */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={<Users className="w-6 h-6 text-green-600" />}
            label="Clients"
            value={clientsCount}
            color="bg-green-100"
            link="/admin/users"
          />
          <StatCard
            icon={<Briefcase className="w-6 h-6 text-blue-600" />}
            label="Pros approuvés"
            value={prosApprovedCount}
            color="bg-blue-100"
            link="/admin/applications"
          />
          <StatCard
            icon={<Clock className="w-6 h-6 text-orange-600" />}
            label="En attente / Rejetés"
            value={`${pendingCount} / ${rejectedCount}`}
            color="bg-orange-100"
            link="/admin/applications"
            badge={pendingCount > 0 ? pendingCount : undefined}
          />
          <StatCard
            icon={<Heart className="w-6 h-6 text-pink-600" />}
            label="Adoptions à modérer"
            value={pendingAdoptions.length}
            color="bg-pink-100"
            link="/admin/adoptions"
            badge={pendingAdoptions.length > 0 ? pendingAdoptions.length : undefined}
          />
        </div>

        {/* Stats cards - Row 2: Financial & Activity */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard
            icon={<DollarSign className="w-6 h-6 text-yellow-600" />}
            label="Revenus ce mois"
            value={traceabilityStats ? formatCurrency(traceabilityStats.totalAmount) : '-'}
            color="bg-yellow-100"
            link="/admin/earnings"
          />
          <StatCard
            icon={<TrendingUp className="w-6 h-6 text-purple-600" />}
            label="Commissions"
            value={traceabilityStats ? formatCurrency(traceabilityStats.totalCommission) : '-'}
            color="bg-purple-100"
            link="/admin/earnings"
          />
          <StatCard
            icon={<UserPlus className="w-6 h-6 text-teal-600" />}
            label="Inscriptions (30j)"
            value={signups30d}
            color="bg-teal-100"
            link="/admin/users"
          />
        </div>

        {/* Recent pending providers */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Demandes Pro récentes</h2>
              <Link to="/admin/applications" className="text-primary-600 hover:text-primary-700 text-sm font-medium">
                Voir tout
              </Link>
            </div>
            {recentProviders.length === 0 ? (
              <p className="text-gray-500 text-sm">Aucune demande en attente</p>
            ) : (
              <div className="space-y-3">
                {recentProviders.map((provider) => (
                  <div
                    key={provider.id}
                    className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                  >
                    <div className="flex items-center space-x-3">
                      <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
                        <span className="text-primary-700 font-medium">
                          {provider.displayName?.charAt(0) || '?'}
                        </span>
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">{provider.displayName}</p>
                        <p className="text-sm text-gray-500">{provider.address || 'Adresse non renseignée'}</p>
                      </div>
                    </div>
                    <span className="flex items-center text-xs text-yellow-600 bg-yellow-100 px-2 py-1 rounded">
                      <Clock size={12} className="mr-1" />
                      En attente
                    </span>
                  </div>
                ))}
              </div>
            )}
          </Card>

          <Card>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Adoptions récentes</h2>
              <Link to="/admin/adoptions" className="text-primary-600 hover:text-primary-700 text-sm font-medium">
                Voir tout
              </Link>
            </div>
            {pendingAdoptions.length === 0 ? (
              <p className="text-gray-500 text-sm">Aucune adoption en attente</p>
            ) : (
              <div className="space-y-3">
                {pendingAdoptions.map((post) => (
                  <div
                    key={post.id}
                    className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                  >
                    <div className="flex items-center space-x-3">
                      {post.images?.[0] ? (
                        <img
                          src={post.images[0].url}
                          alt={post.name}
                          className="w-10 h-10 rounded-lg object-cover"
                        />
                      ) : (
                        <div className="w-10 h-10 bg-pink-100 rounded-lg flex items-center justify-center">
                          <Heart size={20} className="text-pink-600" />
                        </div>
                      )}
                      <div>
                        <p className="font-medium text-gray-900">{post.name}</p>
                        <p className="text-sm text-gray-500">{post.species} - {post.location}</p>
                      </div>
                    </div>
                    <span className="flex items-center text-xs text-yellow-600 bg-yellow-100 px-2 py-1 rounded">
                      <Clock size={12} className="mr-1" />
                      En attente
                    </span>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>
      </div>
    </DashboardLayout>
  );
}
