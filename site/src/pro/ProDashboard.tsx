import { useEffect, useState, useMemo, useCallback, useRef } from 'react';
import { Link } from 'react-router-dom';
import {
  Calendar,
  Users,
  Stethoscope,
  Clock,
  AlertCircle,
  ChevronRight,
  CreditCard,
  Receipt,
  CheckCircle,
  AlertTriangle,
  TrendingUp,
  Settings,
  Bell,
  X,
  Play,
  User,
  MapPin,
} from 'lucide-react';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import { useAuthStore } from '../store/authStore';
import api from '../api/client';
import type { Booking } from '../types';
import { format, startOfMonth, endOfMonth, subMonths, startOfDay, endOfDay, isSameDay, addHours, setHours, setMinutes } from 'date-fns';
import { fr } from 'date-fns/locale';

// Commission fixe par RDV (doit matcher le backend et Flutter)
const COMMISSION_DA = 100;

// Polling interval for notifications (30 seconds)
const NOTIFICATION_POLL_INTERVAL = 30000;

// Types pour le système de ledger
interface ProLedger {
  ym: string;
  dueThis: number;
  collectedThis: number;
  netThis: number;
  arrears: number;
}

interface CompletedBooking {
  scheduledAt: string;
  serviceTitle: string;
  totalPriceDa: number;
}

interface TimeSlot {
  time: string;
  hour: number;
  booking: Booking | null;
  isAvailable: boolean;
}

interface NotificationData {
  id: string;
  type: 'new_booking' | 'booking_cancelled';
  booking: Booking;
  timestamp: Date;
}

// Helper pour parser les entiers
function asInt(v: unknown): number {
  if (typeof v === 'number') return Math.floor(v);
  if (typeof v === 'string') return parseInt(v, 10) || 0;
  return 0;
}

// Normaliser YYYY-MM
function canonYm(s: string): string {
  const t = s.replace('/', '-').trim();
  const m = t.match(/^(\d{4})-(\d{1,2})$/);
  if (!m) return t;
  const y = m[1];
  const mo = parseInt(m[2], 10);
  return `${y}-${mo.toString().padStart(2, '0')}`;
}

// Format DA
function formatDa(v: number): string {
  return `${new Intl.NumberFormat('fr-FR').format(v)} DA`;
}

// Notification Sound Hook using Web Audio API
function useNotificationSound() {
  const audioContextRef = useRef<AudioContext | null>(null);

  const playSound = useCallback(() => {
    try {
      // Create or reuse AudioContext
      if (!audioContextRef.current) {
        audioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
      }
      const ctx = audioContextRef.current;

      // Resume context if suspended (browser autoplay policy)
      if (ctx.state === 'suspended') {
        ctx.resume();
      }

      const now = ctx.currentTime;

      // Create oscillator for the "ding" sound
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gainNode = ctx.createGain();

      // Connect nodes
      osc1.connect(gainNode);
      osc2.connect(gainNode);
      gainNode.connect(ctx.destination);

      // Set frequencies for a pleasant bell-like sound
      osc1.frequency.setValueAtTime(830, now); // High note (G#5)
      osc2.frequency.setValueAtTime(1245, now); // Higher harmonic

      // Sine waves for smooth sound
      osc1.type = 'sine';
      osc2.type = 'sine';

      // Envelope - quick attack, medium decay
      gainNode.gain.setValueAtTime(0, now);
      gainNode.gain.linearRampToValueAtTime(0.3, now + 0.01); // Quick attack
      gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.8); // Decay

      // Play the sound
      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.8);
      osc2.stop(now + 0.8);

      // Second ding (slightly delayed)
      setTimeout(() => {
        if (!audioContextRef.current) return;
        const ctx2 = audioContextRef.current;
        const now2 = ctx2.currentTime;

        const osc3 = ctx2.createOscillator();
        const gainNode2 = ctx2.createGain();

        osc3.connect(gainNode2);
        gainNode2.connect(ctx2.destination);

        osc3.frequency.setValueAtTime(1046, now2); // C6
        osc3.type = 'sine';

        gainNode2.gain.setValueAtTime(0, now2);
        gainNode2.gain.linearRampToValueAtTime(0.25, now2 + 0.01);
        gainNode2.gain.exponentialRampToValueAtTime(0.01, now2 + 0.6);

        osc3.start(now2);
        osc3.stop(now2 + 0.6);
      }, 150);

    } catch (error) {
      // Web Audio API not supported or blocked
      console.log('Notification sound not available');
    }
  }, []);

  return playSound;
}

