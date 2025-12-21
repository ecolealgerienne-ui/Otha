import { useEffect, useState, useCallback, useRef } from 'react';
import {
  MessageSquare,
  AlertTriangle,
  CheckCircle,
  Clock,
  User,
  X,
  Send,
  RefreshCw,
  ChevronRight,
  Filter,
  Inbox,
  AlertCircle,
  MessageCircle,
  Bug,
  Lightbulb,
  HelpCircle,
  ArrowUp,
  ArrowDown,
  Minus,
  Shield,
} from 'lucide-react';
import api from '../api/client';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';

interface SupportTicket {
  id: string;
  subject: string;
  category: string;
  status: string;
  priority: string;
  createdAt: string;
  updatedAt: string;
  user: {
    id: string;
    email: string;
    firstName?: string;
    lastName?: string;
    isBanned?: boolean;
    suspendedUntil?: string;
  };
  assignedTo?: {
    id: string;
    firstName?: string;
    lastName?: string;
  };
  messageCount: number;
  lastMessage?: {
    content: string;
    createdAt: string;
    isFromAdmin: boolean;
  };
}

interface TicketMessage {
  id: string;
  content: string;
  createdAt: string;
  isFromAdmin: boolean;
  readAt?: string;
  sender: {
    id: string;
    name: string;
  };
}

interface TicketDetail {
  id: string;
  subject: string;
  category: string;
  status: string;
  priority: string;
  createdAt: string;
  updatedAt: string;
  closedAt?: string;
  relatedSanction?: {
    id: string;
    type: string;
    reason: string;
    issuedAt: string;
  };
  user: {
    id: string;
    firstName?: string;
    lastName?: string;
    email: string;
  };
  messages: TicketMessage[];
}

interface SupportStats {
  byStatus: {
    open: number;
    inProgress: number;
    waitingUser: number;
    resolved: number;
    closed: number;
    activeTotal: number;
  };
  byCategory: Record<string, number>;
  byPriority: {
    urgent: number;
    high: number;
    normal: number;
    low: number;
  };
  recentActivity: number;
}

const CATEGORIES = [
  { value: 'GENERAL', label: 'Général', color: 'bg-blue-500', icon: HelpCircle },
  { value: 'APPEAL', label: 'Contestation', color: 'bg-red-500', icon: Shield },
  { value: 'BUG', label: 'Bug', color: 'bg-orange-500', icon: Bug },
  { value: 'FEATURE', label: 'Suggestion', color: 'bg-purple-500', icon: Lightbulb },
  { value: 'BILLING', label: 'Facturation', color: 'bg-green-500', icon: AlertCircle },
  { value: 'OTHER', label: 'Autre', color: 'bg-gray-500', icon: MessageCircle },
];

const STATUSES = [
  { value: 'OPEN', label: 'Nouveau', color: 'bg-blue-500' },
  { value: 'IN_PROGRESS', label: 'En cours', color: 'bg-yellow-500' },
  { value: 'WAITING_USER', label: 'Attente user', color: 'bg-purple-500' },
  { value: 'RESOLVED', label: 'Résolu', color: 'bg-green-500' },
  { value: 'CLOSED', label: 'Fermé', color: 'bg-gray-500' },
];

const PRIORITIES = [
  { value: 'URGENT', label: 'Urgent', color: 'text-red-600', icon: ArrowUp },
  { value: 'HIGH', label: 'Élevée', color: 'text-orange-500', icon: ArrowUp },
  { value: 'NORMAL', label: 'Normale', color: 'text-gray-500', icon: Minus },
  { value: 'LOW', label: 'Basse', color: 'text-blue-400', icon: ArrowDown },
];

function getCategoryInfo(category: string) {
  return CATEGORIES.find((c) => c.value === category) || CATEGORIES[5];
}

function getStatusInfo(status: string) {
  return STATUSES.find((s) => s.value === status) || STATUSES[0];
}

function getPriorityInfo(priority: string) {
  return PRIORITIES.find((p) => p.value === priority) || PRIORITIES[2];
}

