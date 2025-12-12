import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Calendar, Users, DollarSign, Stethoscope, Clock, TrendingUp, AlertCircle } from 'lucide-react';
import { Card } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import { useAuthStore } from '../store/authStore';
import api from '../api/client';
import type { Booking, MonthlyEarnings } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

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

export function ProDashboard() {
  const { provider } = useAuthStore();
  const [todayBookings, setTodayBookings] = useState<Booking[]>([]);
  const [monthEarnings, setMonthEarnings] = useState<MonthlyEarnings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const today = new Date();
        const start = format(today, 'yyyy-MM-dd');
        const end = format(today, 'yyyy-MM-dd');
        const month = format(today, 'yyyy-MM');

        const [bookingsResult, earnings] = await Promise.all([
          api.providerAgenda(start, end),
          api.myEarnings(month).catch(() => null),
        ]);

        console.log('Bookings result:', bookingsResult);

        // Handle wrapped response { data: [...] } or direct array
        const bookings = Array.isArray(bookingsResult)
          ? bookingsResult
          : (bookingsResult as { data?: Booking[] })?.data || [];

        setTodayBookings(bookings);
        setMonthEarnings(earnings);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, []);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-DZ', {
      style: 'currency',
      currency: 'DZD',
    }).format(amount);
  };

  // Check provider status
  if (provider?.status === 'PENDING') {
    return (
      <DashboardLayout>
        <div className="max-w-2xl mx-auto py-12">
          <Card className="text-center">
            <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Clock size={32} className="text-yellow-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Demande en cours de traitement</h2>
            <p className="text-gray-600 mb-6">
              Votre demande d'inscription en tant que professionnel est en cours d'examen.
              Vous recevrez une notification dès qu'elle sera approuvée.
            </p>
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-left">
              <p className="text-sm text-yellow-800">
                En attendant l'approbation, assurez-vous que votre carte AVN est bien lisible et que toutes vos informations sont correctes.
              </p>
            </div>
          </Card>
        </div>
      </DashboardLayout>
    );
  }

  if (provider?.status === 'REJECTED') {
    return (
      <DashboardLayout>
        <div className="max-w-2xl mx-auto py-12">
          <Card className="text-center">
            <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertCircle size={32} className="text-red-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Demande rejetée</h2>
            <p className="text-gray-600 mb-6">
              Malheureusement, votre demande d'inscription a été rejetée.
              Veuillez vérifier vos documents et soumettre une nouvelle demande.
            </p>
            <Link
              to="/pro/settings"
              className="inline-flex items-center justify-center px-6 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors"
            >
              Soumettre à nouveau
            </Link>
          </Card>
        </div>
      </DashboardLayout>
    );
  }

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
          <h1 className="text-2xl font-bold text-gray-900">
            Bonjour, {provider?.displayName || 'Docteur'}
          </h1>
          <p className="text-gray-600 mt-1">
            Voici un aperçu de votre activité
          </p>
        </div>

        {/* Stats cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={<Calendar className="w-6 h-6 text-blue-600" />}
            label="RDV aujourd'hui"
            value={todayBookings.length}
            color="bg-blue-100"
            link="/pro/agenda"
          />
          <StatCard
            icon={<DollarSign className="w-6 h-6 text-green-600" />}
            label="Gains ce mois"
            value={monthEarnings ? formatCurrency(monthEarnings.netAmount) : '-'}
            color="bg-green-100"
            link="/pro/earnings"
          />
          <StatCard
            icon={<TrendingUp className="w-6 h-6 text-purple-600" />}
            label="Réservations ce mois"
            value={monthEarnings?.bookingCount || 0}
            color="bg-purple-100"
          />
          <StatCard
            icon={<Users className="w-6 h-6 text-orange-600" />}
            label="Patients"
            value="-"
            color="bg-orange-100"
            link="/pro/patients"
          />
        </div>

        {/* Today's appointments */}
        <Card>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">
              Rendez-vous d'aujourd'hui
            </h2>
            <Link
              to="/pro/agenda"
              className="text-primary-600 hover:text-primary-700 text-sm font-medium"
            >
              Voir l'agenda
            </Link>
          </div>

          {todayBookings.length === 0 ? (
            <div className="text-center py-8">
              <Calendar size={48} className="text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500">Aucun rendez-vous prévu aujourd'hui</p>
            </div>
          ) : (
            <div className="space-y-3">
              {todayBookings.map((booking) => (
                <div
                  key={booking.id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div className="flex items-center space-x-4">
                    <div className="w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center">
                      <Stethoscope size={24} className="text-primary-600" />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">
                        {booking.service?.title || 'Consultation'}
                      </p>
                      <p className="text-sm text-gray-500">
                        {booking.user?.email || 'Client'}
                        {booking.pet && ` - ${booking.pet.name}`}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-medium text-gray-900">
                      {format(new Date(booking.scheduledAt), 'HH:mm', { locale: fr })}
                    </p>
                    <span
                      className={`text-xs px-2 py-1 rounded ${
                        booking.status === 'CONFIRMED'
                          ? 'bg-green-100 text-green-700'
                          : booking.status === 'PENDING'
                          ? 'bg-yellow-100 text-yellow-700'
                          : 'bg-gray-100 text-gray-700'
                      }`}
                    >
                      {booking.status === 'CONFIRMED'
                        ? 'Confirmé'
                        : booking.status === 'PENDING'
                        ? 'En attente'
                        : booking.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>

        {/* Quick actions */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Link to="/pro/services">
            <Card className="hover:shadow-md transition-shadow">
              <div className="flex items-center space-x-4">
                <div className="p-3 bg-primary-100 rounded-lg">
                  <Stethoscope size={24} className="text-primary-600" />
                </div>
                <div>
                  <p className="font-medium text-gray-900">Gérer mes services</p>
                  <p className="text-sm text-gray-500">Ajouter ou modifier vos prestations</p>
                </div>
              </div>
            </Card>
          </Link>

          <Link to="/pro/availability">
            <Card className="hover:shadow-md transition-shadow">
              <div className="flex items-center space-x-4">
                <div className="p-3 bg-green-100 rounded-lg">
                  <Clock size={24} className="text-green-600" />
                </div>
                <div>
                  <p className="font-medium text-gray-900">Disponibilités</p>
                  <p className="text-sm text-gray-500">Gérer vos horaires</p>
                </div>
              </div>
            </Card>
          </Link>

          <Link to="/pro/settings">
            <Card className="hover:shadow-md transition-shadow">
              <div className="flex items-center space-x-4">
                <div className="p-3 bg-purple-100 rounded-lg">
                  <Users size={24} className="text-purple-600" />
                </div>
                <div>
                  <p className="font-medium text-gray-900">Mon profil</p>
                  <p className="text-sm text-gray-500">Modifier mes informations</p>
                </div>
              </div>
            </Card>
          </Link>
        </div>
      </div>
    </DashboardLayout>
  );
}
