import { useEffect, useState, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  TrendingUp,
  Calendar,
  ArrowUp,
  ArrowDown,
  Receipt,
  CreditCard,
  CheckCircle,
  Clock,
  AlertTriangle,
  ChevronLeft,
  Wallet,
  PiggyBank,
  BarChart3,
} from 'lucide-react';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { MonthlyEarnings, Booking } from '../types';
import { format, subMonths, startOfMonth } from 'date-fns';
import { fr } from 'date-fns/locale';

// Commission fixe par RDV (doit matcher le backend et Flutter)
const COMMISSION_DA = 100;

// Format DA
function formatDa(v: number): string {
  return `${new Intl.NumberFormat('fr-FR').format(v)} DA`;
}

// Parse naive local time
function parseNaiveLocal(isoString: string): Date {
  const cleaned = isoString.replace('Z', '').replace(/[+-]\d{2}:\d{2}$/, '');
  const [datePart, timePart] = cleaned.split('T');
  const [year, month, day] = datePart.split('-').map(Number);
  const [hour, minute, second] = (timePart || '00:00:00').split(':').map(n => parseInt(n) || 0);
  return new Date(year, month - 1, day, hour, minute, second);
}

interface LedgerEntry {
  month: string;
  due: number;
  collected: number;
  net: number;
  bookingCount: number;
}

