import { useEffect, useState, useCallback } from 'react';
import {
  Flag,
  AlertTriangle,
  CheckCircle,
  Clock,
  FileText,
  X,
  Check,
  Trash2,
  RefreshCw,
  ChevronRight,
  Plus,
  RotateCcw,
  Zap,
  UserX,
  Briefcase,
} from 'lucide-react';
import api from '../api/client';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

interface AdminFlag {
  id: string;
  userId: string;
  type: string;
  bookingId?: string;
  note?: string;
  createdAt: string;
  resolved: boolean;
  user?: {
    id: string;
    email: string;
    firstName?: string;
    lastName?: string;
    phone?: string;
    trustStatus?: string;
    role?: string;
  };
}

interface FlagStats {
  total: number;
  active: number;
  resolved: number;
  byType: { type: string; count: number }[];
  proFlags?: number;
  userFlags?: number;
  recentFlags?: number;
}

// Types de flags UTILISATEURS
const USER_FLAG_TYPES = [
  { value: 'NO_SHOW', label: 'No-show', color: 'bg-yellow-500', icon: UserX },
  { value: 'DAYCARE_DISPUTE', label: 'Litige Garderie', color: 'bg-orange-500', icon: AlertTriangle },
  { value: 'MULTIPLE_NO_SHOWS', label: 'No-shows multiples', color: 'bg-red-500', icon: UserX },
  { value: 'SUSPICIOUS_BOOKING_PATTERN', label: 'Pattern suspect', color: 'bg-purple-500', icon: AlertTriangle },
  { value: 'LATE_CANCELLATION', label: 'Annulations tardives', color: 'bg-amber-500', icon: Clock },
  { value: 'FRAUD', label: 'Fraude', color: 'bg-red-600', icon: AlertTriangle },
  { value: 'ABUSE', label: 'Abus', color: 'bg-pink-500', icon: AlertTriangle },
  { value: 'SUSPICIOUS_BEHAVIOR', label: 'Comportement suspect', color: 'bg-purple-500', icon: AlertTriangle },
  { value: 'OTHER', label: 'Autre', color: 'bg-gray-500', icon: Flag },
];

// Types de flags PROFESSIONNELS
const PRO_FLAG_TYPES = [
  { value: 'PRO_HIGH_CANCELLATION', label: 'Annulations pro élevées', color: 'bg-red-500', icon: Briefcase },
  { value: 'PRO_LOW_VERIFICATION', label: 'Faible vérification', color: 'bg-orange-500', icon: Briefcase },
  { value: 'PRO_GHOST_COMPLETIONS', label: 'RDV fantômes', color: 'bg-red-600', icon: Briefcase },
  { value: 'PRO_UNRESPONSIVE', label: 'Pro non-réactif', color: 'bg-yellow-500', icon: Briefcase },
  { value: 'PRO_LATE_CONFIRMATIONS', label: 'Confirmations tardives', color: 'bg-amber-500', icon: Briefcase },
  { value: 'PRO_LOW_COMPLETION', label: 'Faible complétion', color: 'bg-orange-600', icon: Briefcase },
  { value: 'PRO_SUSPICIOUS', label: 'Pro suspect', color: 'bg-purple-500', icon: Briefcase },
  { value: 'PRO_LATE_PAYMENT', label: 'Retard de paiement', color: 'bg-red-700', icon: Briefcase },
];

const ALL_FLAG_TYPES = [...USER_FLAG_TYPES, ...PRO_FLAG_TYPES];

function getTypeInfo(type: string) {
  return ALL_FLAG_TYPES.find((t) => t.value === type) || { value: type, label: type, color: 'bg-gray-500', icon: Flag };
}