export function AdminSupport() {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [stats, setStats] = useState<SupportStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedTicket, setSelectedTicket] = useState<TicketDetail | null>(null);
  const [showChatModal, setShowChatModal] = useState(false);

  // Filters
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [categoryFilter, setCategoryFilter] = useState<string>('');
  const [priorityFilter, setPriorityFilter] = useState<string>('');

  // Chat state
  const [newMessage, setNewMessage] = useState('');
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Polling for new messages
  const pollingRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const loadTickets = useCallback(async () => {
    try {
      const filters: any = {};
      if (statusFilter) filters.status = statusFilter;
      if (categoryFilter) filters.category = categoryFilter;
      if (priorityFilter) filters.priority = priorityFilter;

      const result = await api.adminGetSupportTickets(filters);
      setTickets(result.tickets || []);
    } catch (err) {
      console.error('Error loading tickets:', err);
    }
  }, [statusFilter, categoryFilter, priorityFilter]);

  const loadStats = useCallback(async () => {
    try {
      const result = await api.adminGetSupportStats();
      setStats(result);
    } catch (err) {
      console.error('Error loading stats:', err);
    }
  }, []);

  const loadAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([loadTickets(), loadStats()]);
    setLoading(false);
  }, [loadTickets, loadStats]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  // Reload tickets when filters change
  useEffect(() => {
    loadTickets();
  }, [statusFilter, categoryFilter, priorityFilter, loadTickets]);

  // Open ticket chat
  const openChat = async (ticketId: string) => {
    try {
      const detail = await api.adminGetSupportTicket(ticketId);
      setSelectedTicket(detail);
      setShowChatModal(true);

      // Start polling for new messages
      pollingRef.current = setInterval(async () => {
        try {
          const updated = await api.adminGetSupportTicket(ticketId);
          setSelectedTicket(updated);
        } catch (err) {
          console.error('Polling error:', err);
        }
      }, 5000);
    } catch (err) {
      console.error('Error loading ticket:', err);
    }
  };

  // Close chat modal
  const closeChat = () => {
    setShowChatModal(false);
    setSelectedTicket(null);
    setNewMessage('');
    if (pollingRef.current) {
      clearInterval(pollingRef.current);
      pollingRef.current = null;
    }
    loadAll(); // Refresh list
  };

  // Send message
  const sendMessage = async () => {
    if (!selectedTicket || !newMessage.trim()) return;

    setSending(true);
    try {
      await api.adminSendSupportMessage(selectedTicket.id, newMessage.trim());
      setNewMessage('');

      // Reload ticket
      const updated = await api.adminGetSupportTicket(selectedTicket.id);
      setSelectedTicket(updated);
    } catch (err) {
      console.error('Error sending message:', err);
    } finally {
      setSending(false);
    }
  };

  // Update ticket status
  const updateStatus = async (status: string) => {
    if (!selectedTicket) return;

    try {
      await api.adminUpdateTicketStatus(selectedTicket.id, status);
      const updated = await api.adminGetSupportTicket(selectedTicket.id);
      setSelectedTicket(updated);
      loadStats();
    } catch (err) {
      console.error('Error updating status:', err);
    }
  };

  // Update ticket priority
  const updatePriority = async (priority: string) => {
    if (!selectedTicket) return;

    try {
      await api.adminUpdateTicketPriority(selectedTicket.id, priority);
      const updated = await api.adminGetSupportTicket(selectedTicket.id);
      setSelectedTicket(updated);
    } catch (err) {
      console.error('Error updating priority:', err);
    }
  };

  // Assign ticket to self
  const assignToSelf = async () => {
    if (!selectedTicket) return;

    try {
      await api.adminAssignTicket(selectedTicket.id);
      const updated = await api.adminGetSupportTicket(selectedTicket.id);
      setSelectedTicket(updated);
    } catch (err) {
      console.error('Error assigning ticket:', err);
    }
  };

  // Scroll to bottom of messages
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [selectedTicket?.messages]);

  return (
    <DashboardLayout>
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Support</h1>
          <p className="text-gray-500">Gestion des tickets de support client</p>
        </div>
        <button
          onClick={loadAll}
          disabled={loading}
          className="flex items-center gap-2 px-4 py-2 bg-rose-400 text-white rounded-lg hover:bg-rose-500 transition disabled:opacity-50"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          Actualiser
        </button>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-2 text-blue-600 mb-1">
              <Inbox className="w-5 h-5" />
              <span className="text-sm font-medium">Nouveaux</span>
            </div>
            <p className="text-2xl font-bold">{stats.byStatus.open}</p>
          </div>

          <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-2 text-yellow-600 mb-1">
              <Clock className="w-5 h-5" />
              <span className="text-sm font-medium">En cours</span>
            </div>
            <p className="text-2xl font-bold">{stats.byStatus.inProgress}</p>
          </div>

          <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-2 text-purple-600 mb-1">
              <MessageSquare className="w-5 h-5" />
              <span className="text-sm font-medium">Attente</span>
            </div>
            <p className="text-2xl font-bold">{stats.byStatus.waitingUser}</p>
          </div>

          <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-2 text-green-600 mb-1">
              <CheckCircle className="w-5 h-5" />
              <span className="text-sm font-medium">Résolus</span>
            </div>
            <p className="text-2xl font-bold">{stats.byStatus.resolved}</p>
          </div>

          <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-2 text-red-600 mb-1">
              <AlertTriangle className="w-5 h-5" />
              <span className="text-sm font-medium">Urgents</span>
            </div>
            <p className="text-2xl font-bold">{stats.byPriority.urgent}</p>
          </div>

          <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <div className="flex items-center gap-2 text-red-500 mb-1">
              <Shield className="w-5 h-5" />
              <span className="text-sm font-medium">Contestations</span>
            </div>
            <p className="text-2xl font-bold">{stats.byCategory?.appeal || 0}</p>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
        <div className="flex items-center gap-2 mb-3">
          <Filter className="w-4 h-4 text-gray-500" />
          <span className="font-medium text-gray-700">Filtres</span>
        </div>
        <div className="flex flex-wrap gap-4">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-rose-400 focus:border-transparent"
          >
            <option value="">Tous les statuts</option>
            {STATUSES.map((s) => (
              <option key={s.value} value={s.value}>
                {s.label}
              </option>
            ))}
          </select>

          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-rose-400 focus:border-transparent"
          >
            <option value="">Toutes les catégories</option>
            {CATEGORIES.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </select>

          <select
            value={priorityFilter}
            onChange={(e) => setPriorityFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-rose-400 focus:border-transparent"
          >
            <option value="">Toutes les priorités</option>
            {PRIORITIES.map((p) => (
              <option key={p.value} value={p.value}>
                {p.label}
              </option>
            ))}
          </select>

          {(statusFilter || categoryFilter || priorityFilter) && (
            <button
              onClick={() => {
                setStatusFilter('');
                setCategoryFilter('');
                setPriorityFilter('');
              }}
              className="text-sm text-gray-500 hover:text-gray-700"
            >
              Réinitialiser
            </button>
          )}
        </div>
      </div>

      {/* Tickets List */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-500">Chargement...</div>
        ) : tickets.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <Inbox className="w-12 h-12 mx-auto mb-3 opacity-50" />
            <p>Aucun ticket trouvé</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {tickets.map((ticket) => {
              const categoryInfo = getCategoryInfo(ticket.category);
              const statusInfo = getStatusInfo(ticket.status);
              const priorityInfo = getPriorityInfo(ticket.priority);
              const CategoryIcon = categoryInfo.icon;
              const PriorityIcon = priorityInfo.icon;

              return (
                <div
                  key={ticket.id}
                  onClick={() => openChat(ticket.id)}
                  className="p-4 hover:bg-gray-50 cursor-pointer transition"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex items-start gap-3 flex-1 min-w-0">
                      {/* Category icon */}
                      <div className={`p-2 rounded-lg ${categoryInfo.color} bg-opacity-10`}>
                        <CategoryIcon className={`w-5 h-5 ${categoryInfo.color.replace('bg-', 'text-')}`} />
                      </div>

                      <div className="flex-1 min-w-0">
                        {/* Subject */}
                        <div className="flex items-center gap-2">
                          <h3 className="font-medium text-gray-900 truncate">{ticket.subject}</h3>
                          <PriorityIcon className={`w-4 h-4 ${priorityInfo.color}`} />
                        </div>

                        {/* User info */}
                        <div className="flex items-center gap-2 mt-1 text-sm text-gray-500">
                          <User className="w-3 h-3" />
                          <span>
                            {ticket.user.firstName || ''} {ticket.user.lastName || ticket.user.email}
                          </span>
                          {ticket.user.isBanned && (
                            <span className="px-1.5 py-0.5 bg-red-100 text-red-700 text-xs rounded">
                              Banni
                            </span>
                          )}
                          {ticket.user.suspendedUntil && new Date(ticket.user.suspendedUntil) > new Date() && (
                            <span className="px-1.5 py-0.5 bg-orange-100 text-orange-700 text-xs rounded">
                              Suspendu
                            </span>
                          )}
                        </div>

                        {/* Last message preview */}
                        {ticket.lastMessage && (
                          <p className="mt-1 text-sm text-gray-400 truncate">
                            {ticket.lastMessage.isFromAdmin ? 'Vous: ' : ''}
                            {ticket.lastMessage.content}
                          </p>
                        )}
                      </div>
                    </div>

                    <div className="flex flex-col items-end gap-2 shrink-0">
                      {/* Status badge */}
                      <span className={`px-2 py-1 text-xs font-medium text-white rounded-full ${statusInfo.color}`}>
                        {statusInfo.label}
                      </span>

                      {/* Time */}
                      <span className="text-xs text-gray-400">
                        {format(new Date(ticket.updatedAt), 'dd MMM HH:mm', { locale: fr })}
                      </span>

                      {/* Message count */}
                      <div className="flex items-center gap-1 text-xs text-gray-400">
                        <MessageSquare className="w-3 h-3" />
                        {ticket.messageCount}
                      </div>
                    </div>

                    <ChevronRight className="w-5 h-5 text-gray-300" />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Chat Modal */}
      {showChatModal && selectedTicket && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl">
            {/* Modal Header */}
            <div className="p-4 border-b border-gray-100 flex items-center justify-between shrink-0">
              <div>
                <h2 className="font-bold text-lg text-gray-900">{selectedTicket.subject}</h2>
                <div className="flex items-center gap-2 mt-1 text-sm text-gray-500">
                  <User className="w-3 h-3" />
                  <span>
                    {selectedTicket.user.firstName || ''} {selectedTicket.user.lastName || ''} -{' '}
                    {selectedTicket.user.email}
                  </span>
                </div>
              </div>
              <button onClick={closeChat} className="p-2 hover:bg-gray-100 rounded-lg transition">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Actions Bar */}
            <div className="p-3 border-b border-gray-100 flex flex-wrap items-center gap-2 shrink-0 bg-gray-50">
              {/* Status dropdown */}
              <select
                value={selectedTicket.status}
                onChange={(e) => updateStatus(e.target.value)}
                className="px-2 py-1 text-sm border border-gray-200 rounded-lg focus:ring-2 focus:ring-rose-400"
              >
                {STATUSES.map((s) => (
                  <option key={s.value} value={s.value}>
                    {s.label}
                  </option>
                ))}
              </select>

              {/* Priority dropdown */}
              <select
                value={selectedTicket.priority}
                onChange={(e) => updatePriority(e.target.value)}
                className="px-2 py-1 text-sm border border-gray-200 rounded-lg focus:ring-2 focus:ring-rose-400"
              >
                {PRIORITIES.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>

              {/* Category badge */}
              <span
                className={`px-2 py-1 text-xs font-medium text-white rounded-full ${getCategoryInfo(selectedTicket.category).color}`}
              >
                {getCategoryInfo(selectedTicket.category).label}
              </span>

              {/* Related sanction info */}
              {selectedTicket.relatedSanction && (
                <span className="px-2 py-1 text-xs bg-red-100 text-red-700 rounded-full">
                  Contestation: {selectedTicket.relatedSanction.type}
                </span>
              )}

              <div className="flex-1" />

              {/* Assign button */}
              <button
                onClick={assignToSelf}
                className="px-3 py-1 text-sm bg-rose-400 text-white rounded-lg hover:bg-rose-500 transition"
              >
                Me l'assigner
              </button>
            </div>

            {/* Messages Area */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4 min-h-[300px]">
              {selectedTicket.messages.map((msg) => (
                <div key={msg.id} className={`flex ${msg.isFromAdmin ? 'justify-end' : 'justify-start'}`}>
                  <div
                    className={`max-w-[80%] rounded-2xl px-4 py-2 ${
                      msg.isFromAdmin
                        ? 'bg-rose-400 text-white rounded-br-md'
                        : 'bg-gray-100 text-gray-900 rounded-bl-md'
                    }`}
                  >
                    <p className="whitespace-pre-wrap break-words">{msg.content}</p>
                    <div
                      className={`text-xs mt-1 ${msg.isFromAdmin ? 'text-rose-100' : 'text-gray-400'}`}
                    >
                      {format(new Date(msg.createdAt), 'dd MMM HH:mm', { locale: fr })}
                      {msg.isFromAdmin && msg.readAt && ' ✓✓'}
                    </div>
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>

            {/* Message Input */}
            {selectedTicket.status !== 'CLOSED' && selectedTicket.status !== 'RESOLVED' && (
              <div className="p-4 border-t border-gray-100 shrink-0">
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
                    placeholder="Votre réponse..."
                    className="flex-1 px-4 py-2 border border-gray-200 rounded-full focus:ring-2 focus:ring-rose-400 focus:border-transparent"
                    disabled={sending}
                  />
                  <button
                    onClick={sendMessage}
                    disabled={!newMessage.trim() || sending}
                    className="p-3 bg-rose-400 text-white rounded-full hover:bg-rose-500 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Send className="w-5 h-5" />
                  </button>
                </div>
              </div>
            )}

            {/* Closed ticket message */}
            {(selectedTicket.status === 'CLOSED' || selectedTicket.status === 'RESOLVED') && (
              <div className="p-4 border-t border-gray-100 bg-gray-50 text-center text-gray-500 text-sm">
                Ce ticket est {selectedTicket.status === 'CLOSED' ? 'fermé' : 'résolu'}. Pour répondre,
                changez d'abord le statut.
              </div>
            )}
          </div>
        </div>
      )}
    </div>
    </DashboardLayout>
  );
}
