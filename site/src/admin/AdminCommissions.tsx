import { useEffect, useState } from 'react';
import { Percent, Search, RotateCcw, Save, Clock, Calendar } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';

interface ProviderCommission {
  providerId: string;
  userId: string;
  displayName: string;
  email: string;
  isApproved: boolean;
  vetCommissionDa: number;
  daycareHourlyCommissionDa: number;
  daycareDailyCommissionDa: number;
}

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

  const handleSave = async (providerId: string) => {
    setSaving(true);
    try {
      await api.adminUpdateCommission(providerId, editForm);
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

  const filteredProviders = providers.filter((p) =>
    p.displayName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    p.email?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Calculate totals
  const totalProviders = providers.length;
  const customCommissionCount = providers.filter(
    (p) => p.vetCommissionDa !== 100 || p.daycareHourlyCommissionDa !== 10 || p.daycareDailyCommissionDa !== 100
  ).length;

  return (
    <DashboardLayout>
      <div className="p-6 max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center gap-2">
            <Percent className="w-7 h-7 text-coral-500" />
            Gestion des Commissions
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-1">
            Configurez les commissions personnalisées pour chaque professionnel
          </p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                <Percent className="w-5 h-5 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Total Professionnels</p>
                <p className="text-xl font-bold">{totalProviders}</p>
              </div>
            </div>
          </Card>
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-amber-100 dark:bg-amber-900/30 rounded-lg">
                <Clock className="w-5 h-5 text-amber-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Commissions Personnalisées</p>
                <p className="text-xl font-bold">{customCommissionCount}</p>
              </div>
            </div>
          </Card>
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-green-100 dark:bg-green-900/30 rounded-lg">
                <Calendar className="w-5 h-5 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-500 dark:text-gray-400">Commission Standard</p>
                <p className="text-xl font-bold">{totalProviders - customCommissionCount}</p>
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
              <span className="text-sm text-gray-600 dark:text-gray-400">Approuvés uniquement</span>
            </label>
          </div>
        </Card>

        {/* Commissions List */}
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 dark:bg-gray-800/50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Professionnel
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Vétérinaire<br /><span className="text-[10px] normal-case">(par RDV)</span>
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Garderie Horaire<br /><span className="text-[10px] normal-case">(par heure)</span>
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Garderie Journalière<br /><span className="text-[10px] normal-case">(par jour)</span>
                  </th>
                  <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {loading ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                      Chargement...
                    </td>
                  </tr>
                ) : filteredProviders.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                      Aucun professionnel trouvé
                    </td>
                  </tr>
                ) : (
                  filteredProviders.map((provider) => {
                    const isEditing = editingId === provider.providerId;
                    const isCustom =
                      provider.vetCommissionDa !== 100 ||
                      provider.daycareHourlyCommissionDa !== 10 ||
                      provider.daycareDailyCommissionDa !== 100;

                    return (
                      <tr key={provider.providerId} className="hover:bg-gray-50 dark:hover:bg-gray-800/50">
                        <td className="px-4 py-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-rose-400 to-orange-400 flex items-center justify-center text-white font-medium">
                              {provider.displayName?.charAt(0)?.toUpperCase() || '?'}
                            </div>
                            <div>
                              <p className="font-medium text-gray-900 dark:text-white">
                                {provider.displayName}
                              </p>
                              <p className="text-sm text-gray-500 dark:text-gray-400">{provider.email}</p>
                              {isCustom && (
                                <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400 mt-1">
                                  Personnalisée
                                </span>
                              )}
                            </div>
                          </div>
                        </td>

                        {/* Vet Commission */}
                        <td className="px-4 py-4 text-center">
                          {isEditing ? (
                            <Input
                              type="number"
                              value={editForm.vetCommissionDa}
                              onChange={(e) =>
                                setEditForm({ ...editForm, vetCommissionDa: parseInt(e.target.value) || 0 })
                              }
                              className="w-24 text-center mx-auto"
                              min={0}
                            />
                          ) : (
                            <span className={`font-medium ${provider.vetCommissionDa !== 100 ? 'text-amber-600' : ''}`}>
                              {provider.vetCommissionDa} DA
                            </span>
                          )}
                        </td>

                        {/* Daycare Hourly */}
                        <td className="px-4 py-4 text-center">
                          {isEditing ? (
                            <Input
                              type="number"
                              value={editForm.daycareHourlyCommissionDa}
                              onChange={(e) =>
                                setEditForm({
                                  ...editForm,
                                  daycareHourlyCommissionDa: parseInt(e.target.value) || 0,
                                })
                              }
                              className="w-24 text-center mx-auto"
                              min={0}
                            />
                          ) : (
                            <span
                              className={`font-medium ${provider.daycareHourlyCommissionDa !== 10 ? 'text-amber-600' : ''}`}
                            >
                              {provider.daycareHourlyCommissionDa} DA/h
                            </span>
                          )}
                        </td>

                        {/* Daycare Daily */}
                        <td className="px-4 py-4 text-center">
                          {isEditing ? (
                            <Input
                              type="number"
                              value={editForm.daycareDailyCommissionDa}
                              onChange={(e) =>
                                setEditForm({
                                  ...editForm,
                                  daycareDailyCommissionDa: parseInt(e.target.value) || 0,
                                })
                              }
                              className="w-24 text-center mx-auto"
                              min={0}
                            />
                          ) : (
                            <span
                              className={`font-medium ${provider.daycareDailyCommissionDa !== 100 ? 'text-amber-600' : ''}`}
                            >
                              {provider.daycareDailyCommissionDa} DA/j
                            </span>
                          )}
                        </td>

                        {/* Actions */}
                        <td className="px-4 py-4">
                          <div className="flex items-center justify-center gap-2">
                            {isEditing ? (
                              <>
                                <Button
                                  size="sm"
                                  onClick={() => handleSave(provider.providerId)}
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
        <Card className="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800">
          <h3 className="font-medium text-blue-900 dark:text-blue-100 mb-2">Information sur les commissions</h3>
          <ul className="text-sm text-blue-800 dark:text-blue-200 space-y-1">
            <li>• <strong>Vétérinaire:</strong> Commission fixe prélevée par RDV confirmé (défaut: 100 DA)</li>
            <li>• <strong>Garderie Horaire:</strong> Commission par heure de garde (défaut: 10 DA/h)</li>
            <li>• <strong>Garderie Journalière:</strong> Commission par jour complet de garde (défaut: 100 DA/jour)</li>
            <li>• Les commissions personnalisées sont marquées en orange</li>
          </ul>
        </Card>
      </div>
    </DashboardLayout>
  );
}
