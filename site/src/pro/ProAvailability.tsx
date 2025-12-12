import { useEffect, useState } from 'react';
import { Plus, Trash2, Calendar, Save, RefreshCw } from 'lucide-react';
import { Card, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderTimeOff } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

// Weekdays: 1 = Lundi, 7 = Dimanche (like backend)
const WEEKDAYS = [
  { value: 1, label: 'Lundi', short: 'Lun' },
  { value: 2, label: 'Mardi', short: 'Mar' },
  { value: 3, label: 'Mercredi', short: 'Mer' },
  { value: 4, label: 'Jeudi', short: 'Jeu' },
  { value: 5, label: 'Vendredi', short: 'Ven' },
  { value: 6, label: 'Samedi', short: 'Sam' },
  { value: 7, label: 'Dimanche', short: 'Dim' },
];

interface AvailabilitySlot {
  weekday: number;
  startMin: number;
  endMin: number;
}

// Convert minutes to HH:mm string
function minToTime(min: number): string {
  const h = Math.floor(min / 60);
  const m = min % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
}

// Convert HH:mm string to minutes
function timeToMin(time: string): number {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
}

export function ProAvailability() {
  const [selectedDay, setSelectedDay] = useState(1);
  const [availability, setAvailability] = useState<AvailabilitySlot[]>([]);
  const [timeOffs, setTimeOffs] = useState<ProviderTimeOff[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [activeTab, setActiveTab] = useState<'weekly' | 'timeoffs'>('weekly');
  const [showTimeOffModal, setShowTimeOffModal] = useState(false);
  const [newTimeOff, setNewTimeOff] = useState({
    startDate: '',
    endDate: '',
    startTime: '00:00',
    endTime: '23:59',
    reason: '',
  });

  useEffect(() => {
    fetchData();
  }, []);

  async function fetchData() {
    setLoading(true);
    try {
      const [weeklyResult, offs] = await Promise.all([
        api.myWeekly(),
        api.myTimeOffs(),
      ]);

      // Parse entries from API response (may have startMin/endMin or startTime/endTime)
      const entries = weeklyResult.entries || [];
      const slots: AvailabilitySlot[] = entries.map((e) => ({
        weekday: e.weekday,
        startMin: e.startMin ?? (e.startTime ? timeToMin(e.startTime) : 0),
        endMin: e.endMin ?? (e.endTime ? timeToMin(e.endTime) : 0),
      }));

      console.log('Loaded availability:', slots);
      setAvailability(slots);
      setTimeOffs(offs);
    } catch (error) {
      console.error('Error fetching availability:', error);
    } finally {
      setLoading(false);
    }
  }

  const getSlotsForDay = (weekday: number) => {
    return availability.filter((s) => s.weekday === weekday);
  };

  const handleAddSlot = (weekday: number) => {
    setAvailability((prev) => [
      ...prev,
      { weekday, startMin: 9 * 60, endMin: 12 * 60 }, // Default 9:00 - 12:00
    ]);
  };

  const handleRemoveSlot = (weekday: number, index: number) => {
    const daySlots = getSlotsForDay(weekday);
    const slotToRemove = daySlots[index];
    setAvailability((prev) =>
      prev.filter(
        (s) =>
          !(s.weekday === slotToRemove.weekday &&
            s.startMin === slotToRemove.startMin &&
            s.endMin === slotToRemove.endMin)
      )
    );
  };

  const handleSlotChange = (
    weekday: number,
    index: number,
    field: 'startMin' | 'endMin',
    timeValue: string
  ) => {
    const daySlots = getSlotsForDay(weekday);
    const slotToUpdate = daySlots[index];
    const minValue = timeToMin(timeValue);

    setAvailability((prev) =>
      prev.map((s) =>
        s.weekday === slotToUpdate.weekday &&
        s.startMin === slotToUpdate.startMin &&
        s.endMin === slotToUpdate.endMin
          ? { ...s, [field]: minValue }
          : s
      )
    );
  };

  const handlePreset = (preset: 'morning' | 'afternoon' | 'fullday' | 'closed' | 'copyAll') => {
    if (preset === 'morning') {
      setAvailability((prev) => [
        ...prev.filter((s) => s.weekday !== selectedDay),
        { weekday: selectedDay, startMin: 9 * 60, endMin: 12 * 60 },
      ]);
    } else if (preset === 'afternoon') {
      setAvailability((prev) => [
        ...prev.filter((s) => s.weekday !== selectedDay),
        { weekday: selectedDay, startMin: 14 * 60, endMin: 18 * 60 },
      ]);
    } else if (preset === 'fullday') {
      setAvailability((prev) => [
        ...prev.filter((s) => s.weekday !== selectedDay),
        { weekday: selectedDay, startMin: 9 * 60, endMin: 18 * 60 },
      ]);
    } else if (preset === 'closed') {
      setAvailability((prev) => prev.filter((s) => s.weekday !== selectedDay));
    } else if (preset === 'copyAll') {
      const currentSlots = getSlotsForDay(selectedDay);
      const newSlots: AvailabilitySlot[] = [];
      WEEKDAYS.forEach((day) => {
        if (day.value !== selectedDay) {
          currentSlots.forEach((slot) => {
            newSlots.push({
              weekday: day.value,
              startMin: slot.startMin,
              endMin: slot.endMin,
            });
          });
        }
      });
      setAvailability((prev) => [
        ...prev.filter((s) => s.weekday === selectedDay),
        ...newSlots,
      ]);
      alert('Horaires copiés sur tous les jours');
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const payload = availability.map((s) => ({
        weekday: s.weekday,
        startMin: s.startMin,
        endMin: s.endMin,
      }));
      console.log('Saving availability:', payload);
      await api.setWeekly(payload);
      alert('Disponibilités enregistrées !');
      await fetchData();
    } catch (error) {
      console.error('Error saving availability:', error);
      alert("Erreur lors de l'enregistrement");
    } finally {
      setSaving(false);
    }
  };

  const handleClearAll = async () => {
    if (!confirm('Voulez-vous vraiment vider toutes les disponibilités ?')) return;
    setSaving(true);
    try {
      await api.setWeekly([]);
      setAvailability([]);
      alert('Disponibilités vidées');
    } catch (error) {
      console.error('Error clearing availability:', error);
    } finally {
      setSaving(false);
    }
  };

  const handleAddTimeOff = async () => {
    if (!newTimeOff.startDate || !newTimeOff.endDate) {
      alert('Veuillez sélectionner une plage de dates');
      return;
    }

    try {
      const startDateTime = new Date(`${newTimeOff.startDate}T${newTimeOff.startTime}`);
      const endDateTime = new Date(`${newTimeOff.endDate}T${newTimeOff.endTime}`);

      await api.addTimeOff(
        startDateTime.toISOString(),
        endDateTime.toISOString(),
        newTimeOff.reason || undefined
      );

      await fetchData();
      setShowTimeOffModal(false);
      setNewTimeOff({
        startDate: '',
        endDate: '',
        startTime: '00:00',
        endTime: '23:59',
        reason: '',
      });
      alert('Indisponibilité ajoutée');
    } catch (error) {
      console.error('Error adding time off:', error);
      alert("Erreur lors de l'ajout");
    }
  };

  const handleDeleteTimeOff = async (id: string) => {
    if (!confirm('Supprimer cette indisponibilité ?')) return;
    try {
      await api.deleteMyTimeOff(id);
      setTimeOffs((prev) => prev.filter((t) => t.id !== id));
    } catch (error) {
      console.error('Error deleting time off:', error);
    }
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

  const currentDaySlots = getSlotsForDay(selectedDay);

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Disponibilités</h1>
            <p className="text-gray-600 mt-1">Gérez vos horaires de travail</p>
          </div>
          <Button variant="secondary" onClick={fetchData}>
            <RefreshCw size={16} className="mr-2" />
            Actualiser
          </Button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-gray-200">
          <button
            className={`py-3 px-6 font-medium ${
              activeTab === 'weekly'
                ? 'border-b-2 border-primary-600 text-primary-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('weekly')}
          >
            Hebdomadaire
          </button>
          <button
            className={`py-3 px-6 font-medium ${
              activeTab === 'timeoffs'
                ? 'border-b-2 border-primary-600 text-primary-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('timeoffs')}
          >
            Indisponibilités
          </button>
        </div>

        {activeTab === 'weekly' && (
          <>
            {/* Day selector */}
            <div className="flex flex-wrap gap-2">
              {WEEKDAYS.map((day) => {
                const count = getSlotsForDay(day.value).length;
                return (
                  <button
                    key={day.value}
                    onClick={() => setSelectedDay(day.value)}
                    className={`px-4 py-2 rounded-lg font-medium flex items-center gap-2 ${
                      selectedDay === day.value
                        ? 'bg-primary-600 text-white'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    }`}
                  >
                    {day.short}
                    {count > 0 && (
                      <span
                        className={`px-2 py-0.5 text-xs rounded-full ${
                          selectedDay === day.value
                            ? 'bg-primary-500 text-white'
                            : 'bg-gray-200 text-gray-600'
                        }`}
                      >
                        {count}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Presets */}
            <Card>
              <h3 className="font-medium text-gray-700 mb-3">Raccourcis</h3>
              <div className="flex flex-wrap gap-2">
                <Button variant="secondary" size="sm" onClick={() => handlePreset('morning')}>
                  9h–12h
                </Button>
                <Button variant="secondary" size="sm" onClick={() => handlePreset('afternoon')}>
                  14h–18h
                </Button>
                <Button variant="secondary" size="sm" onClick={() => handlePreset('fullday')}>
                  Journée 9h–18h
                </Button>
                <Button variant="secondary" size="sm" onClick={() => handlePreset('closed')}>
                  Fermé
                </Button>
                <Button variant="secondary" size="sm" onClick={() => handlePreset('copyAll')}>
                  Copier sur tous
                </Button>
              </div>
            </Card>

            {/* Current day slots */}
            <Card>
              <h3 className="font-medium text-gray-900 mb-4">
                Créneaux du {WEEKDAYS.find((d) => d.value === selectedDay)?.label}
              </h3>

              {currentDaySlots.length === 0 ? (
                <p className="text-gray-500 text-sm mb-4">Aucun créneau (fermé)</p>
              ) : (
                <div className="space-y-3 mb-4">
                  {currentDaySlots.map((slot, index) => {
                    const isInvalid = slot.endMin <= slot.startMin;
                    return (
                      <div
                        key={index}
                        className={`flex items-center gap-3 p-3 rounded-lg ${
                          isInvalid ? 'bg-red-50 border border-red-200' : 'bg-gray-50'
                        }`}
                      >
                        <div className="flex items-center gap-2">
                          <span className="text-sm text-gray-600">Début</span>
                          <input
                            type="time"
                            value={minToTime(slot.startMin)}
                            onChange={(e) =>
                              handleSlotChange(selectedDay, index, 'startMin', e.target.value)
                            }
                            className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                          />
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-sm text-gray-600">Fin</span>
                          <input
                            type="time"
                            value={minToTime(slot.endMin)}
                            onChange={(e) =>
                              handleSlotChange(selectedDay, index, 'endMin', e.target.value)
                            }
                            className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                          />
                        </div>
                        <button
                          onClick={() => handleRemoveSlot(selectedDay, index)}
                          className="p-2 text-red-500 hover:bg-red-100 rounded-lg"
                        >
                          <Trash2 size={18} />
                        </button>
                        {isInvalid && (
                          <span className="text-red-500 text-sm">Heure fin invalide</span>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}

              <Button variant="secondary" onClick={() => handleAddSlot(selectedDay)}>
                <Plus size={16} className="mr-2" />
                Ajouter un créneau
              </Button>
            </Card>

            {/* Save buttons */}
            <div className="flex gap-3">
              <Button onClick={handleSave} isLoading={saving} className="flex-1">
                <Save size={16} className="mr-2" />
                Enregistrer
              </Button>
              <Button variant="secondary" onClick={handleClearAll} disabled={saving}>
                Tout vider
              </Button>
            </div>
          </>
        )}

        {activeTab === 'timeoffs' && (
          <Card>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Indisponibilités</h2>
              <Button size="sm" onClick={() => setShowTimeOffModal(true)}>
                <Plus size={16} className="mr-2" />
                Ajouter
              </Button>
            </div>

            {timeOffs.length === 0 ? (
              <p className="text-gray-500 text-sm">Aucune indisponibilité</p>
            ) : (
              <div className="space-y-3">
                {timeOffs.map((off) => (
                  <div
                    key={off.id}
                    className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                  >
                    <div className="flex items-center space-x-4">
                      <div className="p-2 bg-red-100 rounded-lg">
                        <Calendar size={20} className="text-red-600" />
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">
                          {format(new Date(off.startsAt), "EEE d MMM yyyy 'à' HH:mm", { locale: fr })}
                          {' → '}
                          {format(new Date(off.endsAt), "EEE d MMM yyyy 'à' HH:mm", { locale: fr })}
                        </p>
                        {off.reason && <p className="text-sm text-gray-500">{off.reason}</p>}
                      </div>
                    </div>
                    <button
                      onClick={() => handleDeleteTimeOff(off.id)}
                      className="p-2 text-red-500 hover:bg-red-100 rounded-lg"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </Card>
        )}
      </div>

      {/* Time off modal */}
      {showTimeOffModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-xl font-semibold text-gray-900 mb-6">
              Ajouter une indisponibilité
            </h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Plage de dates
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="date"
                    value={newTimeOff.startDate}
                    onChange={(e) =>
                      setNewTimeOff((prev) => ({ ...prev, startDate: e.target.value }))
                    }
                    className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                  <input
                    type="date"
                    value={newTimeOff.endDate}
                    onChange={(e) =>
                      setNewTimeOff((prev) => ({ ...prev, endDate: e.target.value }))
                    }
                    className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Heures</label>
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="time"
                    value={newTimeOff.startTime}
                    onChange={(e) =>
                      setNewTimeOff((prev) => ({ ...prev, startTime: e.target.value }))
                    }
                    className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                  <input
                    type="time"
                    value={newTimeOff.endTime}
                    onChange={(e) =>
                      setNewTimeOff((prev) => ({ ...prev, endTime: e.target.value }))
                    }
                    className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Motif (optionnel)
                </label>
                <input
                  type="text"
                  placeholder="Congés, formation..."
                  value={newTimeOff.reason}
                  onChange={(e) =>
                    setNewTimeOff((prev) => ({ ...prev, reason: e.target.value }))
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>
            </div>

            <div className="flex space-x-3 mt-6">
              <Button
                variant="secondary"
                className="flex-1"
                onClick={() => setShowTimeOffModal(false)}
              >
                Annuler
              </Button>
              <Button className="flex-1" onClick={handleAddTimeOff}>
                Ajouter
              </Button>
            </div>
          </Card>
        </div>
      )}
    </DashboardLayout>
  );
}
