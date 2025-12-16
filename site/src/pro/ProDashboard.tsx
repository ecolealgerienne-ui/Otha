import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  Calendar,
  Users,
  Stethoscope,
  Clock,
  AlertCircle,
  ChevronRight,
  QrCode,
  CreditCard,
  Receipt,
  CheckCircle,
  AlertTriangle,
  TrendingUp,
  Handshake,
  Settings,
} from 'lucide-react';
import { Card } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import { useAuthStore } from '../store/authStore';
import api from '../api/client';
import type { Booking } from '../types';
import { format, startOfMonth, endOfMonth, subMonths } from 'date-fns';
import { fr } from 'date-fns/locale';

// Commission fixe par RDV (doit matcher le backend et Flutter)
const COMMISSION_DA = 100;

// Types pour le système de ledger
interface ProLedger {
  ym: string; // 'YYYY-MM' courant
  dueThis: number;
  collectedThis: number;
  netThis: number;
  arrears: number; // retard cumulé (mois < courant)
}

interface CompletedBooking {
  scheduledAt: string;
  serviceTitle: string;
  totalPriceDa: number;
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

export function ProDashboard() {
  const { provider, user } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [nextAppointment, setNextAppointment] = useState<Booking | null>(null);
  const [ledger, setLedger] = useState<ProLedger | null>(null);
  const [completedBookings, setCompletedBookings] = useState<CompletedBooking[]>([]);
  const [pendingValidations, setPendingValidations] = useState<number>(0);
  const [scope, setScope] = useState<string>('ALL');

  // Generate months for selector
  const months = useMemo(() => {
    const now = new Date();
    return Array.from({ length: 24 }, (_, i) => {
      const d = subMonths(now, i);
      return format(d, 'yyyy-MM');
    });
  }, []);

  // Current month label
  const currentMonthLabel = useMemo(() => {
    const now = new Date();
    return format(now, 'MMMM yyyy', { locale: fr }).replace(/^\w/, c => c.toUpperCase());
  }, []);

  // Doctor name
  const doctorName = provider?.displayName ||
    [user?.firstName, user?.lastName].filter(Boolean).join(' ') ||
    'Docteur';

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      try {
        const now = new Date();
        const ymNow = format(now, 'yyyy-MM');
        const curStart = startOfMonth(now);

        // Fetch all data in parallel
        const [agendaResult, historyResult, pendingCount] = await Promise.all([
          api.providerAgenda(
            format(subMonths(now, 24), 'yyyy-MM-dd'),
            format(now, 'yyyy-MM-dd')
          ).catch(() => []),
          api.myHistoryMonthly(24).catch(() => []),
          // Try to get pending validations count
          api.client.get('/bookings/pending-validations/count')
            .then(res => res.data?.data?.count || res.data?.count || 0)
            .catch(() => 0),
        ]);

        setPendingValidations(pendingCount);

        // Handle wrapped response
        const agenda: Booking[] = Array.isArray(agendaResult)
          ? agendaResult
          : (agendaResult as { data?: Booking[] })?.data || [];

        // Find next appointment (future, PENDING or CONFIRMED)
        const cutoff = new Date(now.getTime() - 60 * 60 * 1000); // 1h ago
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

        // Try to get more accurate data for recent months
        const monthsToCheck = Object.values(byMonth)
          .filter(m => m.dueDa > 0 || m.collectedDa > 0)
          .map(m => m.month)
          .sort((a, b) => b.localeCompare(a))
          .slice(0, 6);

        for (const ym of monthsToCheck) {
          try {
            const e = await api.myEarnings(ym);
            if (e) {
              let coll = asInt(
                (e as { collectedDa?: number }).collectedDa ||
                (e as { collectedMonthDa?: number }).collectedMonthDa ||
                (e as { paidDa?: number }).paidDa ||
                (e as { totalCollectedDa?: number }).totalCollectedDa ||
                0
              );
              if (coll === 0) {
                const cents = asInt((e as { collectedCents?: number }).collectedCents || (e as { totalCollectedCents?: number }).totalCollectedCents);
                if (cents > 0) coll = Math.round(cents / 100);
              }
              if (coll < 0) coll = 0;

              const due = byMonth[ym]?.dueDa || 0;
              if (due > 0 && coll > due) coll = due;
              if (byMonth[ym]) byMonth[ym].collectedDa = coll;
            }
          } catch {
            // Silently ignore
          }
        }

        // Calculate aggregates
        let dueThis = 0, collThis = 0, arrears = 0;

        if (byMonth[ymNow]) {
          dueThis = byMonth[ymNow].dueDa;
          collThis = byMonth[ymNow].collectedDa;
          if (collThis > dueThis) collThis = dueThis;
        }

        // Calculate arrears (unpaid from previous months)
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
    }

    fetchData();
  }, []);

  // Filter completed bookings by scope
  const filteredBookings = useMemo(() => {
    if (scope === 'ALL') return completedBookings;

    const y = parseInt(scope.substring(0, 4), 10);
    const m = parseInt(scope.substring(5, 7), 10);
    const start = new Date(y, m - 1, 1);
    const end = new Date(y, m, 1);

    return completedBookings.filter(b => {
      const d = new Date(b.scheduledAt);
      return d >= start && d < end;
    });
  }, [completedBookings, scope]);

  // Calculate totals for filtered bookings
  const totalClient = filteredBookings.reduce((sum, b) => sum + b.totalPriceDa, 0);
  const totalCommission = filteredBookings.length * COMMISSION_DA;

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
              Votre demande d'inscription est en cours d'examen.
              Vous recevrez une notification dès qu'elle sera approuvée.
            </p>
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-left">
              <p className="text-sm text-yellow-800">
                En attendant, assurez-vous que votre carte AVN est bien lisible et que toutes vos informations sont correctes.
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
              Votre demande a été rejetée. Veuillez vérifier vos documents et soumettre une nouvelle demande.
            </p>
            <Link
              to="/pro/settings"
              className="inline-flex items-center justify-center px-6 py-3 bg-[#F36C6C] text-white rounded-lg hover:bg-[#e85c5c] transition-colors"
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
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#F36C6C]" />
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="space-y-6 max-w-6xl mx-auto">
        {/* Header Card */}
        <div className="bg-gradient-to-br from-[#F36C6C] to-[#FF9D9D] rounded-2xl p-6 shadow-lg">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Link to="/pro/settings" className="block">
                <div className="w-14 h-14 bg-white rounded-full flex items-center justify-center shadow-md hover:shadow-lg transition-shadow">
                  <span className="text-2xl font-bold text-[#F36C6C]">
                    {doctorName.charAt(0).toUpperCase()}
                  </span>
                </div>
              </Link>
              <div>
                <p className="text-white/80 text-sm">Bienvenue</p>
                <h1 className="text-white text-xl font-bold">Dr {doctorName}</h1>
              </div>
            </div>
            <Handshake className="text-white" size={28} />
          </div>
        </div>

        {/* Pending Validations Banner */}
        {pendingValidations > 0 && (
          <div className="bg-red-50 border border-red-200 rounded-xl p-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <AlertTriangle className="text-red-500" size={24} />
              <span className="font-semibold text-red-700">
                ⚠️ {pendingValidations} rendez-vous {pendingValidations > 1 ? 'nécessitent' : 'nécessite'} votre validation
              </span>
            </div>
            <Link
              to="/pro/agenda"
              className="text-red-600 hover:text-red-700 font-medium text-sm"
            >
              Voir
            </Link>
          </div>
        )}

        {/* Next Appointment */}
        {nextAppointment && (
          <Card className="border-0 shadow-md">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-[#FFE7E7] rounded-xl flex items-center justify-center flex-shrink-0">
                <Calendar className="text-[#F36C6C]" size={24} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-gray-600 text-sm">
                  {format(new Date(nextAppointment.scheduledAt), "EEEE d MMMM • HH:mm", { locale: fr })
                    .replace(/^\w/, c => c.toUpperCase())}
                </p>
                <p className="font-medium text-gray-900 truncate">
                  {nextAppointment.service?.title || 'Consultation'} • {nextAppointment.user?.displayName || nextAppointment.user?.email || 'Client'}
                </p>
              </div>
              <Link
                to="/pro/agenda"
                className="flex items-center gap-1 bg-[#F36C6C] hover:bg-[#e85c5c] text-white px-4 py-2 rounded-lg font-medium transition-colors"
              >
                Voir <ChevronRight size={18} />
              </Link>
            </div>
          </Card>
        )}

        {/* Action Grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <ActionCard
            icon={<Calendar size={24} />}
            title="Agenda"
            link="/pro/agenda"
            color="#1F7A8C"
          />
          <ActionCard
            icon={<Clock size={24} />}
            title="Disponibilités"
            link="/pro/availability"
            color="#7B2CBF"
          />
          <ActionCard
            icon={<Stethoscope size={24} />}
            title="Services & Tarifs"
            link="/pro/services"
            color="#3A86FF"
          />
          <ActionCard
            icon={<QrCode size={24} />}
            title="Scanner patient"
            link="/pro/patients"
            color="#FF6D00"
          />
        </div>

        {/* Commission Due Card */}
        {ledger && (
          <Card className="border-0 shadow-md">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center">
                  <CreditCard className="text-orange-500" size={24} />
                </div>
                <div>
                  <h3 className="font-bold text-gray-900">À payer (fin du mois)</h3>
                  <p className="text-gray-500 text-sm">{currentMonthLabel}</p>
                </div>
              </div>
              <button
                onClick={() => alert('Fonctionnalité de paiement à venir')}
                className="flex items-center gap-2 bg-[#F36C6C] hover:bg-[#e85c5c] text-white px-4 py-2 rounded-lg font-medium transition-colors"
              >
                <CreditCard size={18} />
                Payer
              </button>
            </div>

            {/* Main Amount */}
            <p className="text-3xl font-black text-gray-900 mb-4">
              {formatDa(ledger.netThis + ledger.arrears)}
            </p>

            {/* Generated / Paid pills */}
            <div className="flex flex-wrap gap-3 mb-4">
              <div className="flex items-center gap-2 bg-white border border-[#FFE7E7] rounded-xl px-4 py-2 min-w-[140px]">
                <Receipt className="text-[#F36C6C]" size={18} />
                <span className="text-gray-600 text-sm">Générées</span>
                <span className="font-bold ml-auto">{formatDa(ledger.dueThis)}</span>
              </div>
              <div className="flex items-center gap-2 bg-white border border-[#FFE7E7] rounded-xl px-4 py-2 min-w-[140px]">
                <CheckCircle className="text-[#F36C6C]" size={18} />
                <span className="text-gray-600 text-sm">Payé</span>
                <span className="font-bold ml-auto">{formatDa(ledger.collectedThis)}</span>
              </div>
            </div>

            {/* Arrears Warning */}
            {ledger.arrears > 0 && (
              <div className="bg-[#FFE7E7] border border-[#F36C6C]/30 rounded-xl p-3 flex items-center gap-3">
                <AlertTriangle className="text-[#F36C6C]" size={20} />
                <span className="font-semibold text-gray-800">
                  Retard cumulé: {formatDa(ledger.arrears)}
                </span>
              </div>
            )}
          </Card>
        )}

        {/* Period Selector */}
        <Card className="border-0 shadow-md">
          <div className="flex items-center gap-4">
            <span className="font-bold text-gray-900">Période</span>
            <select
              value={scope}
              onChange={(e) => setScope(e.target.value)}
              className="border border-gray-200 rounded-lg px-3 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-[#F36C6C]/50"
            >
              <option value="ALL">Tout le temps</option>
              {months.map((m) => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          </div>
        </Card>

        {/* Generated with Bookings */}
        <Card className="border-0 shadow-md">
          <h3 className="font-bold text-gray-900 mb-4">
            Générées avec ses rendez-vous — {scope === 'ALL' ? 'Tout le temps' : scope}
          </h3>

          {filteredBookings.length === 0 ? (
            <div className="flex items-center gap-3 text-gray-500 py-4">
              <Calendar size={24} />
              <span>Aucun rendez-vous complété</span>
            </div>
          ) : (
            <>
              <div className="space-y-3 max-h-96 overflow-y-auto">
                {filteredBookings.slice(0, 20).map((b, i) => (
                  <div key={i} className="flex items-center gap-3">
                    <CheckCircle className="text-green-500 flex-shrink-0" size={20} />
                    <span className="flex-1 text-gray-700 truncate">
                      {b.scheduledAt ? format(new Date(b.scheduledAt), 'dd/MM • HH:mm') : ''} — {b.serviceTitle}
                    </span>
                    <span className="font-medium text-gray-900 whitespace-nowrap">
                      {formatDa(b.totalPriceDa)}
                    </span>
                  </div>
                ))}
                {filteredBookings.length > 20 && (
                  <p className="text-gray-500 text-sm">
                    +{filteredBookings.length - 20} autres...
                  </p>
                )}
              </div>

              {/* Totals (only for specific month) */}
              {scope !== 'ALL' && (
                <>
                  <hr className="my-4 border-gray-100" />
                  <div className="grid grid-cols-2 gap-3">
                    <div className="flex items-center gap-2 bg-white border border-[#FFE7E7] rounded-xl px-4 py-3">
                      <CreditCard className="text-[#F36C6C]" size={18} />
                      <div className="flex-1 min-w-0">
                        <p className="text-gray-600 text-xs">Total client</p>
                        <p className="font-bold text-gray-900">{formatDa(totalClient)}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2 bg-white border border-[#FFE7E7] rounded-xl px-4 py-3">
                      <Receipt className="text-[#F36C6C]" size={18} />
                      <div className="flex-1 min-w-0">
                        <p className="text-gray-600 text-xs">Commission (due)</p>
                        <p className="font-bold text-gray-900">{formatDa(totalCommission)}</p>
                      </div>
                    </div>
                  </div>
                </>
              )}
            </>
          )}
        </Card>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Link to="/pro/services">
            <Card className="hover:shadow-lg transition-shadow border-0 shadow-md h-full">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-[#FFE7E7] rounded-xl">
                  <Stethoscope size={24} className="text-[#F36C6C]" />
                </div>
                <div>
                  <p className="font-semibold text-gray-900">Gérer mes services</p>
                  <p className="text-sm text-gray-500">Ajouter ou modifier vos prestations</p>
                </div>
              </div>
            </Card>
          </Link>

          <Link to="/pro/earnings">
            <Card className="hover:shadow-lg transition-shadow border-0 shadow-md h-full">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-green-100 rounded-xl">
                  <TrendingUp size={24} className="text-green-600" />
                </div>
                <div>
                  <p className="font-semibold text-gray-900">Mes gains</p>
                  <p className="text-sm text-gray-500">Voir l'historique détaillé</p>
                </div>
              </div>
            </Card>
          </Link>

          <Link to="/pro/settings">
            <Card className="hover:shadow-lg transition-shadow border-0 shadow-md h-full">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-purple-100 rounded-xl">
                  <Settings size={24} className="text-purple-600" />
                </div>
                <div>
                  <p className="font-semibold text-gray-900">Mon profil</p>
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

// Action Card Component
function ActionCard({ icon, title, link, color }: { icon: React.ReactNode; title: string; link: string; color: string }) {
  return (
    <Link to={link}>
      <div
        className="rounded-2xl p-4 h-full transition-all hover:scale-[1.02] hover:shadow-md"
        style={{
          backgroundColor: `${color}10`,
          border: `1px solid ${color}25`,
        }}
      >
        <div
          className="w-10 h-10 rounded-full flex items-center justify-center mb-3"
          style={{ backgroundColor: `${color}20` }}
        >
          <span style={{ color }}>{icon}</span>
        </div>
        <p className="font-bold text-gray-900 text-sm">{title}</p>
      </div>
    </Link>
  );
}
