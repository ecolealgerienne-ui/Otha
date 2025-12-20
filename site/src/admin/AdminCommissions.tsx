import { useEffect, useState } from 'react';
import { Percent, Search, RotateCcw, Save, Stethoscope, Home, ShoppingBag } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';

type ProviderKind = 'vet' | 'daycare' | 'petshop';

interface ProviderCommission {
  providerId: string;
  userId: string;
  displayName: string;
  email: string;
  isApproved: boolean;
  kind: ProviderKind;
  vetCommissionDa: number;
  daycareHourlyCommissionDa: number;
  daycareDailyCommissionDa: number;
}

const kindLabels: Record<ProviderKind, { label: string; color: string; bgColor: string; icon: typeof Stethoscope }> = {
  vet: { label: 'Vétérinaire', color: 'text-blue-700', bgColor: 'bg-blue-100', icon: Stethoscope },
  daycare: { label: 'Garderie', color: 'text-green-700', bgColor: 'bg-green-100', icon: Home },
  petshop: { label: 'Petshop', color: 'text-purple-700', bgColor: 'bg-purple-100', icon: ShoppingBag },
};

export function AdminCommissions() {
  const [providers, setProviders] = useState<ProviderCommission[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState({
    vetCommissionDa: 100,
    daycareHourlyCommissionDa: 10,
    daycareDailyCommissionDa: 100,
  });
  const [saving, setSaving] = useState(false);
  const [showApprovedOnly, setShowApprovedOnly] = useState(true);
  const [filterKind, setFilterKind] = useState<ProviderKind | 'all'>('all');

  useEffect(() => {
    fetchCommissions();
  }, [showApprovedOnly]);

  async function fetchCommissions() {
    setLoading(true);
    try {
      const data = await api.adminGetCommissions(undefined, showApprovedOnly ? true : undefined);
      setProviders(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching commissions:', error);
      setProviders([]);
    } finally {
      setLoading(false);
    }
  }

  const handleEdit = (provider: ProviderCommission) => {
    setEditingId(provider.providerId);
    setEditForm({
      vetCommissionDa: provider.vetCommissionDa,
      daycareHourlyCommissionDa: provider.daycareHourlyCommissionDa,
      daycareDailyCommissionDa: provider.daycareDailyCommissionDa,
    });
  };

  const handleCancel = () => {
    setEditingId(null);
  };

  const handleSave = async (provider: ProviderCommission) => {
    setSaving(true);
    try {
      // Only send relevant commission based on provider kind
      const commissionData: any = {};
      if (provider.kind === 'vet') {
        commissionData.vetCommissionDa = editForm.vetCommissionDa;
      } else if (provider.kind === 'daycare') {
        commissionData.daycareHourlyCommissionDa = editForm.daycareHourlyCommissionDa;
        commissionData.daycareDailyCommissionDa = editForm.daycareDailyCommissionDa;
      }
      // petshop: nothing for now

      await api.adminUpdateCommission(provider.providerId, commissionData);
      await fetchCommissions();
      setEditingId(null);
    } catch (error) {
      console.error('Error updating commission:', error);
      alert('Erreur lors de la mise à jour');
    } finally {
      setSaving(false);
    }
  };

  const handleReset = async (providerId: string) => {
    if (!confirm('Réinitialiser les commissions aux valeurs par défaut ?')) return;
    setSaving(true);
    try {
      await api.adminResetCommission(providerId);
      await fetchCommissions();
      setEditingId(null);
    } catch (error) {
      console.error('Error resetting commission:', error);
      alert('Erreur lors de la réinitialisation');
    } finally {
      setSaving(false);
    }
  };

  const filteredProviders = providers.filter((p) => {
    const matchesSearch = p.displayName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.email?.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesKind = filterKind === 'all' || p.kind === filterKind;
    return matchesSearch && matchesKind;
  });

  // Stats by kind
  const vetCount = providers.filter(p => p.kind === 'vet').length;
  const daycareCount = providers.filter(p => p.kind === 'daycare').length;
  const petshopCount = providers.filter(p => p.kind === 'petshop').length;

  const isCustomCommission = (p: ProviderCommission) => {
    if (p.kind === 'vet') return p.vetCommissionDa !== 100;
    if (p.kind === 'daycare') return p.daycareHourlyCommissionDa !== 10 || p.daycareDailyCommissionDa !== 100;
    return false;
  };

  return (
    <DashboardLayout>
      <div className="p-6 max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Percent className="w-7 h-7 text-rose-500" />
            Gestion des Commissions
          </h1>
          <p className="text-gray-500 mt-1">
            Configurez les commissions personnalisées pour chaque professionnel
          </p>
        </div>

        {/* Stats by type */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <Card className="p-4 cursor-pointer transition-all hover:ring-2 hover:ring-blue-300" onClick={() => setFilterKind(filterKind === 'vet' ? 'all' : 'vet')}>
            <div className={`flex items-center gap-3 ${filterKind === 'vet' ? 'opacity-100' : 'opacity-70'}`}>
              <div className="p-2 bg-blue-100 rounded-lg">
                <Stethoscope className="w-5 h-5 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Vétérinaires</p>
                <p className="text-xl font-bold text-gray-900">{vetCount}</p>
              </div>
            </div>
          </Card>
          <Card className="p-4 cursor-pointer transition-all hover:ring-2 hover:ring-green-300" onClick={() => setFilterKind(filterKind === 'daycare' ? 'all' : 'daycare')}>
            <div className={`flex items-center gap-3 ${filterKind === 'daycare' ? 'opacity-100' : 'opacity-70'}`}>
              <div className="p-2 bg-green-100 rounded-lg">
                <Home className="w-5 h-5 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Garderies</p>
                <p className="text-xl font-bold text-gray-900">{daycareCount}</p>
              </div>
            </div>
          </Card>
          <Card className="p-4 cursor-pointer transition-all hover:ring-2 hover:ring-purple-300" onClick={() => setFilterKind(filterKind === 'petshop' ? 'all' : 'petshop')}>
            <div className={`flex items-center gap-3 ${filterKind === 'petshop' ? 'opacity-100' : 'opacity-70'}`}>
              <div className="p-2 bg-purple-100 rounded-lg">
                <ShoppingBag className="w-5 h-5 text-purple-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500">Petshops</p>
                <p className="text-xl font-bold text-gray-900">{petshopCount}</p>
              </div>
            </div>
          </Card>
        </div>

        {/* Filters */}
        <Card className="p-4 mb-6">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <Input
                type="text"
                placeholder="Rechercher par nom ou email..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={showApprovedOnly}
                onChange={(e) => setShowApprovedOnly(e.target.checked)}
                className="w-4 h-4 rounded border-gray-300"
              />
              <span className="text-sm text-gray-600">Approuvés uniquement</span>
            </label>
            {filterKind !== 'all' && (
              <Button variant="outline" size="sm" onClick={() => setFilterKind('all')}>
                Voir tous
              </Button>
            )}
          </div>
        </Card>

        {/* Commissions List */}
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Professionnel
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Type
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Commission
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-gray-500">
                      Chargement...
                    </td>
                  </tr>
                ) : filteredProviders.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-gray-500">
                      Aucun professionnel trouvé
                    </td>
                  </tr>
                ) : (
                  filteredProviders.map((provider) => {
                    const isEditing = editingId === provider.providerId;
                    const isCustom = isCustomCommission(provider);
                    const kindInfo = kindLabels[provider.kind] || {
                      label: 'Inconnu',
                      color: 'text-gray-700',
                      bgColor: 'bg-gray-100',
                      icon: Stethoscope
                    };
                    const IconComponent = kindInfo.icon;

                    return (
                      <tr key={provider.providerId} className="transition-colors hover:bg-gray-50">
                        <td className="px-4 py-4">
                          <div className="flex items-center gap-3">
                            <div className={`w-10 h-10 rounded-full ${kindInfo.bgColor} flex items-center justify-center`}>
                              <IconComponent className={`w-5 h-5 ${kindInfo.color}`} />
                            </div>
                            <div>
                              <p className="font-medium text-gray-900">
                                {provider.displayName}
                              </p>
                              <p className="text-sm text-gray-500">{provider.email}</p>
                            </div>
                          </div>
                        </td>

                        {/* Type */}
                        <td className="px-4 py-4 text-center">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${kindInfo.bgColor} ${kindInfo.color}`}>
                            {kindInfo.label}
                          </span>
                        </td>

                        {/* Commission based on type */}
                        <td className="px-4 py-4">
                          {provider.kind === 'vet' && (
                            <div className="text-center">
                              {isEditing ? (
                                <div className="flex items-center justify-center gap-2">
                                  <Input
                                    type="number"
                                    value={editForm.vetCommissionDa}
                                    onChange={(e) =>
                                      setEditForm({ ...editForm, vetCommissionDa: parseInt(e.target.value) || 0 })
                                    }
                                    className="w-20 text-center"
                                    min={0}
                                  />
                                  <span className="text-sm text-gray-500">DA/RDV</span>
                                </div>
                              ) : (
                                <div>
                                  <span className={`font-medium ${isCustom ? 'text-amber-600' : 'text-gray-900'}`}>
                                    {provider.vetCommissionDa} DA
                                  </span>
                                  <p className="text-xs text-gray-400">par RDV confirmé</p>
                                  {isCustom && (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800 mt-1">
                                      Personnalisée
                                    </span>
                                  )}
                                </div>
                              )}
                            </div>
                          )}

                          {provider.kind === 'daycare' && (
                            <div className="text-center space-y-2">
                              {isEditing ? (
                                <div className="space-y-2">
                                  <div className="flex items-center justify-center gap-2">
                                    <Input
                                      type="number"
                                      value={editForm.daycareHourlyCommissionDa}
                                      onChange={(e) =>
                                        setEditForm({
                                          ...editForm,
                                          daycareHourlyCommissionDa: parseInt(e.target.value) || 0,
                                        })
                                      }
                                      className="w-20 text-center"
                                      min={0}
                                    />
                                    <span className="text-sm text-gray-500">DA/h</span>
                                  </div>
                                  <div className="flex items-center justify-center gap-2">
                                    <Input
                                      type="number"
                                      value={editForm.daycareDailyCommissionDa}
                                      onChange={(e) =>
                                        setEditForm({
                                          ...editForm,
                                          daycareDailyCommissionDa: parseInt(e.target.value) || 0,
                                        })
                                      }
                                      className="w-20 text-center"
                                      min={0}
                                    />
                                    <span className="text-sm text-gray-500">DA/j</span>
                                  </div>
                                </div>
                              ) : (
                                <div>
                                  <div className={`font-medium ${isCustom ? 'text-amber-600' : 'text-gray-900'}`}>
                                    {provider.daycareHourlyCommissionDa} DA/h
                                  </div>
                                  <div className={`font-medium ${isCustom ? 'text-amber-600' : 'text-gray-900'}`}>
                                    {provider.daycareDailyCommissionDa} DA/jour
                                  </div>
                                  {isCustom && (
                                    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800 mt-1">
                                      Personnalisée
                                    </span>
                                  )}
                                </div>
                              )}
                            </div>
                          )}

                          {provider.kind === 'petshop' && (
                            <div className="text-center text-gray-400 text-sm italic">
                              À définir
                            </div>
                          )}
                        </td>

                        {/* Actions */}
                        <td className="px-4 py-4">
                          <div className="flex items-center justify-center gap-2">
                            {provider.kind !== 'petshop' && (
                              <>
                                {isEditing ? (
                                  <>
                                    <Button
                                      size="sm"
                                      onClick={() => handleSave(provider)}
                                      disabled={saving}
                                      className="bg-green-500 hover:bg-green-600 text-white"
                                    >
                                      <Save className="w-4 h-4" />
                                    </Button>
                                    <Button
                                      size="sm"
                                      variant="outline"
                                      onClick={handleCancel}
                                      disabled={saving}
                                    >
                                      Annuler
                                    </Button>
                                  </>
                                ) : (
                                  <>
                                    <Button
                                      size="sm"
                                      variant="outline"
                                      onClick={() => handleEdit(provider)}
                                    >
                                      Modifier
                                    </Button>
                                    {isCustom && (
                                      <Button
                                        size="sm"
                                        variant="ghost"
                                        onClick={() => handleReset(provider.providerId)}
                                        title="Réinitialiser"
                                        className="text-gray-500 hover:text-gray-700"
                                      >
                                        <RotateCcw className="w-4 h-4" />
                                      </Button>
                                    )}
                                  </>
                                )}
                              </>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </Card>

        {/* Info box */}
        <Card className="mt-6 p-4 bg-blue-50 border-blue-200">
          <h3 className="font-medium text-blue-900 mb-2">Information sur les commissions</h3>
          <ul className="text-sm text-blue-800 space-y-1">
            <li>• <strong>Vétérinaire:</strong> Commission fixe prélevée par RDV confirmé (défaut: 100 DA)</li>
            <li>• <strong>Garderie:</strong> Commission par heure (défaut: 10 DA/h) ou par jour (défaut: 100 DA/jour)</li>
            <li>• <strong>Petshop:</strong> Commissions à définir ultérieurement</li>
            <li>• Les commissions personnalisées sont marquées en orange</li>
          </ul>
        </Card>
      </div>
    </DashboardLayout>
  );
}
