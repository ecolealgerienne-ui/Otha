import { useEffect, useState } from 'react';
import { ChevronLeft, ChevronRight, Calendar, Check, X, Clock, User, Stethoscope } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Booking, BookingStatus } from '../types';
import { format, addDays, startOfWeek, endOfWeek, eachDayOfInterval, isSameDay, parseISO } from 'date-fns';
import { fr } from 'date-fns/locale';

export function ProAgenda() {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const weekStart = startOfWeek(currentDate, { weekStartsOn: 1 });
  const weekEnd = endOfWeek(currentDate, { weekStartsOn: 1 });
  const days = eachDayOfInterval({ start: weekStart, end: weekEnd });

  useEffect(() => {
    fetchBookings();
  }, [currentDate]);

  async function fetchBookings() {
    setLoading(true);
    try {
      const fromIso = format(weekStart, 'yyyy-MM-dd');
      const toIso = format(weekEnd, 'yyyy-MM-dd');
      const data = await api.providerAgenda(fromIso, toIso);
      setBookings(data);
    } catch (error) {
      console.error('Error fetching bookings:', error);
    } finally {
      setLoading(false);
    }
  }

  const getBookingsForDay = (date: Date) => {
    return bookings.filter((booking) =>
      isSameDay(parseISO(booking.scheduledAt), date)
    );
  };

  const handlePrevWeek = () => {
    setCurrentDate(addDays(currentDate, -7));
  };

  const handleNextWeek = () => {
    setCurrentDate(addDays(currentDate, 7));
  };

  const handleToday = () => {
    setCurrentDate(new Date());
  };

  const handleStatusChange = async (bookingId: string, status: BookingStatus) => {
    setActionLoading(true);
    try {
      await api.providerSetStatus(bookingId, status);
      await fetchBookings();
      setSelectedBooking(null);
    } catch (error) {
      console.error('Error changing status:', error);
    } finally {
      setActionLoading(false);
    }
  };

  const getStatusBadge = (status: BookingStatus) => {
    const styles: Record<string, string> = {
      PENDING: 'bg-yellow-100 text-yellow-700',
      CONFIRMED: 'bg-green-100 text-green-700',
      COMPLETED: 'bg-blue-100 text-blue-700',
      CANCELLED: 'bg-red-100 text-red-700',
      PENDING_PRO_VALIDATION: 'bg-orange-100 text-orange-700',
    };

    const labels: Record<string, string> = {
      PENDING: 'En attente',
      CONFIRMED: 'Confirmé',
      COMPLETED: 'Terminé',
      CANCELLED: 'Annulé',
      PENDING_PRO_VALIDATION: 'À valider',
    };

    return (
      <span className={`text-xs px-2 py-1 rounded ${styles[status] || 'bg-gray-100 text-gray-700'}`}>
        {labels[status] || status}
      </span>
    );
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Agenda</h1>
            <p className="text-gray-600 mt-1">Gérez vos rendez-vous</p>
          </div>
          <div className="flex items-center space-x-2">
            <Button variant="secondary" size="sm" onClick={handlePrevWeek}>
              <ChevronLeft size={16} />
            </Button>
            <Button variant="secondary" size="sm" onClick={handleToday}>
              Aujourd'hui
            </Button>
            <Button variant="secondary" size="sm" onClick={handleNextWeek}>
              <ChevronRight size={16} />
            </Button>
          </div>
        </div>

        {/* Week header */}
        <div className="text-center text-lg font-medium text-gray-900">
          {format(weekStart, 'd MMM', { locale: fr })} - {format(weekEnd, 'd MMM yyyy', { locale: fr })}
        </div>

        {/* Calendar grid */}
        <div className="grid grid-cols-1 lg:grid-cols-7 gap-4">
          {days.map((day) => {
            const dayBookings = getBookingsForDay(day);
            const isToday = isSameDay(day, new Date());

            return (
              <Card
                key={day.toISOString()}
                padding="sm"
                className={isToday ? 'ring-2 ring-primary-500' : ''}
              >
                <div className={`text-center pb-2 border-b border-gray-100 ${isToday ? 'text-primary-600' : ''}`}>
                  <p className="text-xs text-gray-500 uppercase">
                    {format(day, 'EEE', { locale: fr })}
                  </p>
                  <p className={`text-lg font-semibold ${isToday ? 'text-primary-600' : 'text-gray-900'}`}>
                    {format(day, 'd')}
                  </p>
                </div>

                <div className="mt-2 space-y-2 min-h-[150px]">
                  {loading ? (
                    <div className="flex items-center justify-center h-full">
                      <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
                    </div>
                  ) : dayBookings.length === 0 ? (
                    <p className="text-xs text-gray-400 text-center py-4">Aucun RDV</p>
                  ) : (
                    dayBookings.map((booking) => (
                      <button
                        key={booking.id}
                        className={`w-full text-left p-2 rounded-lg text-xs transition-colors ${
                          selectedBooking?.id === booking.id
                            ? 'bg-primary-100 border border-primary-300'
                            : 'bg-gray-50 hover:bg-gray-100'
                        }`}
                        onClick={() => setSelectedBooking(booking)}
                      >
                        <div className="flex items-center justify-between mb-1">
                          <span className="font-medium">
                            {format(parseISO(booking.scheduledAt), 'HH:mm')}
                          </span>
                          {getStatusBadge(booking.status)}
                        </div>
                        <p className="text-gray-600 truncate">
                          {booking.service?.title || 'Consultation'}
                        </p>
                      </button>
                    ))
                  )}
                </div>
              </Card>
            );
          })}
        </div>

        {/* Selected booking detail */}
        {selectedBooking && (
          <Card>
            <div className="flex items-start justify-between mb-4">
              <h3 className="font-semibold text-gray-900">Détails du rendez-vous</h3>
              <button
                onClick={() => setSelectedBooking(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X size={20} />
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-primary-100 rounded-lg">
                    <Calendar size={20} className="text-primary-600" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-500">Date & Heure</p>
                    <p className="font-medium">
                      {format(parseISO(selectedBooking.scheduledAt), "EEEE d MMMM yyyy 'à' HH:mm", {
                        locale: fr,
                      })}
                    </p>
                  </div>
                </div>

                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-blue-100 rounded-lg">
                    <Stethoscope size={20} className="text-blue-600" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-500">Service</p>
                    <p className="font-medium">{selectedBooking.service?.title || 'Consultation'}</p>
                  </div>
                </div>

                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-green-100 rounded-lg">
                    <Clock size={20} className="text-green-600" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-500">Durée</p>
                    <p className="font-medium">{selectedBooking.service?.durationMin || 30} minutes</p>
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <div className="flex items-center space-x-3">
                  <div className="p-2 bg-purple-100 rounded-lg">
                    <User size={20} className="text-purple-600" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-500">Client</p>
                    <p className="font-medium">{selectedBooking.user?.email || 'Client'}</p>
                  </div>
                </div>

                {selectedBooking.pet && (
                  <div className="flex items-center space-x-3">
                    <div className="p-2 bg-orange-100 rounded-lg">
                      <span className="text-orange-600">🐾</span>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500">Animal</p>
                      <p className="font-medium">
                        {selectedBooking.pet.name} ({selectedBooking.pet.species})
                      </p>
                    </div>
                  </div>
                )}

                <div>
                  <p className="text-sm text-gray-500 mb-1">Statut</p>
                  {getStatusBadge(selectedBooking.status)}
                </div>

                {selectedBooking.notes && (
                  <div>
                    <p className="text-sm text-gray-500">Notes</p>
                    <p className="text-gray-700">{selectedBooking.notes}</p>
                  </div>
                )}
              </div>
            </div>

            {/* Actions */}
            {(selectedBooking.status === 'PENDING' || selectedBooking.status === 'PENDING_PRO_VALIDATION') && (
              <div className="flex space-x-3 mt-6 pt-4 border-t border-gray-100">
                <Button
                  className="flex-1"
                  onClick={() => handleStatusChange(selectedBooking.id, 'CONFIRMED')}
                  isLoading={actionLoading}
                >
                  <Check size={16} className="mr-2" />
                  Confirmer
                </Button>
                <Button
                  variant="danger"
                  className="flex-1"
                  onClick={() => handleStatusChange(selectedBooking.id, 'CANCELLED')}
                  isLoading={actionLoading}
                >
                  <X size={16} className="mr-2" />
                  Annuler
                </Button>
              </div>
            )}

            {selectedBooking.status === 'CONFIRMED' && (
              <div className="flex space-x-3 mt-6 pt-4 border-t border-gray-100">
                <Button
                  className="flex-1"
                  onClick={() => handleStatusChange(selectedBooking.id, 'COMPLETED')}
                  isLoading={actionLoading}
                >
                  <Check size={16} className="mr-2" />
                  Marquer comme terminé
                </Button>
              </div>
            )}
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
