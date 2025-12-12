import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Users, Briefcase, Heart, DollarSign, Clock } from 'lucide-react';
import { Card } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile, AdoptPost } from '../types';

interface StatCardProps {
  icon: React.ReactNode;
  label: string;
  value: string | number;
  color: string;
  link?: string;
}

function StatCard({ icon, label, value, color, link }: StatCardProps) {
  const content = (
    <Card className="flex items-center space-x-4">
      <div className={`p-3 rounded-lg ${color}`}>
        {icon}
      </div>
      <div>
        <p className="text-sm text-gray-500">{label}</p>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
      </div>
    </Card>
  );

  if (link) {
    return <Link to={link}>{content}</Link>;
  }
  return content;
}

export function AdminDashboard() {
  const [pendingProviders, setPendingProviders] = useState<ProviderProfile[]>([]);
  const [pendingAdoptions, setPendingAdoptions] = useState<AdoptPost[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const [providers, adoptions] = await Promise.all([
          api.listProviderApplications('PENDING', 5),
          api.adminAdoptList('PENDING', 5),
        ]);
        setPendingProviders(providers);
        setPendingAdoptions(adoptions.data);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      } finally {
        setLoading(false);
      }
    }
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

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard Admin</h1>
          <p className="text-gray-600 mt-1">Vue d'ensemble de la plateforme</p>
        </div>

        {/* Stats cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={<Briefcase className="w-6 h-6 text-blue-600" />}
            label="Demandes Pro en attente"
            value={pendingProviders.length}
            color="bg-blue-100"
            link="/admin/applications"
          />
          <StatCard
            icon={<Heart className="w-6 h-6 text-pink-600" />}
            label="Adoptions en attente"
            value={pendingAdoptions.length}
            color="bg-pink-100"
            link="/admin/adoptions"
          />
          <StatCard
            icon={<Users className="w-6 h-6 text-green-600" />}
            label="Utilisateurs totaux"
            value="-"
            color="bg-green-100"
            link="/admin/users"
          />
          <StatCard
            icon={<DollarSign className="w-6 h-6 text-yellow-600" />}
            label="Revenus ce mois"
            value="-"
            color="bg-yellow-100"
            link="/admin/earnings"
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
            {pendingProviders.length === 0 ? (
              <p className="text-gray-500 text-sm">Aucune demande en attente</p>
            ) : (
              <div className="space-y-3">
                {pendingProviders.map((provider) => (
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
