import { useEffect, useState } from 'react';
import { Plus, Trash2, Calendar, Save } from 'lucide-react';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { ProviderTimeOff } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

const WEEKDAYS = [
  { value: 1, label: 'Lundi' },
  { value: 2, label: 'Mardi' },
  { value: 3, label: 'Mercredi' },
  { value: 4, label: 'Jeudi' },
  { value: 5, label: 'Vendredi' },
  { value: 6, label: 'Samedi' },
  { value: 0, label: 'Dimanche' },
];

interface AvailabilitySlot {
  weekday: number;
  startTime: string;
  endTime: string;
}

export function ProAvailability() {
  const [availability, setAvailability] = useState<AvailabilitySlot[]>([]);
  const [timeOffs, setTimeOffs] = useState<ProviderTimeOff[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showTimeOffModal, setShowTimeOffModal] = useState(false);
  const [newTimeOff, setNewTimeOff] = useState({
    startsAt: '',
    endsAt: '',
    reason: '',
  });

  useEffect(() => {
    fetchData();
  }, []);

  async function fetchData() {
    setLoading(true);
    try {
      const [weekly, offs] = await Promise.all([api.myWeekly(), api.myTimeOffs()]);
      const slots = weekly.map((w) => ({
        weekday: w.weekday,
        startTime: w.startTime,
        endTime: w.endTime,
      }));
      setAvailability(slots);
      setTimeOffs(offs);
    } catch (error) {
      console.error('Error fetching availability:', error);
    } finally {
      setLoading(false);
    }
  }

  const handleAddSlot = (weekday: number) => {
    setAvailability((prev) => [
      ...prev,
      { weekday, startTime: '09:00', endTime: '17:00' },
    ]);
  };

  const handleRemoveSlot = (weekday: number, index: number) => {
    const daySlots = availability.filter((s) => s.weekday === weekday);
    const slotToRemove = daySlots[index];
    setAvailability((prev) => prev.filter((s) => s !== slotToRemove));
  };

  const handleSlotChange = (
    weekday: number,
    index: number,
    field: 'startTime' | 'endTime',
    value: string
  ) => {
    const daySlots = availability.filter((s) => s.weekday === weekday);
    const slotToUpdate = daySlots[index];

    setAvailability((prev) =>
      prev.map((s) => (s === slotToUpdate ? { ...s, [field]: value } : s))
    );
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await api.setWeekly(availability);
      alert('Disponibilités enregistrées !');
    } catch (error) {
      console.error('Error saving availability:', error);
      alert('Erreur lors de l\'enregistrement');
    } finally {
      setSaving(false);
    }
  };

  const handleAddTimeOff = async () => {
    if (!newTimeOff.startsAt || !newTimeOff.endsAt) return;

    try {
      const off = await api.addTimeOff(
        new Date(newTimeOff.startsAt).toISOString(),
        new Date(newTimeOff.endsAt).toISOString(),
        newTimeOff.reason || undefined
      );
      setTimeOffs((prev) => [...prev, off]);
      setShowTimeOffModal(false);
      setNewTimeOff({ startsAt: '', endsAt: '', reason: '' });
    } catch (error) {
      console.error('Error adding time off:', error);
    }
  };

  const handleDeleteTimeOff = async (id: string) => {
    try {
      await api.deleteMyTimeOff(id);
      setTimeOffs((prev) => prev.filter((t) => t.id !== id));
    } catch (error) {
      console.error('Error deleting time off:', error);
    }
  };

  const getSlotsForDay = (weekday: number) => {
    return availability.filter((s) => s.weekday === weekday);
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

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Disponibilités</h1>
            <p className="text-gray-600 mt-1">Gérez vos horaires de travail</p>
          </div>
          <Button onClick={handleSave} isLoading={saving}>
            <Save size={16} className="mr-2" />
            Enregistrer
          </Button>
        </div>

        {/* Weekly availability */}
        <Card>
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Horaires hebdomadaires</h2>

          <div className="space-y-4">
            {WEEKDAYS.map((day) => {
              const daySlots = getSlotsForDay(day.value);

              return (
                <div
                  key={day.value}
                  className="flex flex-col md:flex-row md:items-start gap-4 pb-4 border-b border-gray-100 last:border-0"
                >
                  <div className="w-24 font-medium text-gray-900">{day.label}</div>

                  <div className="flex-1 space-y-2">
                    {daySlots.length === 0 ? (
                      <p className="text-sm text-gray-500">Non disponible</p>
                    ) : (
                      daySlots.map((slot, index) => (
                        <div key={index} className="flex items-center space-x-2">
                          <input
                            type="time"
                            value={slot.startTime}
                            onChange={(e) =>
                              handleSlotChange(day.value, index, 'startTime', e.target.value)
                            }
                            className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                          />
                          <span className="text-gray-500">à</span>
                          <input
                            type="time"
                            value={slot.endTime}
                            onChange={(e) =>
                              handleSlotChange(day.value, index, 'endTime', e.target.value)
                            }
                            className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                          />
                          <button
                            onClick={() => handleRemoveSlot(day.value, index)}
                            className="p-2 text-red-500 hover:bg-red-50 rounded-lg"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      ))
                    )}
                  </div>

                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleAddSlot(day.value)}
                  >
                    <Plus size={16} className="mr-1" />
                    Ajouter
                  </Button>
                </div>
              );
            })}
          </div>
        </Card>

        {/* Time offs */}
        <Card>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Congés et absences</h2>
            <Button size="sm" onClick={() => setShowTimeOffModal(true)}>
              <Plus size={16} className="mr-2" />
              Ajouter une absence
            </Button>
          </div>

          {timeOffs.length === 0 ? (
            <p className="text-gray-500 text-sm">Aucune absence planifiée</p>
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
                        {format(new Date(off.startsAt), 'dd MMM yyyy', { locale: fr })}
                        {' - '}
                        {format(new Date(off.endsAt), 'dd MMM yyyy', { locale: fr })}
                      </p>
                      {off.reason && <p className="text-sm text-gray-500">{off.reason}</p>}
                    </div>
                  </div>
                  <button
                    onClick={() => handleDeleteTimeOff(off.id)}
                    className="p-2 text-red-500 hover:bg-red-50 rounded-lg"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

      {/* Time off modal */}
      {showTimeOffModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-xl font-semibold text-gray-900 mb-6">Ajouter une absence</h2>

            <div className="space-y-4">
              <div>
                <Input
                  type="datetime-local"
                  label="Début"
                  value={newTimeOff.startsAt}
                  onChange={(e) =>
                    setNewTimeOff((prev) => ({ ...prev, startsAt: e.target.value }))
                  }
                />
              </div>

              <div>
                <Input
                  type="datetime-local"
                  label="Fin"
                  value={newTimeOff.endsAt}
                  onChange={(e) =>
                    setNewTimeOff((prev) => ({ ...prev, endsAt: e.target.value }))
                  }
                />
              </div>

              <div>
                <Input
                  label="Raison (optionnelle)"
                  placeholder="Ex: Vacances, Conférence..."
                  value={newTimeOff.reason}
                  onChange={(e) =>
                    setNewTimeOff((prev) => ({ ...prev, reason: e.target.value }))
                  }
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
