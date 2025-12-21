import { useEffect, useState } from 'react';
import { Calendar, Clock, Check, ArrowRight, ArrowLeft } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { DaycareBooking } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

export function ProDaycare() {
  const [bookings, setBookings] = useState<DaycareBooking[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  useEffect(() => {
    fetchBookings();
  }, []);

  async function fetchBookings() {
    setLoading(true);
    try {
      const data = await api.myDaycareProviderBookings();
      setBookings(data);
    } catch (error) {
      console.error('Error fetching daycare bookings:', error);
    } finally {
      setLoading(false);
    }
  }

  async function handleDropOff(bookingId: string) {
    setActionLoading(bookingId);
    try {
      await api.markDaycareDropOff(bookingId);
      await fetchBookings();
    } catch (error) {
      console.error('Error marking drop-off:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handlePickup(bookingId: string) {
    setActionLoading(bookingId);
    try {
      await api.markDaycarePickup(bookingId);
      await fetchBookings();
    } catch (error) {
      console.error('Error marking pickup:', error);
    } finally {
      setActionLoading(null);
    }
  }

  const getStatusBadge = (status: string) => {
    const styles: Record<string, string> = {
      PENDING: 'bg-yellow-100 text-yellow-700',
      CONFIRMED: 'bg-blue-100 text-blue-700',
      IN_PROGRESS: 'bg-green-100 text-green-700',
      COMPLETED: 'bg-gray-100 text-gray-700',
      CANCELLED: 'bg-red-100 text-red-700',
    };

    const labels: Record<string, string> = {
      PENDING: 'En attente',
      CONFIRMED: 'Confirmé',
      IN_PROGRESS: 'En cours',
      COMPLETED: 'Terminé',
      CANCELLED: 'Annulé',
    };

    return (
      <span className={`text-xs px-2 py-1 rounded ${styles[status] || 'bg-gray-100 text-gray-700'}`}>
        {labels[status] || status}
      </span>
    );
  };

  const pendingBookings = bookings.filter((b) => b.status === 'CONFIRMED');
  const inProgressBookings = bookings.filter((b) => b.status === 'IN_PROGRESS');
  const completedBookings = bookings.filter(
    (b) => b.status === 'COMPLETED' || b.status === 'CANCELLED'
  );

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
          <h1 className="text-2xl font-bold text-gray-900">Garderie</h1>
          <p className="text-gray-600 mt-1">Gérez les réservations de garderie</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="flex items-center space-x-4">
            <div className="p-3 rounded-lg bg-blue-100">
              <Calendar className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">À venir</p>
              <p className="text-2xl font-bold text-gray-900">{pendingBookings.length}</p>
            </div>
          </Card>

          <Card className="flex items-center space-x-4">
            <div className="p-3 rounded-lg bg-green-100">
              <Clock className="w-6 h-6 text-green-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">En cours</p>
              <p className="text-2xl font-bold text-gray-900">{inProgressBookings.length}</p>
            </div>
          </Card>

          <Card className="flex items-center space-x-4">
            <div className="p-3 rounded-lg bg-gray-100">
              <Check className="w-6 h-6 text-gray-600" />
            </div>
            <div>
              <p className="text-sm text-gray-500">Terminées</p>
              <p className="text-2xl font-bold text-gray-900">{completedBookings.length}</p>
            </div>
          </Card>
        </div>

        {/* In progress */}
        {inProgressBookings.length > 0 && (
          <Card>
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Animaux en garderie</h2>
            <div className="space-y-4">
              {inProgressBookings.map((booking) => (
                <div
                  key={booking.id}
                  className="flex items-center justify-between p-4 bg-green-50 border border-green-200 rounded-lg"
                >
                  <div className="flex items-center space-x-4">
                    <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center text-2xl">
                      🐾
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{booking.pet?.name || 'Animal'}</p>
                      <p className="text-sm text-gray-500">
                        {booking.user?.email || 'Client'} - Déposé à{' '}
                        {booking.dropOffTime
                          ? format(new Date(booking.dropOffTime), 'HH:mm')
                          : '--:--'}
                      </p>
                    </div>
                  </div>
                  <Button
                    onClick={() => handlePickup(booking.id)}
                    isLoading={actionLoading === booking.id}
                  >
                    <ArrowRight size={16} className="mr-2" />
                    Marquer récupéré
                  </Button>
                </div>
              ))}
            </div>
          </Card>
        )}

        {/* Pending drop-offs */}
        {pendingBookings.length > 0 && (
          <Card>
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Dépôts à venir</h2>
            <div className="space-y-4">
              {pendingBookings.map((booking) => (
                <div
                  key={booking.id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div className="flex items-center space-x-4">
                    <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-2xl">
                      🐾
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{booking.pet?.name || 'Animal'}</p>
                      <p className="text-sm text-gray-500">
                        {booking.user?.email || 'Client'} -{' '}
                        {format(new Date(booking.scheduledDate), 'dd MMMM yyyy', { locale: fr })}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-3">
                    {getStatusBadge(booking.status)}
                    <Button
                      variant="secondary"
                      onClick={() => handleDropOff(booking.id)}
                      isLoading={actionLoading === booking.id}
                    >
                      <ArrowLeft size={16} className="mr-2" />
                      Marquer déposé
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </Card>
        )}

        {/* Completed */}
        {completedBookings.length > 0 && (
          <Card>
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Historique récent</h2>
            <div className="space-y-3">
              {completedBookings.slice(0, 10).map((booking) => (
                <div
                  key={booking.id}
                  className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                >
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center text-lg">
                      🐾
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{booking.pet?.name || 'Animal'}</p>
                      <p className="text-xs text-gray-500">
                        {format(new Date(booking.scheduledDate), 'dd MMM yyyy', { locale: fr })}
                      </p>
                    </div>
                  </div>
                  {getStatusBadge(booking.status)}
                </div>
              ))}
            </div>
          </Card>
        )}

        {/* Empty state */}
        {bookings.length === 0 && (
          <Card className="text-center py-12">
            <Calendar size={48} className="text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">Aucune réservation de garderie</p>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
