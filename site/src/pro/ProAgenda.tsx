import { useEffect, useState, useRef } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  Calendar,
  Check,
  X,
  Clock,
  User,
  Stethoscope,
  QrCode,
  KeyRound,
  Phone,
  DollarSign,
  AlertCircle,
  CheckCircle,
  XCircle,
} from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Booking, BookingStatus } from '../types';
import {
  format,
  addDays,
  startOfWeek,
  endOfWeek,
  eachDayOfInterval,
  isSameDay,
} from 'date-fns';
import { fr } from 'date-fns/locale';
import { Html5Qrcode } from 'html5-qrcode';

/**
 * UTC naïf : traite l'heure UTC comme heure locale (pas de conversion)
 */
function parseISOAsLocal(isoString: string): Date {
  const d = new Date(isoString);
  return new Date(
    d.getUTCFullYear(),
    d.getUTCMonth(),
    d.getUTCDate(),
    d.getUTCHours(),
    d.getUTCMinutes(),
    d.getUTCSeconds()
  );
}

export function ProAgenda() {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  // OTP Dialog
  const [showOtpDialog, setShowOtpDialog] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [otpError, setOtpError] = useState('');
  const [otpLoading, setOtpLoading] = useState(false);

  // QR Scanner
  const [showQrScanner, setShowQrScanner] = useState(false);
  const [qrLoading, setQrLoading] = useState(false);
  const scannerRef = useRef<Html5Qrcode | null>(null);

  // Pending validations action loading
  const [pendingActionId, setPendingActionId] = useState<string | null>(null);

  const weekStart = startOfWeek(currentDate, { weekStartsOn: 1 });
  const weekEnd = endOfWeek(currentDate, { weekStartsOn: 1 });
  const days = eachDayOfInterval({ start: weekStart, end: weekEnd });

  // Get bookings that need validation (CONFIRMED status, scheduled for today or past)
  const pendingValidations = bookings.filter((b) => {
    if (b.status !== 'CONFIRMED') return false;
    const scheduled = parseISOAsLocal(b.scheduledAt);
    const now = new Date();
    // RDV confirmé et l'heure est passée ou c'est aujourd'hui
    return scheduled <= now || isSameDay(scheduled, now);
  });

  useEffect(() => {
    fetchBookings();
  }, [currentDate]);

  // Cleanup QR scanner on unmount
  useEffect(() => {
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(() => {});
      }
    };
  }, []);

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
    return bookings.filter((booking) => isSameDay(parseISOAsLocal(booking.scheduledAt), date));
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

  // Confirm booking (simple)
  const handleConfirm = async () => {
    if (!selectedBooking) return;
    setActionLoading(true);
    try {
      await api.providerSetStatus(selectedBooking.id, 'CONFIRMED');
      await fetchBookings();
      setSelectedBooking(null);
    } catch (error) {
      console.error('Error confirming:', error);
      alert('Erreur lors de la confirmation');
    } finally {
      setActionLoading(false);
    }
  };

  // Mark as completed
  const handleComplete = async (bookingId?: string) => {
    const id = bookingId || selectedBooking?.id;
    if (!id) return;

    if (bookingId) {
      setPendingActionId(bookingId);
    } else {
      setActionLoading(true);
    }

    try {
      await api.providerSetStatus(id, 'COMPLETED');
      await fetchBookings();
      if (!bookingId) setSelectedBooking(null);
    } catch (error) {
      console.error('Error completing:', error);
      alert('Erreur lors de la finalisation');
    } finally {
      setActionLoading(false);
      setPendingActionId(null);
    }
  };

  // Cancel booking
  const handleCancel = async (bookingId?: string) => {
    const id = bookingId || selectedBooking?.id;
    if (!id) return;

    if (!bookingId && !confirm('Voulez-vous vraiment annuler ce rendez-vous ?')) return;

    if (bookingId) {
      setPendingActionId(bookingId);
    } else {
      setActionLoading(true);
    }

    try {
      await api.providerSetStatus(id, 'CANCELLED');
      await fetchBookings();
      if (!bookingId) setSelectedBooking(null);
    } catch (error) {
      console.error('Error cancelling:', error);
      alert("Erreur lors de l'annulation");
    } finally {
      setActionLoading(false);
      setPendingActionId(null);
    }
  };

  // Mark as no-show (client absent)
  const handleNoShow = async (bookingId: string) => {
    setPendingActionId(bookingId);
    try {
      await api.providerSetStatus(bookingId, 'CANCELLED');
      await fetchBookings();
    } catch (error) {
      console.error('Error marking no-show:', error);
      alert('Erreur');
    } finally {
      setPendingActionId(null);
    }
  };

  // OTP Verification
  const openOtpDialog = () => {
    setOtpCode('');
    setOtpError('');
    setShowOtpDialog(true);
  };

  const handleVerifyOtp = async () => {
    if (!selectedBooking || otpCode.length !== 6) {
      setOtpError('Veuillez entrer un code à 6 chiffres');
      return;
    }

    setOtpLoading(true);
    setOtpError('');
    try {
      const result = await api.verifyBookingOtp(selectedBooking.id, otpCode);
      if (result.success) {
        setShowOtpDialog(false);
        await fetchBookings();
        setSelectedBooking(null);
        alert('Code vérifié avec succès !');
      } else {
        setOtpError(result.message || 'Code invalide');
      }
    } catch (error: unknown) {
      console.error('OTP verification error:', error);
      const errorMessage =
        error instanceof Error
          ? error.message
          : (error as { response?: { data?: { message?: string } } })?.response?.data?.message ||
            'Erreur de vérification';
      setOtpError(errorMessage);
    } finally {
      setOtpLoading(false);
    }
  };

  // QR Code Scanner
  const startQrScanner = async () => {
    setShowQrScanner(true);
    setQrLoading(true);

    await new Promise((resolve) => setTimeout(resolve, 100));

    try {
      const scanner = new Html5Qrcode('qr-reader');
      scannerRef.current = scanner;

      await scanner.start(
        { facingMode: 'environment' },
        { fps: 10, qrbox: { width: 250, height: 250 } },
        handleQrCodeSuccess,
        () => {}
      );
    } catch (error) {
      console.error('QR Scanner error:', error);
      alert('Impossible de démarrer la caméra');
      setShowQrScanner(false);
    } finally {
      setQrLoading(false);
    }
  };

  const stopQrScanner = async () => {
    if (scannerRef.current) {
      try {
        await scannerRef.current.stop();
      } catch {
        // Ignore stop errors
      }
      scannerRef.current = null;
    }
    setShowQrScanner(false);
  };

  const handleQrCodeSuccess = async (decodedText: string) => {
    await stopQrScanner();
    console.log('QR Code scanned:', decodedText);

    setQrLoading(true);
    try {
      let petId = decodedText;
      if (decodedText.includes('pet/')) {
        const match = decodedText.match(/pet\/([a-zA-Z0-9-]+)/);
        if (match) petId = match[1];
      } else if (decodedText.includes('petId=')) {
        const match = decodedText.match(/petId=([a-zA-Z0-9-]+)/);
        if (match) petId = match[1];
      }

      const booking = await api.getActiveBookingForPet(petId);
      if (booking) {
        await api.proConfirmBooking(booking.id, 'QR_SCAN');
        await fetchBookings();
        alert('Rendez-vous confirmé par QR Code !');
      } else {
        alert('Aucun rendez-vous actif trouvé pour cet animal');
      }
    } catch (error) {
      console.error('QR confirmation error:', error);
      alert('Erreur lors de la confirmation par QR');
    } finally {
      setQrLoading(false);
    }
  };

  const getStatusBadge = (status: BookingStatus) => {
    const styles: Record<string, string> = {
      PENDING: 'bg-yellow-100 text-yellow-700',
      CONFIRMED: 'bg-green-100 text-green-700',
      COMPLETED: 'bg-blue-100 text-blue-700',
      CANCELLED: 'bg-red-100 text-red-700',
      CANCELED: 'bg-red-100 text-red-700',
      PENDING_PRO_VALIDATION: 'bg-orange-100 text-orange-700',
      AWAITING_CONFIRMATION: 'bg-purple-100 text-purple-700',
    };

    const labels: Record<string, string> = {
      PENDING: 'En attente',
      CONFIRMED: 'Confirmé',
      COMPLETED: 'Terminé',
      CANCELLED: 'Annulé',
      CANCELED: 'Annulé',
      PENDING_PRO_VALIDATION: 'À valider',
      AWAITING_CONFIRMATION: 'En attente confirm.',
    };

    return (
      <span className={`text-xs px-2 py-1 rounded ${styles[status] || 'bg-gray-100 text-gray-700'}`}>
        {labels[status] || status}
      </span>
    );
  };

  const isPending = (status: BookingStatus) =>
    status === 'PENDING' || status === 'PENDING_PRO_VALIDATION';
  const isConfirmed = (status: BookingStatus) => status === 'CONFIRMED';
  const canCancel = (status: BookingStatus) => isPending(status) || isConfirmed(status);

  return (
    <DashboardLayout>
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Agenda</h1>
            <p className="text-gray-600 mt-1">Gérez vos rendez-vous</p>
          </div>
          <div className="flex items-center space-x-2">
            <Button variant="secondary" size="sm" onClick={startQrScanner}>
              <QrCode size={16} className="mr-1" />
              Scanner QR
            </Button>
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

        {/* Pending Validations Banner */}
        {pendingValidations.length > 0 && (
          <div className="bg-orange-50 border border-orange-200 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-3">
              <AlertCircle className="text-orange-600" size={20} />
              <h3 className="font-semibold text-orange-900">
                {pendingValidations.length} rendez-vous à valider
              </h3>
            </div>
            <div className="space-y-3">
              {pendingValidations.slice(0, 5).map((booking) => (
                <div
                  key={booking.id}
                  className="bg-white rounded-lg p-3 flex items-center justify-between shadow-sm"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-orange-100 rounded-full flex items-center justify-center">
                      <User size={18} className="text-orange-600" />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">
                        {booking.user?.displayName || booking.user?.email || 'Client'}
                      </p>
                      <p className="text-sm text-gray-500">
                        {format(parseISOAsLocal(booking.scheduledAt), "HH:mm", { locale: fr })} - {booking.service?.title || 'Consultation'}
                        {booking.pet && ` • ${booking.pet.name}`}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm text-gray-600 mr-2">Le client est-il présent ?</span>
                    <button
                      onClick={() => handleComplete(booking.id)}
                      disabled={pendingActionId === booking.id}
                      className="flex items-center gap-1 px-3 py-1.5 bg-green-100 hover:bg-green-200 text-green-700 rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
                    >
                      <CheckCircle size={16} />
                      Oui
                    </button>
                    <button
                      onClick={() => handleNoShow(booking.id)}
                      disabled={pendingActionId === booking.id}
                      className="flex items-center gap-1 px-3 py-1.5 bg-red-100 hover:bg-red-200 text-red-700 rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
                    >
                      <XCircle size={16} />
                      Non
                    </button>
                  </div>
                </div>
              ))}
              {pendingValidations.length > 5 && (
                <p className="text-sm text-orange-700 text-center">
                  Et {pendingValidations.length - 5} autres...
                </p>
              )}
            </div>
          </div>
        )}

        {/* Week header */}
        <div className="text-center text-lg font-medium text-gray-900">
          {format(weekStart, 'd MMM', { locale: fr })} -{' '}
          {format(weekEnd, 'd MMM yyyy', { locale: fr })}
        </div>

        {/* Main content: Calendar + Side Panel */}
        <div className="flex gap-6">
          {/* Calendar grid - takes remaining space */}
          <div className="flex-1 grid grid-cols-1 lg:grid-cols-7 gap-3">
            {days.map((day) => {
              const dayBookings = getBookingsForDay(day);
              const isToday = isSameDay(day, new Date());

              return (
                <Card
                  key={day.toISOString()}
                  padding="sm"
                  className={isToday ? 'ring-2 ring-primary-500' : ''}
                >
                  <div
                    className={`text-center pb-2 border-b border-gray-100 ${isToday ? 'text-primary-600' : ''}`}
                  >
                    <p className="text-xs text-gray-500 uppercase">
                      {format(day, 'EEE', { locale: fr })}
                    </p>
                    <p
                      className={`text-lg font-semibold ${isToday ? 'text-primary-600' : 'text-gray-900'}`}
                    >
                      {format(day, 'd')}
                    </p>
                  </div>

                  <div className="mt-2 space-y-2 min-h-[120px]">
                    {loading ? (
                      <div className="flex items-center justify-center h-full">
                        <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600" />
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
                              {format(parseISOAsLocal(booking.scheduledAt), 'HH:mm')}
                            </span>
                            <div className="flex items-center gap-1">
                              {booking.user?.isFirstBooking && (
                                <span className="bg-amber-100 text-amber-700 text-[10px] px-1 py-0.5 rounded-full">
                                  ★
                                </span>
                              )}
                              {getStatusBadge(booking.status)}
                            </div>
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

          {/* Side Panel - Fixed width, sticky */}
          <div className="w-80 flex-shrink-0">
            <div className="sticky top-4">
              {selectedBooking ? (
                <Card className="shadow-lg">
                  <div className="flex items-start justify-between mb-4">
                    <h3 className="font-semibold text-gray-900">Détails du RDV</h3>
                    <button
                      onClick={() => setSelectedBooking(null)}
                      className="text-gray-400 hover:text-gray-600"
                    >
                      <X size={20} />
                    </button>
                  </div>

                  <div className="space-y-4">
                    {/* Date & Time */}
                    <div className="flex items-center space-x-3">
                      <div className="p-2 bg-primary-100 rounded-lg">
                        <Calendar size={18} className="text-primary-600" />
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Date & Heure</p>
                        <p className="font-medium text-sm">
                          {format(parseISOAsLocal(selectedBooking.scheduledAt), "EEE d MMM 'à' HH:mm", {
                            locale: fr,
                          })}
                        </p>
                      </div>
                    </div>

                    {/* Service */}
                    <div className="flex items-center space-x-3">
                      <div className="p-2 bg-blue-100 rounded-lg">
                        <Stethoscope size={18} className="text-blue-600" />
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Service</p>
                        <p className="font-medium text-sm">{selectedBooking.service?.title || 'Consultation'}</p>
                      </div>
                    </div>

                    {/* Duration */}
                    <div className="flex items-center space-x-3">
                      <div className="p-2 bg-green-100 rounded-lg">
                        <Clock size={18} className="text-green-600" />
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Durée</p>
                        <p className="font-medium text-sm">{selectedBooking.service?.durationMin || 30} min</p>
                      </div>
                    </div>

                    {/* Client */}
                    <div className="flex items-center space-x-3">
                      <div className="p-2 bg-purple-100 rounded-lg">
                        <User size={18} className="text-purple-600" />
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Client</p>
                        <div className="flex items-center gap-2">
                          <p className="font-medium text-sm">
                            {selectedBooking.user?.displayName || selectedBooking.user?.email || 'Client'}
                          </p>
                          {selectedBooking.user?.isFirstBooking && (
                            <span className="bg-amber-100 text-amber-700 text-[10px] px-1.5 py-0.5 rounded-full">
                              ★ Nouveau
                            </span>
                          )}
                        </div>
                        {isConfirmed(selectedBooking.status) && selectedBooking.user?.phone && (
                          <a
                            href={`tel:${selectedBooking.user.phone}`}
                            className="text-xs text-primary-600 flex items-center gap-1"
                          >
                            <Phone size={10} />
                            {selectedBooking.user.phone}
                          </a>
                        )}
                      </div>
                    </div>

                    {/* Pet */}
                    {selectedBooking.pet && (
                      <div className="flex items-center space-x-3">
                        <div className="p-2 bg-orange-100 rounded-lg">
                          <span className="text-orange-600 text-sm">🐾</span>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Animal</p>
                          <p className="font-medium text-sm">
                            {selectedBooking.pet.name} ({selectedBooking.pet.species})
                          </p>
                        </div>
                      </div>
                    )}

                    {/* Price */}
                    {selectedBooking.service?.price != null && (
                      <div className="flex items-center space-x-3">
                        <div className="p-2 bg-emerald-100 rounded-lg">
                          <DollarSign size={18} className="text-emerald-600" />
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Prix total</p>
                          <p className="font-medium text-sm">
                            {(selectedBooking.service.price + (selectedBooking.commissionDa || 0))} DA
                          </p>
                        </div>
                      </div>
                    )}

                    {/* Status */}
                    <div>
                      <p className="text-xs text-gray-500 mb-1">Statut</p>
                      {getStatusBadge(selectedBooking.status)}
                    </div>

                    {/* Notes */}
                    {selectedBooking.notes && (
                      <div>
                        <p className="text-xs text-gray-500">Notes</p>
                        <p className="text-sm text-gray-700">{selectedBooking.notes}</p>
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  <div className="flex flex-wrap gap-2 mt-4 pt-4 border-t border-gray-100">
                    {isPending(selectedBooking.status) && (
                      <Button size="sm" onClick={handleConfirm} isLoading={actionLoading}>
                        <Check size={14} className="mr-1" />
                        Confirmer
                      </Button>
                    )}

                    {isConfirmed(selectedBooking.status) && (
                      <Button size="sm" onClick={() => handleComplete()} isLoading={actionLoading}>
                        <Check size={14} className="mr-1" />
                        Terminer
                      </Button>
                    )}

                    {(isPending(selectedBooking.status) || isConfirmed(selectedBooking.status)) && (
                      <Button variant="secondary" size="sm" onClick={openOtpDialog}>
                        <KeyRound size={14} className="mr-1" />
                        OTP
                      </Button>
                    )}

                    {canCancel(selectedBooking.status) && (
                      <Button variant="danger" size="sm" onClick={() => handleCancel()} isLoading={actionLoading}>
                        <X size={14} className="mr-1" />
                        Annuler
                      </Button>
                    )}
                  </div>
                </Card>
              ) : (
                <Card className="text-center py-12 text-gray-400">
                  <Calendar size={48} className="mx-auto mb-4 opacity-50" />
                  <p>Sélectionnez un rendez-vous</p>
                  <p className="text-sm">pour voir les détails</p>
                </Card>
              )}
            </div>
          </div>
        </div>

        {/* OTP Verification Dialog */}
        {showOtpDialog && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-xl max-w-md w-full p-6">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-lg font-bold text-gray-900">Vérification OTP</h3>
                <button
                  onClick={() => setShowOtpDialog(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X size={24} />
                </button>
              </div>

              <p className="text-gray-600 mb-4">
                Demandez au client le code à 6 chiffres affiché sur son téléphone.
              </p>

              <input
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                maxLength={6}
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                placeholder="000000"
                className="w-full text-center text-3xl tracking-widest font-mono px-4 py-4 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 mb-4"
              />

              {otpError && (
                <p className="text-red-500 text-sm mb-4 text-center">{otpError}</p>
              )}

              <div className="flex gap-3">
                <Button
                  variant="secondary"
                  className="flex-1"
                  onClick={() => setShowOtpDialog(false)}
                >
                  Annuler
                </Button>
                <Button
                  className="flex-1"
                  onClick={handleVerifyOtp}
                  isLoading={otpLoading}
                  disabled={otpCode.length !== 6}
                >
                  Vérifier
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* QR Scanner Modal */}
        {showQrScanner && (
          <div className="fixed inset-0 bg-black bg-opacity-90 flex flex-col items-center justify-center z-50 p-4">
            <div className="bg-white rounded-xl max-w-md w-full overflow-hidden">
              <div className="flex items-center justify-between p-4 border-b">
                <h3 className="text-lg font-bold text-gray-900">Scanner QR Code</h3>
                <button onClick={stopQrScanner} className="text-gray-400 hover:text-gray-600">
                  <X size={24} />
                </button>
              </div>

              <div className="relative">
                <div id="qr-reader" className="w-full" />
                {qrLoading && (
                  <div className="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
                  </div>
                )}
              </div>

              <div className="p-4">
                <p className="text-gray-600 text-center text-sm">
                  Scannez le QR Code du carnet de santé de l'animal pour confirmer le rendez-vous.
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