// Notification Popup Component
function NotificationPopup({
  notification,
  onClose,
}: {
  notification: NotificationData | null;
  onClose: () => void;
}) {
  useEffect(() => {
    if (notification) {
      const timer = setTimeout(onClose, 8000);
      return () => clearTimeout(timer);
    }
  }, [notification, onClose]);

  if (!notification) return null;

  const booking = notification.booking;
  const scheduledAt = new Date(booking.scheduledAt);

  return (
    <div className="fixed top-4 right-4 z-50 animate-slide-in">
      <div className="bg-white rounded-2xl shadow-2xl border border-gray-100 p-4 w-80 max-w-[calc(100vw-2rem)]">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 bg-gradient-to-br from-emerald-400 to-emerald-600 rounded-full flex items-center justify-center flex-shrink-0">
            <Bell className="text-white" size={20} />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between gap-2">
              <h4 className="font-semibold text-gray-900 text-sm">
                Nouveau rendez-vous !
              </h4>
              <button
                onClick={onClose}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X size={16} />
              </button>
            </div>
            <p className="text-gray-600 text-sm mt-1">
              {booking.service?.title || 'Consultation'}
            </p>
            <p className="text-emerald-600 font-medium text-sm mt-1">
              {format(scheduledAt, "EEEE d MMMM 'à' HH:mm", { locale: fr })}
            </p>
            <div className="flex items-center gap-2 mt-2">
              <Link
                to="/pro/agenda"
                className="flex-1 text-center bg-emerald-500 hover:bg-emerald-600 text-white px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
              >
                Confirmer
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function ProDashboard() {
  const { provider, user } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [todayBookings, setTodayBookings] = useState<Booking[]>([]);
  const [nextAppointment, setNextAppointment] = useState<Booking | null>(null);
  const [ledger, setLedger] = useState<ProLedger | null>(null);
  const [completedBookings, setCompletedBookings] = useState<CompletedBooking[]>([]);
  const [pendingValidations, setPendingValidations] = useState<number>(0);
  const [notification, setNotification] = useState<NotificationData | null>(null);
  const [knownBookingIds, setKnownBookingIds] = useState<Set<string>>(new Set());
  const playSound = useNotificationSound();

  // Stats
  const [stats, setStats] = useState({
    todayCount: 0,
    weekCount: 0,
    monthRevenue: 0,
    completedThisMonth: 0,
  });

  // Doctor name
  const doctorName = provider?.displayName ||
    [user?.firstName, user?.lastName].filter(Boolean).join(' ') ||
    'Docteur';

  // Generate time slots for today
  const timeSlots = useMemo((): TimeSlot[] => {
    const slots: TimeSlot[] = [];
    const today = new Date();

    // Generate slots from 8:00 to 18:00
    for (let hour = 8; hour <= 18; hour++) {
      const slotTime = setMinutes(setHours(today, hour), 0);
      const booking = todayBookings.find(b => {
        const bTime = new Date(b.scheduledAt);
        return bTime.getHours() === hour;
      });

      slots.push({
        time: format(slotTime, 'HH:mm'),
        hour,
        booking: booking || null,
        isAvailable: !booking,
      });
    }

    return slots;
  }, [todayBookings]);

  // Current hour for highlighting
  const currentHour = new Date().getHours();

  // Fetch data
  const fetchData = useCallback(async () => {
    try {
      const now = new Date();
      const ymNow = format(now, 'yyyy-MM');
      const curStart = startOfMonth(now);
      const todayStart = startOfDay(now);
      const todayEnd = endOfDay(now);

      // Fetch all data in parallel
      const [agendaResult, historyResult, pendingCount] = await Promise.all([
        api.providerAgenda(
          format(subMonths(now, 24), 'yyyy-MM-dd'),
          format(addHours(now, 24 * 30), 'yyyy-MM-dd')
        ).catch(() => []),
        api.myHistoryMonthly(24).catch(() => []),
        api.client.get('/bookings/pending-validations/count')
          .then(res => res.data?.data?.count || res.data?.count || 0)
          .catch(() => 0),
      ]);

      setPendingValidations(pendingCount);

      // Handle wrapped response
      const agenda: Booking[] = Array.isArray(agendaResult)
        ? agendaResult
        : (agendaResult as { data?: Booking[] })?.data || [];

      // Store known booking IDs for notification detection
      const currentIds = new Set(agenda.filter(b => b.id).map(b => b.id));
      setKnownBookingIds(currentIds);

      // Filter today's bookings
      const todayAppts = agenda.filter(b => {
        const bDate = new Date(b.scheduledAt);
        return bDate >= todayStart && bDate <= todayEnd;
      }).sort((a, b) => new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime());

      setTodayBookings(todayAppts);

      // Find next appointment (future, PENDING or CONFIRMED)
      const cutoff = new Date(now.getTime() - 60 * 60 * 1000);
      let next: Booking | null = null;
      let nextDate: Date | null = null;

      for (const b of agenda) {
        const iso = b.scheduledAt?.toString() || '';
        if (!iso) continue;
        const t = new Date(iso);
        const st = b.status?.toString() || '';
        if (st !== 'PENDING' && st !== 'CONFIRMED') continue;
        if (t < cutoff) continue;
        if (!nextDate || t < nextDate) {
          nextDate = t;
          next = b;
        }
      }
      setNextAppointment(next);

      // Calculate stats
      const weekStart = new Date(now);
      weekStart.setDate(weekStart.getDate() - weekStart.getDay());
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 7);

      const weekAppts = agenda.filter(b => {
        const d = new Date(b.scheduledAt);
        return d >= weekStart && d < weekEnd && (b.status === 'PENDING' || b.status === 'CONFIRMED');
      });

      const monthCompleted = agenda.filter(b => {
        const d = new Date(b.scheduledAt);
        return d >= curStart && b.status === 'COMPLETED';
      });

      const monthRevenue = monthCompleted.reduce((sum, b) => sum + asInt(b.service?.price || 0), 0);

      setStats({
        todayCount: todayAppts.filter(b => b.status === 'PENDING' || b.status === 'CONFIRMED').length,
        weekCount: weekAppts.length,
        monthRevenue,
        completedThisMonth: monthCompleted.length,
      });

      // Build ledger from history
      const hist = Array.isArray(historyResult) ? historyResult : [];
      const byMonth: Record<string, { month: string; dueDa: number; collectedDa: number }> = {};

      for (const raw of hist) {
        const ym = canonYm((raw as { month?: string }).month || '');
        if (ym.length !== 7) continue;

        let due = asInt((raw as { dueDa?: number }).dueDa);
        if (due === 0 && 'completed' in (raw as object)) {
          due = asInt((raw as { completed?: number }).completed) * COMMISSION_DA;
        }

        let coll = asInt(
          (raw as { collectedDa?: number }).collectedDa ||
          (raw as { collectedDaScheduled?: number }).collectedDaScheduled ||
          (raw as { collectedScheduledDa?: number }).collectedScheduledDa ||
          0
        );
        if (due > 0 && coll > due) coll = due;

        byMonth[ym] = { month: ym, dueDa: due, collectedDa: coll };
      }

      // Calculate aggregates
      let dueThis = 0, collThis = 0, arrears = 0;

      if (byMonth[ymNow]) {
        dueThis = byMonth[ymNow].dueDa;
        collThis = byMonth[ymNow].collectedDa;
        if (collThis > dueThis) collThis = dueThis;
      }

      for (const entry of Object.values(byMonth)) {
        if (entry.month.length !== 7) continue;
        const y = parseInt(entry.month.substring(0, 4), 10);
        const m = parseInt(entry.month.substring(5, 7), 10);
        const d = new Date(y, m - 1, 1);
        if (d < curStart) {
          const net = entry.dueDa - entry.collectedDa;
          if (net > 0) arrears += net;
        }
      }

      setLedger({
        ym: ymNow,
        dueThis,
        collectedThis: collThis,
        netThis: Math.max(0, dueThis - collThis),
        arrears,
      });

      // Get completed bookings for display
      const completed: CompletedBooking[] = agenda
        .filter(b => b.status === 'COMPLETED')
        .map(b => ({
          scheduledAt: b.scheduledAt?.toString() || '',
          serviceTitle: b.service?.title || 'Service',
          totalPriceDa: asInt(b.service?.price || b.service?.priceCents || 0),
        }))
        .sort((a, b) => new Date(b.scheduledAt).getTime() - new Date(a.scheduledAt).getTime());

      setCompletedBookings(completed);

    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  // Poll for new bookings (notifications)
  const checkForNewBookings = useCallback(async () => {
    try {
      const now = new Date();
      const result = await api.providerAgenda(
        format(now, 'yyyy-MM-dd'),
        format(addHours(now, 24 * 30), 'yyyy-MM-dd')
      ).catch(() => []);

      const agenda: Booking[] = Array.isArray(result)
        ? result
        : (result as { data?: Booking[] })?.data || [];

      // Check for new pending bookings
      for (const booking of agenda) {
        if (booking.id && booking.status === 'PENDING' && !knownBookingIds.has(booking.id)) {
          // New booking found!
          setNotification({
            id: booking.id,
            type: 'new_booking',
            booking,
            timestamp: new Date(),
          });
          playSound();

          // Update known IDs
          setKnownBookingIds(prev => new Set([...prev, booking.id]));
          break;
        }
      }
    } catch (error) {
      // Silently ignore polling errors
    }
  }, [knownBookingIds, playSound]);

  // Initial fetch
  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Set up polling for notifications
  useEffect(() => {
    const interval = setInterval(checkForNewBookings, NOTIFICATION_POLL_INTERVAL);
    return () => clearInterval(interval);
  }, [checkForNewBookings]);

  // Close notification handler
  const closeNotification = useCallback(() => {
    setNotification(null);
  }, []);

  // Check provider status
  if (provider?.status === 'PENDING') {
    return (
      <DashboardLayout>
        <div className="max-w-2xl mx-auto py-12 px-4">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 text-center">
            <div className="w-16 h-16 bg-amber-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <Clock size={32} className="text-amber-500" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Demande en cours</h2>
            <p className="text-gray-500 mb-6">
              Votre demande d'inscription est en cours d'examen.
            </p>
            <div className="bg-amber-50 rounded-xl p-4 text-left">
              <p className="text-sm text-amber-700">
                En attendant, assurez-vous que votre carte AVN est bien lisible.
              </p>
            </div>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  if (provider?.status === 'REJECTED') {
    return (
      <DashboardLayout>
        <div className="max-w-2xl mx-auto py-12 px-4">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 text-center">
            <div className="w-16 h-16 bg-red-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertCircle size={32} className="text-red-500" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Demande rejetée</h2>
            <p className="text-gray-500 mb-6">
              Veuillez vérifier vos documents et soumettre une nouvelle demande.
            </p>
            <Link
              to="/pro/settings"
              className="inline-flex items-center justify-center px-6 py-3 bg-gray-900 text-white rounded-xl hover:bg-gray-800 transition-colors font-medium"
            >
              Soumettre à nouveau
            </Link>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-10 w-10 border-2 border-gray-200 border-t-gray-900" />
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      {/* Notification Popup */}
      <NotificationPopup notification={notification} onClose={closeNotification} />

      {/* CSS for animation */}
      <style>{`
        @keyframes slide-in {
          from {
            transform: translateX(100%);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
        .animate-slide-in {
          animation: slide-in 0.3s ease-out;
        }
      `}</style>

      <div className="space-y-6 max-w-6xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <p className="text-gray-500 text-sm">Bonjour,</p>
            <h1 className="text-2xl font-bold text-gray-900">Dr {doctorName}</h1>
          </div>
          <Link
            to="/pro/settings"
            className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center hover:bg-gray-200 transition-colors"
          >
            <span className="text-xl font-semibold text-gray-700">
              {doctorName.charAt(0).toUpperCase()}
            </span>
          </Link>
        </div>

        {/* Pending Validations Alert */}
        {pendingValidations > 0 && (
          <div className="bg-gradient-to-r from-amber-500 to-orange-500 rounded-2xl p-4 flex items-center justify-between shadow-lg">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
                <Bell className="text-white" size={20} />
              </div>
              <div>
                <p className="text-white font-semibold">
                  {pendingValidations} rendez-vous en attente
                </p>
                <p className="text-white/80 text-sm">
                  Nécessite votre confirmation
                </p>
              </div>
            </div>
            <Link
              to="/pro/agenda"
              className="bg-white text-amber-600 px-4 py-2 rounded-xl font-medium hover:bg-amber-50 transition-colors"
            >
              Voir
            </Link>
          </div>
        )}

        {/* Stats Row */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={<Calendar size={20} />}
            label="Aujourd'hui"
            value={stats.todayCount.toString()}
            color="blue"
          />
          <StatCard
            icon={<Users size={20} />}
            label="Cette semaine"
            value={stats.weekCount.toString()}
            color="purple"
          />
          <StatCard
            icon={<CheckCircle size={20} />}
            label="Complétés ce mois"
            value={stats.completedThisMonth.toString()}
            color="green"
          />
          <StatCard
            icon={<TrendingUp size={20} />}
            label="Revenus du mois"
            value={formatDa(stats.monthRevenue)}
            color="emerald"
            small
          />
        </div>

        {/* Main Grid */}
        <div className="grid lg:grid-cols-3 gap-6">
          {/* Today's Schedule - Takes 2 columns */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
                <div>
                  <h2 className="font-semibold text-gray-900">Aujourd'hui</h2>
                  <p className="text-sm text-gray-500">
                    {format(new Date(), "EEEE d MMMM", { locale: fr }).replace(/^\w/, c => c.toUpperCase())}
                  </p>
                </div>
                <Link
                  to="/pro/agenda"
                  className="text-sm text-blue-600 hover:text-blue-700 font-medium flex items-center gap-1"
                >
                  Voir tout <ChevronRight size={16} />
                </Link>
              </div>

              <div className="p-4 max-h-[420px] overflow-y-auto">
                <div className="space-y-2">
                  {timeSlots.map((slot) => (
                    <TimeSlotRow
                      key={slot.hour}
                      slot={slot}
                      isNow={currentHour === slot.hour}
                    />
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Next Appointment */}
            {nextAppointment && (
              <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-5 shadow-lg">
                <p className="text-blue-100 text-sm mb-1">Prochain rendez-vous</p>
                <p className="text-white font-semibold text-lg mb-3">
                  {format(new Date(nextAppointment.scheduledAt), "EEEE d MMMM", { locale: fr })
                    .replace(/^\w/, c => c.toUpperCase())}
                </p>
                <div className="bg-white/10 rounded-xl p-3 backdrop-blur">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
                      <Clock className="text-white" size={20} />
                    </div>
                    <div>
                      <p className="text-white font-bold text-xl">
                        {format(new Date(nextAppointment.scheduledAt), "HH:mm")}
                      </p>
                      <p className="text-blue-100 text-sm">
                        {nextAppointment.service?.title || 'Consultation'}
                      </p>
                    </div>
                  </div>
                </div>
                <Link
                  to="/pro/agenda"
                  className="mt-4 w-full bg-white text-blue-600 py-2.5 rounded-xl font-medium hover:bg-blue-50 transition-colors flex items-center justify-center gap-2"
                >
                  <Calendar size={18} />
                  Voir l'agenda
                </Link>
              </div>
            )}

            {/* Commission Card */}
            {ledger && (
              <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="font-semibold text-gray-900">Commission</h3>
                  <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded-full">
                    {format(new Date(), 'MMMM', { locale: fr })}
                  </span>
                </div>

                <div className="text-center py-4">
                  <p className="text-sm text-gray-500 mb-1">À payer</p>
                  <p className="text-3xl font-bold text-gray-900">
                    {formatDa(ledger.netThis + ledger.arrears)}
                  </p>
                </div>

                <div className="grid grid-cols-2 gap-3 mb-4">
                  <div className="bg-gray-50 rounded-xl p-3 text-center">
                    <p className="text-xs text-gray-500">Générée</p>
                    <p className="font-semibold text-gray-900">{formatDa(ledger.dueThis)}</p>
                  </div>
                  <div className="bg-gray-50 rounded-xl p-3 text-center">
                    <p className="text-xs text-gray-500">Payée</p>
                    <p className="font-semibold text-gray-900">{formatDa(ledger.collectedThis)}</p>
                  </div>
                </div>

                {ledger.arrears > 0 && (
                  <div className="bg-red-50 rounded-xl p-3 flex items-center gap-2">
                    <AlertTriangle className="text-red-500 flex-shrink-0" size={18} />
                    <div>
                      <p className="text-xs text-red-600">Retard</p>
                      <p className="font-semibold text-red-700">{formatDa(ledger.arrears)}</p>
                    </div>
                  </div>
                )}

                <Link
                  to="/pro/earnings"
                  className="mt-4 w-full bg-gray-900 text-white py-2.5 rounded-xl font-medium hover:bg-gray-800 transition-colors flex items-center justify-center gap-2"
                >
                  <Receipt size={18} />
                  Voir les détails
                </Link>
              </div>
            )}
          </div>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <QuickAction
            icon={<Calendar size={22} />}
            title="Agenda"
            description="Gérer les RDV"
            link="/pro/agenda"
            color="blue"
          />
          <QuickAction
            icon={<Clock size={22} />}
            title="Disponibilités"
            description="Modifier les horaires"
            link="/pro/availability"
            color="purple"
          />
          <QuickAction
            icon={<Stethoscope size={22} />}
            title="Services"
            description="Tarifs & prestations"
            link="/pro/services"
            color="emerald"
          />
          <QuickAction
            icon={<Settings size={22} />}
            title="Paramètres"
            description="Mon profil"
            link="/pro/settings"
            color="gray"
          />
        </div>

        {/* Recent Activity */}
        {completedBookings.length > 0 && (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
              <h2 className="font-semibold text-gray-900">Activité récente</h2>
              <Link
                to="/pro/earnings"
                className="text-sm text-blue-600 hover:text-blue-700 font-medium"
              >
                Tout voir
              </Link>
            </div>
            <div className="divide-y divide-gray-50">
              {completedBookings.slice(0, 5).map((b, i) => (
                <div key={i} className="px-6 py-3 flex items-center gap-4">
                  <div className="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center flex-shrink-0">
                    <CheckCircle className="text-green-600" size={16} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {b.serviceTitle}
                    </p>
                    <p className="text-xs text-gray-500">
                      {format(new Date(b.scheduledAt), "d MMM 'à' HH:mm", { locale: fr })}
                    </p>
                  </div>
                  <p className="font-semibold text-gray-900 text-sm">
                    {formatDa(b.totalPriceDa)}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}

// Stat Card Component
function StatCard({
  icon,
  label,
  value,
  color,
  small = false,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  color: 'blue' | 'purple' | 'green' | 'emerald' | 'orange';
  small?: boolean;
}) {
  const colors = {
    blue: 'bg-blue-50 text-blue-600',
    purple: 'bg-purple-50 text-purple-600',
    green: 'bg-green-50 text-green-600',
    emerald: 'bg-emerald-50 text-emerald-600',
    orange: 'bg-orange-50 text-orange-600',
  };

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
      <div className={`w-10 h-10 rounded-xl ${colors[color]} flex items-center justify-center mb-3`}>
        {icon}
      </div>
      <p className={`font-bold text-gray-900 ${small ? 'text-lg' : 'text-2xl'}`}>{value}</p>
      <p className="text-gray-500 text-sm">{label}</p>
    </div>
  );
}

// Time Slot Row Component
function TimeSlotRow({ slot, isNow }: { slot: TimeSlot; isNow: boolean }) {
  return (
    <div
      className={`flex items-center gap-4 p-3 rounded-xl transition-colors ${
        isNow ? 'bg-blue-50 ring-2 ring-blue-200' : slot.booking ? 'bg-gray-50' : 'hover:bg-gray-50'
      }`}
    >
      <div className="w-14 flex-shrink-0">
        <p className={`font-semibold ${isNow ? 'text-blue-600' : 'text-gray-900'}`}>
          {slot.time}
        </p>
      </div>

      {slot.booking ? (
        <div className="flex-1 flex items-center gap-3">
          <div className={`w-1 h-10 rounded-full ${
            slot.booking.status === 'PENDING' ? 'bg-amber-500' :
            slot.booking.status === 'CONFIRMED' ? 'bg-blue-500' :
            'bg-green-500'
          }`} />
          <div className="flex-1 min-w-0">
            <p className="font-medium text-gray-900 truncate">
              {slot.booking.service?.title || 'Consultation'}
            </p>
            <div className="flex items-center gap-2 text-sm text-gray-500">
              <User size={14} />
              <span className="truncate">
                {slot.booking.user?.displayName || slot.booking.user?.email || 'Client'}
              </span>
            </div>
          </div>
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
            slot.booking.status === 'PENDING' ? 'bg-amber-100 text-amber-700' :
            slot.booking.status === 'CONFIRMED' ? 'bg-blue-100 text-blue-700' :
            'bg-green-100 text-green-700'
          }`}>
            {slot.booking.status === 'PENDING' ? 'En attente' :
             slot.booking.status === 'CONFIRMED' ? 'Confirmé' : 'Terminé'}
          </span>
        </div>
      ) : (
        <div className="flex-1 flex items-center gap-3">
          <div className="w-1 h-10 rounded-full bg-gray-200" />
          <p className="text-gray-400 text-sm">Disponible</p>
        </div>
      )}
    </div>
  );
}

// Quick Action Component
function QuickAction({
  icon,
  title,
  description,
  link,
  color,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  link: string;
  color: 'blue' | 'purple' | 'emerald' | 'gray';
}) {
  const colors = {
    blue: 'bg-blue-50 text-blue-600 group-hover:bg-blue-100',
    purple: 'bg-purple-50 text-purple-600 group-hover:bg-purple-100',
    emerald: 'bg-emerald-50 text-emerald-600 group-hover:bg-emerald-100',
    gray: 'bg-gray-100 text-gray-600 group-hover:bg-gray-200',
  };

  return (
    <Link to={link} className="group">
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4 hover:shadow-md transition-all">
        <div className={`w-11 h-11 rounded-xl ${colors[color]} flex items-center justify-center mb-3 transition-colors`}>
          {icon}
        </div>
        <p className="font-semibold text-gray-900">{title}</p>
        <p className="text-gray-500 text-sm">{description}</p>
      </div>
    </Link>
  );
}
