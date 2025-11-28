import { useEffect, useState } from 'react';
import {
  User,
  Mail,
  Phone,
  MapPin,
  Link as LinkIcon,
  Copy,
  LogOut,
  Eye,
  EyeOff,
  Stethoscope,
  Check,
  Clock,
  X,
  Calendar,
  Save,
  RefreshCw,
  ExternalLink,
} from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import { useAuthStore } from '../store/authStore';
import api from '../api/client';
import type { Service } from '../types';
import { useNavigate, Link } from 'react-router-dom';

export function ProSettings() {
  const navigate = useNavigate();
  const { user, provider, setProvider, logout } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [services, setServices] = useState<Service[]>([]);

  // Stats
  const [stats, setStats] = useState({
    confirmed: 0,
    pending: 0,
    cancelled: 0,
    total: 0,
  });

  // Form fields
  const [bio, setBio] = useState('');
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    try {
      // Load provider profile
      const providerData = await api.myProvider();
      if (providerData) {
        setProvider(providerData);
        setBio(providerData.bio || '');
        setVisible(providerData.visible ?? true);
      }

      // Load services
      const servicesData = await api.myServices();
      setServices(servicesData);

      // Load stats from bookings
      const now = new Date();
      const fromDate = new Date(now.getFullYear() - 1, now.getMonth(), 1);
      const bookings = await api.providerAgenda(
        fromDate.toISOString().split('T')[0],
        now.toISOString().split('T')[0]
      );

      let confirmed = 0,
        pending = 0,
        cancelled = 0,
        completed = 0;
      bookings.forEach((b) => {
        const status = (b.status || '').toUpperCase();
        if (status === 'CONFIRMED') confirmed++;
        else if (status === 'PENDING' || status === 'PENDING_PRO_VALIDATION') pending++;
        else if (status === 'CANCELLED' || status === 'CANCELED') cancelled++;
        else if (status === 'COMPLETED') completed++;
      });

      setStats({
        confirmed,
        pending,
        cancelled,
        total: confirmed + pending + cancelled + completed,
      });
    } catch (error) {
      console.error('Error loading settings data:', error);
    } finally {
      setLoading(false);
    }
  }

  const handleSave = async () => {
    setSaving(true);
    try {
      const fullName = `${user?.firstName || ''} ${user?.lastName || ''}`.trim();
      const displayName = fullName || user?.email?.split('@')[0] || 'Docteur';

      const updated = await api.upsertMyProvider({
        displayName,
        bio: bio.trim() || undefined,
        address: provider?.address,
        specialties: provider?.specialties,
      });

      setProvider(updated);
      alert('Profil enregistré !');
    } catch (error) {
      console.error('Error saving profile:', error);
      alert("Erreur lors de l'enregistrement");
    } finally {
      setSaving(false);
    }
  };

  const handleToggleVisibility = async () => {
    const newValue = !visible;
    setVisible(newValue);

    try {
      try {
        await api.setMyVisibility(newValue);
      } catch {
        // Fallback: use upsertMyProvider with specialties
        const fullName = `${user?.firstName || ''} ${user?.lastName || ''}`.trim();
        const displayName = fullName || user?.email?.split('@')[0] || 'Docteur';

        await api.upsertMyProvider({
          displayName,
          address: provider?.address,
          specialties: { ...provider?.specialties, visible: newValue },
        });
      }

      alert(newValue ? 'Profil visible' : 'Profil masqué');
      await loadData();
    } catch (error) {
      console.error('Error toggling visibility:', error);
      setVisible(!newValue); // Revert
      alert('Erreur');
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    alert(`${label} copié !`);
  };

  const formatPrice = (price: number | string | undefined) => {
    if (!price) return '—';
    const n = typeof price === 'number' ? price : parseInt(price);
    return isNaN(n) ? '—' : `${n.toLocaleString('fr-DZ')} DA`;
  };

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
        </div>
      </DashboardLayout>
    );
  }

  const displayName =
    provider?.displayName ||
    `${user?.firstName || ''} ${user?.lastName || ''}`.trim() ||
    'Docteur';
  const initial = displayName[0]?.toUpperCase() || 'D';
  const isApproved = provider?.status === 'APPROVED' || provider?.isApproved;
  const providerId = provider?.id;

  return (
    <DashboardLayout>
      <div className="space-y-6 max-w-4xl">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Mon profil professionnel</h1>
          </div>
          <div className="flex gap-2">
            <Button variant="secondary" onClick={loadData}>
              <RefreshCw size={16} className="mr-2" />
              Actualiser
            </Button>
            <Button variant="secondary" onClick={handleLogout}>
              <LogOut size={16} className="mr-2" />
              Déconnexion
            </Button>
          </div>
        </div>

        {/* Header Card */}
        <Card>
          <div className="flex items-center gap-4">
            <div className="relative">
              {provider?.avatarUrl ? (
                <img
                  src={provider.avatarUrl}
                  alt={displayName}
                  className="w-20 h-20 rounded-full object-cover"
                />
              ) : (
                <div className="w-20 h-20 bg-primary-100 rounded-full flex items-center justify-center">
                  <span className="text-2xl font-bold text-primary-600">{initial}</span>
                </div>
              )}
            </div>
            <div className="flex-1">
              <h2 className="text-xl font-bold text-gray-900">{displayName}</h2>
              <div className="flex flex-wrap gap-2 mt-2">
                <span className="px-3 py-1 bg-pink-50 text-pink-700 text-sm font-medium rounded-full border border-pink-200">
                  {(provider?.specialties as { kind?: string })?.kind?.toUpperCase() || 'VET'}
                </span>
                <span
                  className={`px-3 py-1 text-sm font-medium rounded-full ${
                    isApproved
                      ? 'bg-primary-600 text-white'
                      : 'bg-yellow-50 text-yellow-700 border border-yellow-200'
                  }`}
                >
                  {isApproved ? 'APPROUVÉ' : 'EN ATTENTE'}
                </span>
                {providerId && (
                  <button
                    onClick={() => copyToClipboard(providerId, 'ID fournisseur')}
                    className="px-3 py-1 bg-gray-100 text-gray-700 text-sm font-medium rounded-full hover:bg-gray-200 flex items-center gap-1"
                  >
                    ID: {providerId.substring(0, 8)}…
                    <Copy size={12} />
                  </button>
                )}
              </div>
            </div>
          </div>
        </Card>

        {/* Stats Row */}
        <Card>
          <h3 className="font-bold text-gray-900 mb-4">Résumé des rendez-vous</h3>
          <div className="flex flex-wrap gap-3">
            <StatPill icon={<Check size={14} />} label="Confirmés" value={stats.confirmed} />
            <StatPill icon={<Clock size={14} />} label="Pending" value={stats.pending} />
            <StatPill icon={<X size={14} />} label="Annulés" value={stats.cancelled} />
            <StatPill icon={<Calendar size={14} />} label="Total" value={stats.total} />
          </div>
        </Card>

        {/* Business Card */}
        <Card>
          <h3 className="font-bold text-gray-900 mb-4">Informations professionnelles</h3>
          <div className="space-y-3">
            <InfoRow
              icon={<Mail size={16} />}
              label="Email"
              value={user?.email || '—'}
              onCopy={() => copyToClipboard(user?.email || '', 'Email')}
            />
            <InfoRow
              icon={<Phone size={16} />}
              label="Téléphone"
              value={user?.phone || '—'}
              onCopy={() => copyToClipboard(user?.phone || '', 'Téléphone')}
            />
            <InfoRow
              icon={<MapPin size={16} />}
              label="Adresse"
              value={provider?.address || '—'}
              onCopy={() => copyToClipboard(provider?.address || '', 'Adresse')}
            />
            <InfoRow
              icon={<LinkIcon size={16} />}
              label="Google Maps"
              value={(provider?.specialties as { mapsUrl?: string })?.mapsUrl || '—'}
              onCopy={() =>
                copyToClipboard(
                  (provider?.specialties as { mapsUrl?: string })?.mapsUrl || '',
                  'Lien Maps'
                )
              }
            />

            <div className="pt-4 border-t border-gray-100 flex items-center justify-between">
              <div>
                <p className="font-medium text-gray-900">Visibilité publique</p>
                <p className="text-sm text-gray-500">
                  {visible ? 'Votre profil est visible' : 'Votre profil est masqué'}
                </p>
              </div>
              <button
                onClick={handleToggleVisibility}
                className={`relative inline-flex h-7 w-12 items-center rounded-full transition-colors ${
                  visible ? 'bg-primary-600' : 'bg-gray-300'
                }`}
              >
                <span
                  className={`inline-block h-5 w-5 transform rounded-full bg-white transition-transform shadow ${
                    visible ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>

            {providerId && (
              <div className="pt-2">
                <Link
                  to={`/explore/vets/${providerId}`}
                  className="inline-flex items-center gap-2 text-primary-600 hover:text-primary-700 font-medium"
                >
                  <ExternalLink size={16} />
                  Voir le profil public
                </Link>
              </div>
            )}
          </div>
        </Card>

        {/* Services Card */}
        <Card>
          <h3 className="font-bold text-gray-900 mb-4">Mes services</h3>
          {services.length === 0 ? (
            <p className="text-gray-500">Aucun service défini.</p>
          ) : (
            <div className="space-y-2">
              {services.slice(0, 5).map((s) => (
                <div key={s.id} className="flex items-center justify-between py-2">
                  <div className="flex items-center gap-2">
                    <Stethoscope size={16} className="text-gray-500" />
                    <span className="font-medium">{s.title}</span>
                  </div>
                  <span className="text-gray-500">{formatPrice(s.price)}</span>
                </div>
              ))}
              {services.length > 5 && (
                <p className="text-gray-400 text-sm">+ encore {services.length - 5}…</p>
              )}
            </div>
          )}
          <div className="pt-4">
            <Link to="/pro/services">
              <Button variant="secondary" className="w-full">
                <Stethoscope size={16} className="mr-2" />
                Gérer mes services
              </Button>
            </Link>
          </div>
        </Card>

        {/* Bio Card */}
        <Card>
          <h3 className="font-bold text-gray-900 mb-4">Présentation</h3>
          <textarea
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            maxLength={280}
            rows={4}
            placeholder="Décrivez votre parcours et spécialités..."
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 resize-none"
          />
          <p className="text-sm text-gray-400 mt-1 text-right">{bio.length}/280</p>
          <p className="text-sm text-gray-500 mt-2">Visible côté clients</p>
        </Card>

        {/* Save Button */}
        <Button onClick={handleSave} isLoading={saving} className="w-full">
          <Save size={16} className="mr-2" />
          Enregistrer
        </Button>
      </div>
    </DashboardLayout>
  );
}

// Helper components
function StatPill({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: number;
}) {
  return (
    <div className="flex items-center gap-2 px-4 py-2 bg-pink-50 border border-pink-200 rounded-full">
      <span className="text-pink-600">{icon}</span>
      <span className="font-medium text-gray-900">{label}</span>
      <span className="px-2 py-0.5 bg-white border border-pink-200 rounded-lg text-sm">
        {value}
      </span>
    </div>
  );
}

function InfoRow({
  icon,
  label,
  value,
  onCopy,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  onCopy?: () => void;
}) {
  const hasValue = value && value !== '—';
  return (
    <div className="flex items-center gap-4 py-2">
      <div className="text-gray-400">{icon}</div>
      <div className="w-28 text-sm text-gray-500">{label}</div>
      <div className="flex-1 text-gray-900">{value}</div>
      {hasValue && onCopy && (
        <button onClick={onCopy} className="p-1 text-gray-400 hover:text-gray-600">
          <Copy size={16} />
        </button>
      )}
    </div>
  );
}
