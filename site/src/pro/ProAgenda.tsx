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

// Commission par défaut (sera remplacée par la valeur du provider)
const DEFAULT_COMMISSION_DA = 100;

/**
 * UTC naïf : traite l'heure UTC comme heure locale (pas de conversion)
 * Exemple: "2024-01-01T17:00:00.000Z" → affiche 17:00 (pas 18:00 en GMT+1)
 * Correspond au comportement Flutter: DateTime.parse(iso).toUtc()
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
  const [commissionDa, setCommissionDa] = useState(DEFAULT_COMMISSION_DA);

  // OTP Dialog
  const [showOtpDialog, setShowOtpDialog] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [otpError, setOtpError] = useState('');
  const [otpLoading, setOtpLoading] = useState(false);

  // QR Scanner
  const [showQrScanner, setShowQrScanner] = useState(false);
  const [qrLoading, setQrLoading] = useState(false);
  const scannerRef = useRef<Html5Qrcode | null>(null);

  const weekStart = startOfWeek(currentDate, { weekStartsOn: 1 });
  const weekEnd = endOfWeek(currentDate, { weekStartsOn: 1 });
  const days = eachDayOfInterval({ start: weekStart, end: weekEnd });

  useEffect(() => {
    fetchProviderCommission();
  }, []);

  useEffect(() => {
    fetchBookings();
  }, [currentDate]);

  async function fetchProviderCommission() {
    try {
      const provider = await api.myProvider();
      // Vérification robuste: accepte 0 comme valeur valide
      if (provider && typeof provider.vetCommissionDa === 'number') {
        setCommissionDa(provider.vetCommissionDa);
      }
    } catch (error) {
      console.error('Error fetching provider commission:', error);
    }
  }

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
  const handleComplete = async () => {
    if (!selectedBooking) return;
    setActionLoading(true);
    try {
      await api.providerSetStatus(selectedBooking.id, 'COMPLETED');
      await fetchBookings();
      setSelectedBooking(null);
    } catch (error) {
      console.error('Error completing:', error);
      alert('Erreur lors de la finalisation');
    } finally {
      setActionLoading(false);
    }
  };

  // Cancel booking
  const handleCancel = async () => {
    if (!selectedBooking) return;
    if (!confirm('Voulez-vous vraiment annuler ce rendez-vous ?')) return;

    setActionLoading(true);
    try {
      await api.providerSetStatus(selectedBooking.id, 'CANCELLED');
      await fetchBookings();
      setSelectedBooking(null);
    } catch (error) {
      console.error('Error cancelling:', error);
      alert("Erreur lors de l'annulation");
    } finally {
      setActionLoading(false);
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

    // Wait for DOM to render
    await new Promise((resolve) => setTimeout(resolve, 100));

    try {
      const scanner = new Html5Qrcode('qr-reader');
      scannerRef.current = scanner;

      await scanner.start(
        { facingMode: 'environment' },
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
        },
        handleQrCodeSuccess,
        () => {} // Ignore errors during scanning
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
    // Stop scanner first
    await stopQrScanner();

    // Parse QR code - it might contain petId or bookingId
    console.log('QR Code scanned:', decodedText);

    setQrLoading(true);
    try {
      // Try to extract pet ID from QR code URL or direct ID
      let petId = decodedText;

      // If it's a URL like "otha://pet/xxx" or contains petId parameter
      if (decodedText.includes('pet/')) {
        const match = decodedText.match(/pet\/([a-zA-Z0-9-]+)/);
        if (match) petId = match[1];
      } else if (decodedText.includes('petId=')) {
        const match = decodedText.match(/petId=([a-zA-Z0-9-]+)/);
        if (match) petId = match[1];
      }

      // Find active booking for this pet
      const booking = await api.getActiveBookingForPet(petId);
      if (booking) {
        // Confirm via QR scan
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
      <div className="space-y-6">
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

        {/* Week header */}
        <div className="text-center text-lg font-medium text-gray-900">
          {format(weekStart, 'd MMM', { locale: fr })} -{' '}
          {format(weekEnd, 'd MMM yyyy', { locale: fr })}
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
                            {format(parseISOAsLocal(booking.scheduledAt), 'HH:mm')}
                          </span>
                          <div className="flex items-center gap-1">
                            {booking.user?.isFirstBooking && (
                              <span className="bg-amber-100 text-amber-700 text-[10px] px-1.5 py-0.5 rounded-full flex items-center gap-0.5">
                                <span>★</span> Nouveau
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
                      {format(parseISOAsLocal(selectedBooking.scheduledAt), "EEEE d MMMM yyyy 'à' HH:mm", {
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
                    <div className="flex items-center gap-2">
                      <p className="font-medium">
                        {selectedBooking.user?.displayName || selectedBooking.user?.email || 'Client'}
                      </p>
                      {selectedBooking.user?.isFirstBooking && (
                        <span className="bg-amber-100 text-amber-700 text-xs px-2 py-0.5 rounded-full flex items-center gap-1">
                          <span>★</span> Nouveau client
                        </span>
                      )}
                    </div>
                    {/* Show phone only when CONFIRMED */}
                    {isConfirmed(selectedBooking.status) && selectedBooking.user?.phone && (
                      <a
                        href={`tel:${selectedBooking.user.phone}`}
                        className="text-sm text-primary-600 flex items-center gap-1"
                      >
                        <Phone size={12} />
                        {selectedBooking.user.phone}
                      </a>
                    )}
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

                {/* Price with commission */}
                {selectedBooking.service?.price != null && (
                  <div className="flex items-center space-x-3">
                    <div className="p-2 bg-emerald-100 rounded-lg">
                      <DollarSign size={20} className="text-emerald-600" />
                    </div>
                    <div>
                      <p className="text-sm text-gray-500">À payer</p>
                      <p className="font-medium">
                        {selectedBooking.service.price} + {commissionDa} = {selectedBooking.service.price + commissionDa} DA
                      </p>
                      <p className="text-xs text-gray-400">
                        (Service: {selectedBooking.service.price} DA + Commission: {commissionDa} DA)
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

            {/* Actions - matching Flutter logic */}
            <div className="flex flex-wrap gap-3 mt-6 pt-4 border-t border-gray-100">
              {/* PENDING → Show Confirmer */}
              {isPending(selectedBooking.status) && (
                <Button onClick={handleConfirm} isLoading={actionLoading}>
                  <Check size={16} className="mr-2" />
                  Confirmer
                </Button>
              )}

              {/* CONFIRMED → Show Terminer */}
              {isConfirmed(selectedBooking.status) && (
                <Button onClick={handleComplete} isLoading={actionLoading}>
                  <Check size={16} className="mr-2" />
                  Terminer
                </Button>
              )}

              {/* PENDING or CONFIRMED → Show OTP button */}
              {(isPending(selectedBooking.status) || isConfirmed(selectedBooking.status)) && (
                <Button variant="secondary" onClick={openOtpDialog}>
                  <KeyRound size={16} className="mr-2" />
                  OTP
                </Button>
              )}

              {/* PENDING or CONFIRMED → Show Annuler */}
              {canCancel(selectedBooking.status) && (
                <Button variant="danger" onClick={handleCancel} isLoading={actionLoading}>
                  <X size={16} className="mr-2" />
                  Annuler
                </Button>
              )}
            </div>
          </Card>
        )}

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