export function AdminFlags() {
  const [flags, setFlags] = useState<AdminFlag[]>([]);
  const [stats, setStats] = useState<FlagStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedFlag, setSelectedFlag] = useState<AdminFlag | null>(null);
  const [filter, setFilter] = useState<'all' | 'active' | 'resolved'>('active');
  const [typeFilter, setTypeFilter] = useState<string>('');

  // Modal states
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showResolveModal, setShowResolveModal] = useState(false);
  const [resolveNote, setResolveNote] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  // Create flag form
  const [newFlag, setNewFlag] = useState({
    userId: '',
    type: 'FRAUD',
    bookingId: '',
    note: '',
  });

  // Analysis state
  const [analyzing, setAnalyzing] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<{
    pros: { analyzed: number; flagged: number; flags: string[] };
    users: { analyzed: number; flagged: number; flags: string[] };
    totalNewFlags: number;
  } | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [flagsData, statsData] = await Promise.all([
        api.adminGetFlags({
          resolved: filter === 'all' ? undefined : filter === 'resolved',
          type: typeFilter || undefined,
          limit: 100,
        }),
        api.adminGetFlagStats(),
      ]);
      setFlags(flagsData);
      setStats(statsData);
    } catch (error) {
      console.error('Error fetching flags:', error);
    } finally {
      setLoading(false);
    }
  }, [filter, typeFilter]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleResolve = async () => {
    if (!selectedFlag) return;
    setActionLoading(true);
    try {
      await api.adminResolveFlag(selectedFlag.id, resolveNote || undefined);
      setShowResolveModal(false);
      setResolveNote('');
      setSelectedFlag(null);
      fetchData();
    } catch (error) {
      console.error('Error resolving flag:', error);
    } finally {
      setActionLoading(false);
    }
  };

  const handleUnresolve = async (flag: AdminFlag) => {
    setActionLoading(true);
    try {
      await api.adminUnresolveFlag(flag.id);
      fetchData();
    } catch (error) {
      console.error('Error unresolving flag:', error);
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async (flag: AdminFlag) => {
    if (!confirm('Supprimer ce flag definitivement ?')) return;
    setActionLoading(true);
    try {
      await api.adminDeleteFlag(flag.id);
      if (selectedFlag?.id === flag.id) setSelectedFlag(null);
      fetchData();
    } catch (error) {
      console.error('Error deleting flag:', error);
    } finally {
      setActionLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!newFlag.userId.trim()) {
      alert('User ID requis');
      return;
    }
    setActionLoading(true);
    try {
      await api.adminCreateFlag({
        userId: newFlag.userId.trim(),
        type: newFlag.type,
        bookingId: newFlag.bookingId.trim() || undefined,
        note: newFlag.note.trim() || undefined,
      });
      setShowCreateModal(false);
      setNewFlag({ userId: '', type: 'FRAUD', bookingId: '', note: '' });
      fetchData();
    } catch (error) {
      console.error('Error creating flag:', error);
      alert('Erreur lors de la creation');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRunAnalysis = async () => {
    setAnalyzing(true);
    setAnalysisResult(null);
    try {
      const result = await api.adminRunFlagAnalysis();
      setAnalysisResult(result);
      if (result.totalNewFlags > 0) {
        fetchData(); // Refresh flags list if new ones were created
      }
    } catch (error) {
      console.error('Error running analysis:', error);
      alert('Erreur lors de l\'analyse');
    } finally {
      setAnalyzing(false);
    }
  };

  const getUserDisplayName = (flag: AdminFlag) => {
    if (!flag.user) return flag.userId.slice(0, 8) + '...';
    const { firstName, lastName, email } = flag.user;
    if (firstName || lastName) return `${firstName || ''} ${lastName || ''}`.trim();
    return email;
  };

  return (
    <div className="min-h-screen bg-zinc-900 text-zinc-100">
      {/* Header */}
      <div className="bg-zinc-800 border-b border-zinc-700 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Flag className="text-red-400" size={24} />
            <h1 className="text-xl font-bold">Signalements</h1>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={handleRunAnalysis}
              disabled={analyzing}
              className="flex items-center gap-2 px-4 py-2 rounded-lg bg-purple-600 hover:bg-purple-500 transition-colors font-medium disabled:opacity-50"
              title="Analyser les comportements suspects"
            >
              {analyzing ? (
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
              ) : (
                <Zap size={18} />
              )}
              Analyser
            </button>
            <button
              onClick={fetchData}
              className="p-2 rounded-lg bg-zinc-700 hover:bg-zinc-600 transition-colors"
              title="Rafraichir"
            >
              <RefreshCw size={18} />
            </button>
            <button
              onClick={() => setShowCreateModal(true)}
              className="flex items-center gap-2 px-4 py-2 rounded-lg bg-red-600 hover:bg-red-500 transition-colors font-medium"
            >
              <Plus size={18} />
              Nouveau Flag
            </button>
          </div>
        </div>

        {/* Analysis Result Banner */}
        {analysisResult && (
          <div className="mt-4 p-4 rounded-lg bg-purple-500/20 border border-purple-500/30">
            <div className="flex items-start justify-between">
              <div>
                <p className="font-medium text-purple-300">Analyse terminee</p>
                <p className="text-sm text-zinc-400 mt-1">
                  {analysisResult.totalNewFlags} nouveau(x) flag(s) cree(s)
                </p>
                <div className="mt-2 text-xs text-zinc-500 space-y-1">
                  <p>Pros analyses: {analysisResult.pros.analyzed} - {analysisResult.pros.flagged} flagges</p>
                  <p>Users analyses: {analysisResult.users.analyzed} - {analysisResult.users.flagged} flagges</p>
                </div>
                {analysisResult.totalNewFlags > 0 && (
                  <div className="mt-2 text-xs text-purple-400 space-y-0.5">
                    {[...analysisResult.pros.flags, ...analysisResult.users.flags].slice(0, 5).map((msg, i) => (
                      <p key={i}>• {msg}</p>
                    ))}
                    {[...analysisResult.pros.flags, ...analysisResult.users.flags].length > 5 && (
                      <p>...et {[...analysisResult.pros.flags, ...analysisResult.users.flags].length - 5} autres</p>
                    )}
                  </div>
                )}
              </div>
              <button
                onClick={() => setAnalysisResult(null)}
                className="p-1 rounded hover:bg-zinc-700"
              >
                <X size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      <div className="p-6">
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-zinc-800 rounded-xl p-4 border border-zinc-700">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-zinc-700">
                  <Flag size={20} className="text-zinc-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{stats.total}</p>
                  <p className="text-sm text-zinc-500">Total</p>
                </div>
              </div>
            </div>
            <div className="bg-zinc-800 rounded-xl p-4 border border-zinc-700">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-red-500/20">
                  <AlertTriangle size={20} className="text-red-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-red-400">{stats.active}</p>
                  <p className="text-sm text-zinc-500">Actifs</p>
                </div>
              </div>
            </div>
            <div className="bg-zinc-800 rounded-xl p-4 border border-zinc-700">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-green-500/20">
                  <CheckCircle size={20} className="text-green-400" />
                </div>
                <div>
                  <p className="text-2xl font-bold text-green-400">{stats.resolved}</p>
                  <p className="text-sm text-zinc-500">Resolus</p>
                </div>
              </div>
            </div>
            <div className="bg-zinc-800 rounded-xl p-4 border border-zinc-700">
              <div className="text-sm space-y-1">
                {stats.byType.slice(0, 3).map((t) => (
                  <div key={t.type} className="flex items-center justify-between">
                    <span className="text-zinc-400">{getTypeInfo(t.type).label}</span>
                    <span className="font-medium">{t.count}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap items-center gap-3 mb-6">
          <div className="flex items-center gap-1 bg-zinc-800 rounded-lg p-1">
            {(['active', 'resolved', 'all'] as const).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  filter === f
                    ? 'bg-zinc-600 text-white'
                    : 'text-zinc-400 hover:text-white'
                }`}
              >
                {f === 'active' ? 'Actifs' : f === 'resolved' ? 'Resolus' : 'Tous'}
              </button>
            ))}
          </div>
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
          >
            <option value="">Tous les types</option>
            <optgroup label="Utilisateurs">
              {USER_FLAG_TYPES.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </optgroup>
            <optgroup label="Professionnels">
              {PRO_FLAG_TYPES.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </optgroup>
          </select>
        </div>

        {/* Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Flags list */}
          <div className="lg:col-span-2 space-y-3">
            {loading ? (
              <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-red-500" />
              </div>
            ) : flags.length === 0 ? (
              <div className="bg-zinc-800 rounded-xl p-8 text-center border border-zinc-700">
                <Flag size={48} className="mx-auto text-zinc-600 mb-4" />
                <p className="text-zinc-400">Aucun flag trouve</p>
              </div>
            ) : (
              flags.map((flag) => {
                const typeInfo = getTypeInfo(flag.type);
                const isSelected = selectedFlag?.id === flag.id;
                return (
                  <div
                    key={flag.id}
                    onClick={() => setSelectedFlag(flag)}
                    className={`bg-zinc-800 rounded-xl p-4 border cursor-pointer transition-all ${
                      isSelected
                        ? 'border-red-500 ring-1 ring-red-500'
                        : 'border-zinc-700 hover:border-zinc-600'
                    }`}
                  >
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-3">
                        <div className={`w-2 h-2 rounded-full mt-2 ${typeInfo.color}`} />
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <span className="font-medium">{getUserDisplayName(flag)}</span>
                            <span className={`text-xs px-2 py-0.5 rounded ${typeInfo.color} bg-opacity-20`}>
                              {typeInfo.label}
                            </span>
                            {flag.resolved && (
                              <span className="text-xs px-2 py-0.5 rounded bg-green-500/20 text-green-400">
                                Resolu
                              </span>
                            )}
                          </div>
                          {flag.note && (
                            <p className="text-sm text-zinc-400 line-clamp-2">{flag.note}</p>
                          )}
                          <p className="text-xs text-zinc-500 mt-1">
                            {format(new Date(flag.createdAt), 'dd MMM yyyy HH:mm', { locale: fr })}
                          </p>
                        </div>
                      </div>
                      <ChevronRight size={18} className="text-zinc-500" />
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Detail panel */}
          <div className="lg:col-span-1">
            {selectedFlag ? (
              <div className="bg-zinc-800 rounded-xl border border-zinc-700 sticky top-6">
                <div className="p-4 border-b border-zinc-700">
                  <div className="flex items-center justify-between">
                    <h3 className="font-semibold">Details du Flag</h3>
                    <button
                      onClick={() => setSelectedFlag(null)}
                      className="p-1 rounded hover:bg-zinc-700"
                    >
                      <X size={18} />
                    </button>
                  </div>
                </div>
                <div className="p-4 space-y-4">
                  {/* Type */}
                  <div>
                    <p className="text-xs text-zinc-500 mb-1">Type</p>
                    <div className="flex items-center gap-2">
                      <div className={`w-3 h-3 rounded-full ${getTypeInfo(selectedFlag.type).color}`} />
                      <span className="font-medium">{getTypeInfo(selectedFlag.type).label}</span>
                    </div>
                  </div>

                  {/* User */}
                  <div>
                    <p className="text-xs text-zinc-500 mb-1">Utilisateur</p>
                    {selectedFlag.user ? (
                      <div className="bg-zinc-700/50 rounded-lg p-3">
                        <p className="font-medium">{getUserDisplayName(selectedFlag)}</p>
                        <p className="text-sm text-zinc-400">{selectedFlag.user.email}</p>
                        {selectedFlag.user.phone && (
                          <p className="text-sm text-zinc-400">{selectedFlag.user.phone}</p>
                        )}
                        {selectedFlag.user.trustStatus && (
                          <p className={`text-xs mt-2 ${
                            selectedFlag.user.trustStatus === 'RESTRICTED'
                              ? 'text-red-400'
                              : selectedFlag.user.trustStatus === 'VERIFIED'
                              ? 'text-green-400'
                              : 'text-blue-400'
                          }`}>
                            Trust: {selectedFlag.user.trustStatus}
                          </p>
                        )}
                      </div>
                    ) : (
                      <p className="text-zinc-400 font-mono text-sm">{selectedFlag.userId}</p>
                    )}
                  </div>

                  {/* Booking ID */}
                  {selectedFlag.bookingId && (
                    <div>
                      <p className="text-xs text-zinc-500 mb-1">Booking ID</p>
                      <p className="font-mono text-sm bg-zinc-700/50 px-2 py-1 rounded">
                        {selectedFlag.bookingId}
                      </p>
                    </div>
                  )}

                  {/* Note */}
                  {selectedFlag.note && (
                    <div>
                      <p className="text-xs text-zinc-500 mb-1">Note</p>
                      <p className="text-sm bg-zinc-700/50 p-3 rounded-lg">{selectedFlag.note}</p>
                    </div>
                  )}

                  {/* Date */}
                  <div>
                    <p className="text-xs text-zinc-500 mb-1">Date de creation</p>
                    <p className="text-sm">
                      {format(new Date(selectedFlag.createdAt), 'dd MMMM yyyy a HH:mm', { locale: fr })}
                    </p>
                  </div>

                  {/* Status */}
                  <div>
                    <p className="text-xs text-zinc-500 mb-1">Statut</p>
                    <div className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg ${
                      selectedFlag.resolved
                        ? 'bg-green-500/20 text-green-400'
                        : 'bg-red-500/20 text-red-400'
                    }`}>
                      {selectedFlag.resolved ? (
                        <>
                          <CheckCircle size={16} />
                          <span>Resolu</span>
                        </>
                      ) : (
                        <>
                          <Clock size={16} />
                          <span>Actif</span>
                        </>
                      )}
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="pt-4 border-t border-zinc-700 space-y-2">
                    {!selectedFlag.resolved ? (
                      <button
                        onClick={() => setShowResolveModal(true)}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-green-600 hover:bg-green-500 transition-colors font-medium"
                      >
                        <Check size={18} />
                        Marquer comme resolu
                      </button>
                    ) : (
                      <button
                        onClick={() => handleUnresolve(selectedFlag)}
                        disabled={actionLoading}
                        className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-orange-600 hover:bg-orange-500 transition-colors font-medium disabled:opacity-50"
                      >
                        <RotateCcw size={18} />
                        Reouvrir
                      </button>
                    )}
                    <button
                      onClick={() => handleDelete(selectedFlag)}
                      disabled={actionLoading}
                      className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-zinc-700 hover:bg-red-600 transition-colors font-medium disabled:opacity-50"
                    >
                      <Trash2 size={18} />
                      Supprimer
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-zinc-800 rounded-xl border border-zinc-700 p-8 text-center">
                <FileText size={48} className="mx-auto text-zinc-600 mb-4" />
                <p className="text-zinc-400">Selectionnez un flag pour voir les details</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="bg-zinc-800 rounded-xl border border-zinc-700 w-full max-w-md">
            <div className="p-4 border-b border-zinc-700 flex items-center justify-between">
              <h3 className="font-semibold">Nouveau Flag</h3>
              <button onClick={() => setShowCreateModal(false)} className="p-1 rounded hover:bg-zinc-700">
                <X size={18} />
              </button>
            </div>
            <div className="p-4 space-y-4">
              <div>
                <label className="block text-sm text-zinc-400 mb-1">User ID *</label>
                <input
                  type="text"
                  value={newFlag.userId}
                  onChange={(e) => setNewFlag({ ...newFlag, userId: e.target.value })}
                  placeholder="cxxxxxxxxxxxxxxx"
                  className="w-full bg-zinc-700 border border-zinc-600 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-red-500"
                />
              </div>
              <div>
                <label className="block text-sm text-zinc-400 mb-1">Type</label>
                <select
                  value={newFlag.type}
                  onChange={(e) => setNewFlag({ ...newFlag, type: e.target.value })}
                  className="w-full bg-zinc-700 border border-zinc-600 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-red-500"
                >
                  <optgroup label="Utilisateurs">
                    {USER_FLAG_TYPES.map((t) => (
                      <option key={t.value} value={t.value}>{t.label}</option>
                    ))}
                  </optgroup>
                  <optgroup label="Professionnels">
                    {PRO_FLAG_TYPES.map((t) => (
                      <option key={t.value} value={t.value}>{t.label}</option>
                    ))}
                  </optgroup>
                </select>
              </div>
              <div>
                <label className="block text-sm text-zinc-400 mb-1">Booking ID (optionnel)</label>
                <input
                  type="text"
                  value={newFlag.bookingId}
                  onChange={(e) => setNewFlag({ ...newFlag, bookingId: e.target.value })}
                  placeholder="cxxxxxxxxxxxxxxx"
                  className="w-full bg-zinc-700 border border-zinc-600 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-red-500"
                />
              </div>
              <div>
                <label className="block text-sm text-zinc-400 mb-1">Note (optionnel)</label>
                <textarea
                  value={newFlag.note}
                  onChange={(e) => setNewFlag({ ...newFlag, note: e.target.value })}
                  rows={3}
                  placeholder="Raison du flag..."
                  className="w-full bg-zinc-700 border border-zinc-600 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-red-500 resize-none"
                />
              </div>
            </div>
            <div className="p-4 border-t border-zinc-700 flex justify-end gap-3">
              <button
                onClick={() => setShowCreateModal(false)}
                className="px-4 py-2 rounded-lg bg-zinc-700 hover:bg-zinc-600 transition-colors"
              >
                Annuler
              </button>
              <button
                onClick={handleCreate}
                disabled={actionLoading}
                className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-500 transition-colors font-medium disabled:opacity-50"
              >
                {actionLoading ? 'Creation...' : 'Creer'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Resolve Modal */}
      {showResolveModal && selectedFlag && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="bg-zinc-800 rounded-xl border border-zinc-700 w-full max-w-md">
            <div className="p-4 border-b border-zinc-700 flex items-center justify-between">
              <h3 className="font-semibold">Resoudre le Flag</h3>
              <button onClick={() => setShowResolveModal(false)} className="p-1 rounded hover:bg-zinc-700">
                <X size={18} />
              </button>
            </div>
            <div className="p-4 space-y-4">
              <p className="text-zinc-400">
                Flag pour <span className="text-white font-medium">{getUserDisplayName(selectedFlag)}</span>
              </p>
              <div>
                <label className="block text-sm text-zinc-400 mb-1">Note de resolution (optionnel)</label>
                <textarea
                  value={resolveNote}
                  onChange={(e) => setResolveNote(e.target.value)}
                  rows={3}
                  placeholder="Comment le probleme a ete resolu..."
                  className="w-full bg-zinc-700 border border-zinc-600 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 resize-none"
                />
              </div>
            </div>
            <div className="p-4 border-t border-zinc-700 flex justify-end gap-3">
              <button
                onClick={() => setShowResolveModal(false)}
                className="px-4 py-2 rounded-lg bg-zinc-700 hover:bg-zinc-600 transition-colors"
              >
                Annuler
              </button>
              <button
                onClick={handleResolve}
                disabled={actionLoading}
                className="px-4 py-2 rounded-lg bg-green-600 hover:bg-green-500 transition-colors font-medium disabled:opacity-50"
              >
                {actionLoading ? 'Resolution...' : 'Resoudre'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