export function ProEarnings() {
  const [loading, setLoading] = useState(true);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [ledger, setLedger] = useState<LedgerEntry[]>([]);
  const [selectedMonth, setSelectedMonth] = useState<string | null>(null);

  useEffect(() => {
    fetchData();
  }, []);

  async function fetchData() {
    setLoading(true);
    try {
      const now = new Date();

      // Fetch bookings and history in parallel
      const [agendaResult, historyResult] = await Promise.all([
        api.providerAgenda(
          format(subMonths(now, 24), 'yyyy-MM-dd'),
          format(now, 'yyyy-MM-dd')
        ).catch(() => []),
        api.myHistoryMonthly(24).catch(() => []),
      ]);

      // Handle wrapped response
      const agenda: Booking[] = Array.isArray(agendaResult)
        ? agendaResult
        : (agendaResult as { data?: Booking[] })?.data || [];

      setBookings(agenda);

      // Build ledger from history
      const hist = Array.isArray(historyResult) ? historyResult : [];
      const entries: LedgerEntry[] = hist.map((h: MonthlyEarnings) => {
        const due = h.totalCommission || (h.bookingCount * COMMISSION_DA);
        const collected = h.collected ? due : 0;
        return {
          month: h.month,
          due,
          collected,
          net: due - collected,
          bookingCount: h.bookingCount || 0,
        };
      });

      // If no history, build from bookings
      if (entries.length === 0 && agenda.length > 0) {
        const byMonth: Record<string, { count: number; completed: number }> = {};
        for (const b of agenda) {
          if (b.status !== 'COMPLETED') continue;
          const d = parseNaiveLocal(b.scheduledAt);
          const ym = format(d, 'yyyy-MM');
          if (!byMonth[ym]) byMonth[ym] = { count: 0, completed: 0 };
          byMonth[ym].count++;
          byMonth[ym].completed++;
        }

        for (const [month, data] of Object.entries(byMonth)) {
          entries.push({
            month,
            due: data.completed * COMMISSION_DA,
            collected: 0,
            net: data.completed * COMMISSION_DA,
            bookingCount: data.count,
          });
        }
      }

      // Sort by month descending
      entries.sort((a, b) => b.month.localeCompare(a.month));
      setLedger(entries);

    } catch (error) {
      console.error('Error fetching earnings:', error);
    } finally {
      setLoading(false);
    }
  }

  // Calculate totals
  const totals = useMemo(() => {
    const totalDue = ledger.reduce((sum, e) => sum + e.due, 0);
    const totalCollected = ledger.reduce((sum, e) => sum + e.collected, 0);
    const totalBookings = ledger.reduce((sum, e) => sum + e.bookingCount, 0);
    const currentMonth = ledger[0];
    const previousMonth = ledger[1];

    const percentChange = previousMonth && previousMonth.due > 0
      ? ((currentMonth?.due || 0) - previousMonth.due) / previousMonth.due * 100
      : 0;

    // Calculate arrears (unpaid from previous months)
    const now = new Date();
    const currentYm = format(now, 'yyyy-MM');
    const arrears = ledger
      .filter(e => e.month < currentYm && e.net > 0)
      .reduce((sum, e) => sum + e.net, 0);

    return {
      totalDue,
      totalCollected,
      totalNet: totalDue - totalCollected,
      totalBookings,
      currentMonth,
      previousMonth,
      percentChange,
      arrears,
    };
  }, [ledger]);

  // Get bookings for selected month
  const monthBookings = useMemo(() => {
    if (!selectedMonth) return [];
    return bookings
      .filter(b => {
        const d = parseNaiveLocal(b.scheduledAt);
        return format(d, 'yyyy-MM') === selectedMonth && b.status === 'COMPLETED';
      })
      .sort((a, b) => parseNaiveLocal(b.scheduledAt).getTime() - parseNaiveLocal(a.scheduledAt).getTime());
  }, [bookings, selectedMonth]);

  // Calculate revenue for selected month
  const monthRevenue = useMemo(() => {
    return monthBookings.reduce((sum, b) => sum + (b.service?.price || 0), 0);
  }, [monthBookings]);

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-10 w-10 border-2 border-gray-200 border-t-gray-900" />
        </div>
      </DashboardLayout>
    );
  }

  // Detail view for a month
  if (selectedMonth) {
    const entry = ledger.find(e => e.month === selectedMonth);
    const monthDate = new Date(selectedMonth + '-01');

    return (
      <DashboardLayout>
        <div className="space-y-6 max-w-4xl mx-auto">
          {/* Header */}
          <div className="flex items-center gap-4">
            <button
              onClick={() => setSelectedMonth(null)}
              className="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center hover:bg-gray-200 transition-colors"
            >
              <ChevronLeft size={20} className="text-gray-600" />
            </button>
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                {format(monthDate, 'MMMM yyyy', { locale: fr }).replace(/^\w/, c => c.toUpperCase())}
              </h1>
              <p className="text-gray-500 text-sm">Détail des gains</p>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              icon={<Calendar size={20} />}
              label="Consultations"
              value={entry?.bookingCount?.toString() || '0'}
              color="blue"
            />
            <StatCard
              icon={<Wallet size={20} />}
              label="Revenus clients"
              value={formatDa(monthRevenue)}
              color="green"
              small
            />
            <StatCard
              icon={<Receipt size={20} />}
              label="Commission due"
              value={formatDa(entry?.due || 0)}
              color="orange"
              small
            />
            <StatCard
              icon={<CheckCircle size={20} />}
              label="Commission payée"
              value={formatDa(entry?.collected || 0)}
              color="emerald"
              small
            />
          </div>

          {/* Bookings list */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100">
              <h2 className="font-semibold text-gray-900">Consultations terminées</h2>
            </div>

            {monthBookings.length === 0 ? (
              <div className="p-8 text-center">
                <Calendar size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Aucune consultation terminée ce mois</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-50">
                {monthBookings.map((b) => (
                  <div key={b.id} className="px-6 py-4 flex items-center gap-4">
                    <div className="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <CheckCircle className="text-green-600" size={20} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900 truncate">
                        {b.service?.title || 'Consultation'}
                      </p>
                      <p className="text-sm text-gray-500">
                        {format(parseNaiveLocal(b.scheduledAt), "EEEE d MMMM 'à' HH:mm", { locale: fr })}
                      </p>
                      <p className="text-xs text-gray-400 mt-1">
                        {b.user?.displayName || b.user?.email || 'Client'}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold text-gray-900">{formatDa(b.service?.price || 0)}</p>
                      <p className="text-xs text-orange-600">-{formatDa(COMMISSION_DA)}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Commission info */}
          <div className="bg-orange-50 rounded-2xl p-4 flex items-start gap-3">
            <Receipt className="text-orange-500 mt-0.5" size={20} />
            <div>
              <p className="font-medium text-orange-900">Commission Vegece</p>
              <p className="text-sm text-orange-700 mt-1">
                Une commission de {formatDa(COMMISSION_DA)} est prélevée par consultation terminée.
                Payable en fin de mois.
              </p>
            </div>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  // Main view
  return (
    <DashboardLayout>
      <div className="space-y-6 max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Mes Gains</h1>
            <p className="text-gray-500 text-sm">Suivez vos revenus et commissions</p>
          </div>
          <Link
            to="/pro"
            className="text-sm text-blue-600 hover:text-blue-700 font-medium flex items-center gap-1"
          >
            <ChevronLeft size={16} />
            Retour
          </Link>
        </div>

        {/* Main Stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <div className="flex items-center justify-between mb-3">
              <div className="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center">
                <BarChart3 size={20} className="text-blue-600" />
              </div>
              {totals.percentChange !== 0 && (
                <span className={`text-xs font-medium flex items-center gap-1 ${
                  totals.percentChange >= 0 ? 'text-green-600' : 'text-red-600'
                }`}>
                  {totals.percentChange >= 0 ? <ArrowUp size={14} /> : <ArrowDown size={14} />}
                  {Math.abs(totals.percentChange).toFixed(0)}%
                </span>
              )}
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {formatDa(totals.currentMonth?.due || 0)}
            </p>
            <p className="text-gray-500 text-sm">Ce mois</p>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <div className="w-10 h-10 bg-purple-50 rounded-xl flex items-center justify-center mb-3">
              <Calendar size={20} className="text-purple-600" />
            </div>
            <p className="text-2xl font-bold text-gray-900">{totals.totalBookings}</p>
            <p className="text-gray-500 text-sm">Total consultations</p>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <div className="w-10 h-10 bg-green-50 rounded-xl flex items-center justify-center mb-3">
              <PiggyBank size={20} className="text-green-600" />
            </div>
            <p className="text-2xl font-bold text-gray-900">{formatDa(totals.totalCollected)}</p>
            <p className="text-gray-500 text-sm">Commission payée</p>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <div className="w-10 h-10 bg-orange-50 rounded-xl flex items-center justify-center mb-3">
              <Receipt size={20} className="text-orange-600" />
            </div>
            <p className="text-2xl font-bold text-gray-900">{formatDa(totals.totalNet)}</p>
            <p className="text-gray-500 text-sm">À payer</p>
          </div>
        </div>

        {/* Arrears warning */}
        {totals.arrears > 0 && (
          <div className="bg-red-50 rounded-2xl p-4 flex items-start gap-3">
            <AlertTriangle className="text-red-500 mt-0.5" size={20} />
            <div>
              <p className="font-medium text-red-900">Retard de paiement</p>
              <p className="text-sm text-red-700 mt-1">
                Vous avez {formatDa(totals.arrears)} de commission impayée des mois précédents.
              </p>
            </div>
          </div>
        )}

        {/* Monthly History */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900">Historique mensuel</h2>
          </div>

          {ledger.length === 0 ? (
            <div className="p-8 text-center">
              <TrendingUp size={48} className="text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500">Aucun historique de gains</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-50">
              {ledger.map((entry, index) => {
                const monthDate = new Date(entry.month + '-01');
                const isCurrentMonth = index === 0;
                const isPaid = entry.collected >= entry.due;

                return (
                  <button
                    key={entry.month}
                    onClick={() => setSelectedMonth(entry.month)}
                    className={`w-full px-6 py-4 flex items-center gap-4 hover:bg-gray-50 transition-colors text-left ${
                      isCurrentMonth ? 'bg-blue-50 hover:bg-blue-100' : ''
                    }`}
                  >
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                      isPaid ? 'bg-green-100' : isCurrentMonth ? 'bg-blue-100' : 'bg-orange-100'
                    }`}>
                      {isPaid ? (
                        <CheckCircle size={20} className="text-green-600" />
                      ) : isCurrentMonth ? (
                        <Clock size={20} className="text-blue-600" />
                      ) : (
                        <AlertTriangle size={20} className="text-orange-600" />
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900">
                        {format(monthDate, 'MMMM yyyy', { locale: fr }).replace(/^\w/, c => c.toUpperCase())}
                        {isCurrentMonth && (
                          <span className="ml-2 text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full">
                            En cours
                          </span>
                        )}
                      </p>
                      <p className="text-sm text-gray-500">
                        {entry.bookingCount} consultation{entry.bookingCount > 1 ? 's' : ''}
                      </p>
                    </div>

                    <div className="text-right">
                      <p className="font-semibold text-gray-900">{formatDa(entry.due)}</p>
                      <p className={`text-xs ${isPaid ? 'text-green-600' : 'text-orange-600'}`}>
                        {isPaid ? 'Payé' : `À payer: ${formatDa(entry.net)}`}
                      </p>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Commission info */}
        <div className="bg-gray-50 rounded-2xl p-4 flex items-start gap-3">
          <CreditCard className="text-gray-500 mt-0.5" size={20} />
          <div>
            <p className="font-medium text-gray-900">À propos des commissions</p>
            <p className="text-sm text-gray-600 mt-1">
              Une commission de {formatDa(COMMISSION_DA)} est prélevée pour chaque consultation terminée.
              Les paiements sont dus en fin de mois.
            </p>
          </div>
        </div>
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
