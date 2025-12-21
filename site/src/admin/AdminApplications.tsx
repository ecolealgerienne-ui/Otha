import { useEffect, useState, useCallback } from 'react';
import { Check, X, Eye, MapPin, Clock, CheckCircle, XCircle, Phone, Mail, Link, Navigation, Save, RefreshCw, Copy, DollarSign, Briefcase, ExternalLink } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderProfile, Service } from '../types';

// Use lowercase status like Flutter app does
type TabStatus = 'pending' | 'approved' | 'rejected';

// Helper: Sanitize Google Maps URL (remove tracking params)
function sanitizeMapsUrl(url: string): string {
  const raw = url.trim();
  if (!raw) return '';

  const withScheme = /^(https?:\/\/)/i.test(raw) ? raw : `https://${raw}`;

  try {
    const uri = new URL(withScheme);
    const banned = new Set(['ts', 'entry', 'g_ep', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content', 'hl', 'ved', 'source', 'opi', 'sca_esv']);

    const params = new URLSearchParams(uri.search);
    banned.forEach(key => params.delete(key));
    uri.search = params.toString();

    let path = uri.pathname.replace(/\/+/g, '/');
    const hasImportant = /\/data=![^/?#]*(?:!3d|!4d|:0x|ChI)/i.test(path);
    if (!hasImportant) {
      path = path.replace(/\/data=![^/?#]*/g, '');
    }
    uri.pathname = path;

    return uri.toString().replace(/[?#]$/, '');
  } catch {
    return raw;
  }
}

// Helper: Extract lat/lng from Google Maps URL
function extractLatLngFromUrl(url: string): { lat: number | null; lng: number | null } {
  const s = url.trim();
  if (!s) return { lat: null, lng: null };

  const dec = decodeURIComponent(s);

  // @lat,lng pattern
  const atMatches = [...dec.matchAll(/@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/g)];
  if (atMatches.length > 0) {
    const m = atMatches[atMatches.length - 1];
    const lat = parseFloat(m[1].replace(',', '.'));
    const lng = parseFloat(m[2].replace(',', '.'));
    if (!isNaN(lat) && !isNaN(lng)) return { lat, lng };
  }

  // !3dlat!4dlng pattern
  const m34 = dec.match(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/i);
  if (m34) {
    const lat = parseFloat(m34[1].replace(',', '.'));
    const lng = parseFloat(m34[2].replace(',', '.'));
    if (!isNaN(lat) && !isNaN(lng)) return { lat, lng };
  }

  // !4dlng!3dlat pattern
  const m43 = dec.match(/!4d(-?\d+(?:\.\d+)?)!3d(-?\d+(?:\.\d+)?)/i);
  if (m43) {
    const lat = parseFloat(m43[2].replace(',', '.'));
    const lng = parseFloat(m43[1].replace(',', '.'));
    if (!isNaN(lat) && !isNaN(lng)) return { lat, lng };
  }

  return { lat: null, lng: null };
}

// Helper: Format price in DZD
function formatPrice(price: number): string {
  return new Intl.NumberFormat('fr-DZ', {
    style: 'currency',
    currency: 'DZD',
    maximumFractionDigits: 0,
  }).format(price);
}

export function AdminApplications() {
  const [activeTab, setActiveTab] = useState<TabStatus>('pending');
  const [providers, setProviders] = useState<ProviderProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedProvider, setSelectedProvider] = useState<ProviderProfile | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // Provider details
  const [services, setServices] = useState<Service[]>([]);
  const [servicesLoading, setServicesLoading] = useState(false);

  // Edit form state
  const [mapsUrl, setMapsUrl] = useState('');
  const [lat, setLat] = useState('');
  const [lng, setLng] = useState('');
  const [saving, setSaving] = useState(false);
  const [copied, setCopied] = useState<string | null>(null);

  useEffect(() => {
    fetchProviders(activeTab);
  }, [activeTab]);

  // When provider is selected, fetch fresh data and services
  const loadProviderDetails = useCallback(async (provider: ProviderProfile) => {
    // Set form fields from provider data
    const specialties = provider.specialties as Record<string, unknown> | null;
    setMapsUrl((specialties?.mapsUrl as string) || provider.mapsUrl || '');
    setLat(provider.lat?.toFixed(6) || '');
    setLng(provider.lng?.toFixed(6) || '');

    // Fetch services
    setServicesLoading(true);
    try {
      const providerServices = await api.getProviderServices(provider.id);
      setServices(providerServices);
    } catch (error) {
      console.error('Error fetching services:', error);
      setServices([]);
    } finally {
      setServicesLoading(false);
    }
  }, []);

  useEffect(() => {
    if (selectedProvider) {
      loadProviderDetails(selectedProvider);
    } else {
      setServices([]);
      setMapsUrl('');
      setLat('');
      setLng('');
    }
  }, [selectedProvider, loadProviderDetails]);

  async function fetchProviders(status: TabStatus) {
    setLoading(true);
    try {
      const data = await api.listProviderApplications(status, 100);
      setProviders(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching providers:', error);
      setProviders([]);
    } finally {
      setLoading(false);
    }
  }

  async function handleApprove(providerId: string) {
    setActionLoading(providerId);
    try {
      await api.approveProvider(providerId);
      setProviders((prev) => prev.filter((p) => p.id !== providerId));
      setSelectedProvider(null);
    } catch (error) {
      console.error('Error approving provider:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleReject(providerId: string) {
    if (!confirm('Rejeter cette candidature ?')) return;
    setActionLoading(providerId);
    try {
      await api.rejectProvider(providerId);
      setProviders((prev) => prev.filter((p) => p.id !== providerId));
      setSelectedProvider(null);
    } catch (error) {
      console.error('Error rejecting provider:', error);
    } finally {
      setActionLoading(null);
    }
  }

  async function handleSaveLocation() {
    if (!selectedProvider) return;

    let finalLat = parseFloat(lat.replace(',', '.'));
    let finalLng = parseFloat(lng.replace(',', '.'));

    // Auto-extract from URL if coords missing
    if ((isNaN(finalLat) || isNaN(finalLng)) && mapsUrl) {
      const extracted = extractLatLngFromUrl(mapsUrl);
      if (extracted.lat !== null) finalLat = extracted.lat;
      if (extracted.lng !== null) finalLng = extracted.lng;
      setLat(finalLat?.toFixed(6) || '');
      setLng(finalLng?.toFixed(6) || '');
    }

    if (isNaN(finalLat) || isNaN(finalLng)) {
      alert('Coordonnées invalides. Veuillez entrer latitude et longitude ou extraire depuis l\'URL.');
      return;
    }

    setSaving(true);
    try {
      const sanitized = mapsUrl ? sanitizeMapsUrl(mapsUrl) : '';
      await api.adminUpdateProvider(selectedProvider.id, {
        lat: finalLat,
        lng: finalLng,
        mapsUrl: sanitized,
      });

      // Update the selected provider with new values
      setSelectedProvider({
        ...selectedProvider,
        lat: finalLat,
        lng: finalLng,
        mapsUrl: sanitized,
      });

      // Refresh the list
      fetchProviders(activeTab);
      alert('Modifications enregistrées');
    } catch (error) {
      console.error('Error saving:', error);
      alert('Erreur lors de l\'enregistrement');
    } finally {
      setSaving(false);
    }
  }

  function handleExtractCoords() {
    const extracted = extractLatLngFromUrl(mapsUrl);
    if (extracted.lat !== null && extracted.lng !== null) {
      setLat(extracted.lat.toFixed(6));
      setLng(extracted.lng.toFixed(6));
    } else {
      alert('Aucune coordonnée trouvée dans l\'URL');
    }
  }

  function handleSanitizeUrl() {
    setMapsUrl(sanitizeMapsUrl(mapsUrl));
  }

  async function copyToClipboard(text: string, type: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(type);
      setTimeout(() => setCopied(null), 2000);
    } catch {
      // Fallback
    }
  }

  const tabs: { status: TabStatus; label: string; icon: React.ReactNode }[] = [
    { status: 'pending', label: 'En attente', icon: <Clock size={16} /> },
    { status: 'approved', label: 'Approuvées', icon: <CheckCircle size={16} /> },
    { status: 'rejected', label: 'Rejetées', icon: <XCircle size={16} /> },
  ];

  // Get user info from provider
  const user = selectedProvider?.user as Record<string, unknown> | undefined;
  const email = (user?.email as string) || '';
  const phone = (user?.phone as string) || '';
  const isApproved = selectedProvider?.isApproved === true;
  const providerAsAny = selectedProvider as unknown as Record<string, unknown> | undefined;
  const rejectedAt = providerAsAny?.rejectedAt as string | undefined;
  const isRejected = !!rejectedAt;

  // Map coordinates
  const previewLat = parseFloat(lat.replace(',', '.'));
  const previewLng = parseFloat(lng.replace(',', '.'));

  // Google Maps link for viewing
  const googleMapsLink = !isNaN(previewLat) && !isNaN(previewLng)
    ? `https://www.google.com/maps?q=${previewLat},${previewLng}`
    : null;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Demandes Pro</h1>
          <p className="text-gray-600 mt-1">Gérez les demandes d'inscription des professionnels</p>
        </div>

        {/* Tabs */}
        <div className="flex space-x-2 border-b border-gray-200">
          {tabs.map((tab) => (
            <button
              key={tab.status}
              onClick={() => setActiveTab(tab.status)}
              className={`flex items-center space-x-2 px-4 py-3 border-b-2 transition-colors ${
                activeTab === tab.status
                  ? 'border-primary-600 text-primary-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab.icon}
              <span>{tab.label}</span>
              {activeTab === tab.status && (
                <span className="bg-primary-100 text-primary-700 text-xs px-2 py-0.5 rounded-full">
                  {providers.length}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* List */}
          <div className="lg:col-span-1">
            {loading ? (
              <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
              </div>
            ) : providers.length === 0 ? (
              <Card className="text-center py-12">
                <p className="text-gray-500">Aucune demande {activeTab === 'pending' ? 'en attente' : activeTab === 'approved' ? 'approuvée' : 'rejetée'}</p>
              </Card>
            ) : (
              <div className="space-y-3 max-h-[70vh] overflow-y-auto">
                {providers.map((provider) => (
                  <Card
                    key={provider.id}
                    className={`cursor-pointer transition-all ${
                      selectedProvider?.id === provider.id
                        ? 'ring-2 ring-primary-500'
                        : 'hover:shadow-md'
                    }`}
                    onClick={() => setSelectedProvider(provider)}
                  >
                    <div className="flex items-center space-x-3">
                      {provider.avatarUrl ? (
                        <img
                          src={provider.avatarUrl}
                          alt={provider.displayName}
                          className="w-12 h-12 rounded-lg object-cover"
                        />
                      ) : (
                        <div className="w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center">
                          <span className="text-primary-700 font-bold text-lg">
                            {provider.displayName?.charAt(0) || '?'}
                          </span>
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <h3 className="font-semibold text-gray-900 truncate">{provider.displayName || '(Sans nom)'}</h3>
                        <p className="text-sm text-gray-500 truncate">{provider.address || 'Adresse non renseignée'}</p>
                        {provider.lat && provider.lng && (
                          <p className="text-xs text-green-600">
                            ✓ Coords: {provider.lat.toFixed(4)}, {provider.lng.toFixed(4)}
                          </p>
                        )}
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </div>

          {/* Detail panel */}
          <div className="lg:col-span-2">
            {selectedProvider ? (
              <div className="space-y-4">
                <Card>
                  {/* Header with status badge */}
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center space-x-4">
                      {selectedProvider.avatarUrl ? (
                        <img
                          src={selectedProvider.avatarUrl}
                          alt={selectedProvider.displayName}
                          className="w-16 h-16 rounded-xl object-cover"
                        />
                      ) : (
                        <div className="w-16 h-16 bg-primary-100 rounded-xl flex items-center justify-center">
                          <span className="text-primary-700 font-bold text-2xl">
                            {selectedProvider.displayName?.charAt(0) || '?'}
                          </span>
                        </div>
                      )}
                      <div>
                        <h3 className="text-xl font-bold text-gray-900">{selectedProvider.displayName || '(Sans nom)'}</h3>
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold ${
                          isRejected
                            ? 'bg-red-100 text-red-800'
                            : isApproved
                              ? 'bg-green-100 text-green-800'
                              : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {isRejected ? 'REJETÉ' : isApproved ? 'APPROUVÉ' : 'EN ATTENTE'}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Coordonnées */}
                  <div className="border-t pt-4 mb-4">
                    <h4 className="font-semibold text-gray-900 mb-3">Coordonnées</h4>
                    <div className="space-y-2 text-sm">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <Mail size={16} className="text-gray-400" />
                          <span>{email || '—'}</span>
                        </div>
                        {email && (
                          <button onClick={() => copyToClipboard(email, 'email')} className="text-gray-400 hover:text-gray-600">
                            <Copy size={14} />
                            {copied === 'email' && <span className="ml-1 text-green-600 text-xs">Copié!</span>}
                          </button>
                        )}
                      </div>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <Phone size={16} className="text-gray-400" />
                          <span>{phone || '—'}</span>
                        </div>
                        {phone && (
                          <button onClick={() => copyToClipboard(phone, 'phone')} className="text-gray-400 hover:text-gray-600">
                            <Copy size={14} />
                            {copied === 'phone' && <span className="ml-1 text-green-600 text-xs">Copié!</span>}
                          </button>
                        )}
                      </div>
                      <div className="flex items-center space-x-2">
                        <MapPin size={16} className="text-gray-400" />
                        <span>{selectedProvider.address || '—'}</span>
                      </div>
                    </div>
                  </div>

                  {/* Validation de la localisation */}
                  <div className="border-t pt-4 mb-4">
                    <h4 className="font-semibold text-gray-900 mb-3">Validation de la localisation</h4>

                    <div className="space-y-3">
                      {/* Google Maps URL */}
                      <div>
                        <label className="block text-sm text-gray-600 mb-1">Lien Google Maps</label>
                        <div className="flex space-x-2">
                          <input
                            type="url"
                            value={mapsUrl}
                            onChange={(e) => setMapsUrl(e.target.value)}
                            placeholder="https://www.google.com/maps/..."
                            className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                          />
                          <button
                            onClick={handleSanitizeUrl}
                            title="Nettoyer l'URL"
                            className="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                          >
                            <Link size={16} />
                          </button>
                          <button
                            onClick={handleExtractCoords}
                            title="Extraire les coordonnées"
                            className="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                          >
                            <Navigation size={16} />
                          </button>
                        </div>
                      </div>

                      {/* Lat/Lng */}
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <label className="block text-sm text-gray-600 mb-1">Latitude</label>
                          <input
                            type="text"
                            value={lat}
                            onChange={(e) => setLat(e.target.value)}
                            placeholder="36.752887"
                            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                          />
                        </div>
                        <div>
                          <label className="block text-sm text-gray-600 mb-1">Longitude</label>
                          <input
                            type="text"
                            value={lng}
                            onChange={(e) => setLng(e.target.value)}
                            placeholder="3.042048"
                            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                          />
                        </div>
                      </div>

                      {/* Map link (no preview - just button) */}
                      <div className="rounded-lg border border-gray-200 p-4 bg-gray-50">
                        {googleMapsLink ? (
                          <div className="flex items-center justify-between">
                            <div>
                              <p className="text-sm font-medium text-gray-900">Localisation</p>
                              <p className="text-xs text-gray-500">
                                {previewLat.toFixed(6)}, {previewLng.toFixed(6)}
                              </p>
                            </div>
                            <a
                              href={googleMapsLink}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center px-4 py-2 bg-primary-600 text-white rounded-lg text-sm font-medium hover:bg-primary-700 transition-colors"
                            >
                              <ExternalLink size={16} className="mr-2" />
                              Ouvrir sur Google Maps
                            </a>
                          </div>
                        ) : (
                          <p className="text-sm text-gray-500 text-center">
                            Coordonnées manquantes — entrez lat/lng ou extrayez depuis l'URL
                          </p>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* AVN Cards */}
                  {(selectedProvider.avnCardFront || selectedProvider.avnCardBack) && (
                    <div className="border-t pt-4 mb-4">
                      <h4 className="font-semibold text-gray-900 mb-3">Carte AVN</h4>
                      <div className="grid grid-cols-2 gap-3">
                        {selectedProvider.avnCardFront && (
                          <a href={selectedProvider.avnCardFront} target="_blank" rel="noopener noreferrer">
                            <img src={selectedProvider.avnCardFront} alt="AVN Recto" className="w-full h-24 object-cover rounded border hover:border-primary-500" />
                            <p className="text-xs text-center text-gray-500 mt-1">Recto</p>
                          </a>
                        )}
                        {selectedProvider.avnCardBack && (
                          <a href={selectedProvider.avnCardBack} target="_blank" rel="noopener noreferrer">
                            <img src={selectedProvider.avnCardBack} alt="AVN Verso" className="w-full h-24 object-cover rounded border hover:border-primary-500" />
                            <p className="text-xs text-center text-gray-500 mt-1">Verso</p>
                          </a>
                        )}
                      </div>
                    </div>
                  )}

                  {/* Action buttons */}
                  <div className="border-t pt-4 flex flex-wrap gap-3">
                    <Button
                      variant="secondary"
                      onClick={handleSaveLocation}
                      isLoading={saving}
                      className="flex-1"
                    >
                      <Save size={16} className="mr-2" />
                      Enregistrer
                    </Button>

                    {activeTab === 'pending' && (
                      <>
                        <Button
                          onClick={() => handleApprove(selectedProvider.id)}
                          isLoading={actionLoading === selectedProvider.id}
                          className="flex-1"
                        >
                          <Check size={16} className="mr-2" />
                          Approuver
                        </Button>
                        <Button
                          variant="danger"
                          onClick={() => handleReject(selectedProvider.id)}
                          isLoading={actionLoading === selectedProvider.id}
                        >
                          <X size={16} className="mr-2" />
                          Rejeter
                        </Button>
                      </>
                    )}

                    {activeTab === 'rejected' && (
                      <Button
                        onClick={() => handleApprove(selectedProvider.id)}
                        isLoading={actionLoading === selectedProvider.id}
                        className="flex-1"
                      >
                        <RefreshCw size={16} className="mr-2" />
                        Ré-approuver
                      </Button>
                    )}

                    {activeTab === 'approved' && (
                      <Button
                        variant="danger"
                        onClick={() => handleReject(selectedProvider.id)}
                        isLoading={actionLoading === selectedProvider.id}
                      >
                        <X size={16} className="mr-2" />
                        Rejeter
                      </Button>
                    )}
                  </div>
                </Card>

                {/* Services Card */}
                <Card>
                  <div className="flex items-center justify-between mb-4">
                    <h4 className="font-semibold text-gray-900 flex items-center">
                      <Briefcase size={18} className="mr-2 text-primary-600" />
                      Services ({services.length})
                    </h4>
                  </div>

                  {servicesLoading ? (
                    <div className="flex items-center justify-center py-8">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" />
                    </div>
                  ) : services.length === 0 ? (
                    <p className="text-gray-500 text-sm py-4 text-center">Aucun service configuré</p>
                  ) : (
                    <div className="space-y-3">
                      {services.map((service) => (
                        <div
                          key={service.id}
                          className="p-3 bg-gray-50 rounded-lg border border-gray-200"
                        >
                          <div className="flex items-start justify-between">
                            <div className="flex-1">
                              <h5 className="font-medium text-gray-900">{service.title}</h5>
                              {service.description && (
                                <p className="text-sm text-gray-600 mt-1">{service.description}</p>
                              )}
                              <p className="text-xs text-gray-500 mt-1">
                                Durée: {service.durationMin} min
                              </p>
                            </div>
                            <div className="text-right">
                              <span className="inline-flex items-center px-2.5 py-1 bg-green-100 text-green-800 rounded-lg text-sm font-bold">
                                <DollarSign size={14} className="mr-1" />
                                {formatPrice(service.price)}
                              </span>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </Card>
              </div>
            ) : (
              <Card className="text-center py-16">
                <Eye size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez une demande pour voir les détails</p>
              </Card>
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
