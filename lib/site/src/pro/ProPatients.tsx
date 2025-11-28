import { useEffect, useState, useRef } from 'react';
import {
  Search,
  User,
  FileText,
  Syringe,
  QrCode,
  X,
  RefreshCw,
  Plus,
  Clock,
  Calendar,
} from 'lucide-react';
import { Html5Qrcode } from 'html5-qrcode';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Pet, MedicalRecord, Vaccination, Booking } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

// Patient aggregated from bookings
interface PatientRow {
  keyId: string;
  name: string;
  phone: string;
  lastPet: string;
  visits: number;
  lastAt: Date | null;
  email: string;
}

export function ProPatients() {
  const [patients, setPatients] = useState<PatientRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedPatient, setSelectedPatient] = useState<PatientRow | null>(null);
  const [patientBookings, setPatientBookings] = useState<Booking[]>([]);
  const [showHistoryModal, setShowHistoryModal] = useState(false);

  // QR Scanner state
  const [showQrScanner, setShowQrScanner] = useState(false);
  const [scannedPet, setScannedPet] = useState<Pet | null>(null);
  const [scannedRecords, setScannedRecords] = useState<MedicalRecord[]>([]);
  const [scannedVaccinations, setScannedVaccinations] = useState<Vaccination[]>([]);
  const [currentToken, setCurrentToken] = useState<string | null>(null);
  const [qrError, setQrError] = useState<string | null>(null);
  const scannerRef = useRef<Html5Qrcode | null>(null);

  // Add record modal
  const [showAddRecordModal, setShowAddRecordModal] = useState(false);
  const [newRecord, setNewRecord] = useState({
    title: '',
    type: 'CONSULTATION',
    description: '',
  });
  const [addingRecord, setAddingRecord] = useState(false);

  // All bookings for history
  const [allBookings, setAllBookings] = useState<Booking[]>([]);

  useEffect(() => {
    fetchPatients();
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(() => {});
      }
    };
  }, []);

  async function fetchPatients() {
    setLoading(true);
    try {
      // Get all provider bookings
      const now = new Date();
      const fromDate = new Date(now.getFullYear() - 2, 0, 1);
      const bookings = await api.providerAgenda(
        fromDate.toISOString().split('T')[0],
        now.toISOString().split('T')[0]
      );

      setAllBookings(bookings);

      // Aggregate patients from bookings
      const patientMap = new Map<string, PatientRow>();

      bookings.forEach((booking) => {
        const status = (booking.status || '').toUpperCase();
        if (status !== 'CONFIRMED' && status !== 'COMPLETED') return;

        const user = booking.user || {};
        const userId = user.id || booking.userId || user.email || '';
        if (!userId) return;

        const name = getHumanName(user);
        const phone = user.phone || '';
        const email = user.email || '';

        const scheduledAt = booking.scheduledAt
          ? new Date(booking.scheduledAt)
          : null;

        const petLabel = booking.pet
          ? `${booking.pet.idNumber || booking.pet.species || ''} (${booking.pet.name || ''})`
          : '';

        const existing = patientMap.get(userId);
        if (!existing) {
          patientMap.set(userId, {
            keyId: userId,
            name,
            phone,
            email,
            lastPet: petLabel,
            visits: 1,
            lastAt: scheduledAt,
          });
        } else {
          const newer =
            !existing.lastAt ||
            (scheduledAt && scheduledAt > existing.lastAt);
          patientMap.set(userId, {
            ...existing,
            visits: existing.visits + 1,
            lastAt: newer ? scheduledAt : existing.lastAt,
            lastPet: newer && petLabel ? petLabel : existing.lastPet,
            phone: existing.phone || phone,
          });
        }
      });

      const rows = Array.from(patientMap.values()).sort((a, b) => {
        if (a.lastAt && b.lastAt) return b.lastAt.getTime() - a.lastAt.getTime();
        return a.name.localeCompare(b.name);
      });

      setPatients(rows);
    } catch (error) {
      console.error('Error fetching patients:', error);
    } finally {
      setLoading(false);
    }
  }

  function getHumanName(user: { displayName?: string; firstName?: string; lastName?: string; email?: string }): string {
    if (user.displayName) return user.displayName;
    const fullName = `${user.firstName || ''} ${user.lastName || ''}`.trim();
    if (fullName) return fullName;
    return user.email?.split('@')[0] || 'Client';
  }

  const handleShowHistory = (patient: PatientRow) => {
    setSelectedPatient(patient);
    const bookings = allBookings.filter((b) => {
      const userId = b.user?.id || b.userId || b.user?.email || '';
      const status = (b.status || '').toUpperCase();
      return userId === patient.keyId && (status === 'CONFIRMED' || status === 'COMPLETED');
    });
    setPatientBookings(bookings.sort((a, b) => {
      const dateA = new Date(a.scheduledAt || 0);
      const dateB = new Date(b.scheduledAt || 0);
      return dateB.getTime() - dateA.getTime();
    }));
    setShowHistoryModal(true);
  };

  // QR Scanner functions
  const startQrScanner = async () => {
    setShowQrScanner(true);
    setQrError(null);

    setTimeout(async () => {
      try {
        const scanner = new Html5Qrcode('qr-reader');
        scannerRef.current = scanner;

        await scanner.start(
          { facingMode: 'environment' },
          {
            fps: 10,
            qrbox: { width: 250, height: 250 },
          },
          async (decodedText) => {
            // Stop scanner
            await scanner.stop();
            scannerRef.current = null;

            // Process QR code
            handleQrResult(decodedText);
          },
          () => {}
        );
      } catch (err) {
        console.error('QR Scanner error:', err);
        setQrError("Impossible d'accéder à la caméra");
      }
    }, 100);
  };

  const stopQrScanner = () => {
    if (scannerRef.current) {
      scannerRef.current.stop().catch(() => {});
      scannerRef.current = null;
    }
    setShowQrScanner(false);
    setQrError(null);
  };

  const handleQrResult = async (text: string) => {
    // Extract token from URL or use directly
    let token = text;
    if (text.includes('/pet/')) {
      token = text.split('/pet/').pop() || text;
    } else if (text.includes('token=')) {
      token = text.split('token=').pop() || text;
    }

    setCurrentToken(token);
    setShowQrScanner(false);

    try {
      const result = await api.getPetByToken(token);
      console.log('Pet by token result:', result);
      setScannedPet(result.pet);
      setScannedRecords(result.medicalRecords || []);
      setScannedVaccinations(result.vaccinations || []);
    } catch (error) {
      console.error('Error fetching pet by token:', error);
      alert('QR code invalide ou expiré');
    }
  };

  const handleAddRecord = async () => {
    if (!currentToken || !newRecord.title) return;

    setAddingRecord(true);
    try {
      const record = await api.createMedicalRecordByToken(currentToken, {
        title: newRecord.title,
        type: newRecord.type,
        description: newRecord.description || undefined,
      });
      setScannedRecords((prev) => [record, ...prev]);
      setShowAddRecordModal(false);
      setNewRecord({ title: '', type: 'CONSULTATION', description: '' });
      alert('Enregistrement ajouté !');
    } catch (error) {
      console.error('Error adding record:', error);
      alert("Erreur lors de l'ajout");
    } finally {
      setAddingRecord(false);
    }
  };

  const closePetView = () => {
    setScannedPet(null);
    setScannedRecords([]);
    setScannedVaccinations([]);
    setCurrentToken(null);
  };

  const filteredPatients = patients.filter((p) => {
    const query = searchQuery.toLowerCase();
    return (
      p.name.toLowerCase().includes(query) ||
      p.phone.toLowerCase().includes(query) ||
      p.lastPet.toLowerCase().includes(query)
    );
  });

  const getSpeciesEmoji = (species?: string) => {
    switch ((species || '').toUpperCase()) {
      case 'DOG':
      case 'CHIEN':
        return '🐕';
      case 'CAT':
      case 'CHAT':
        return '🐈';
      case 'BIRD':
      case 'OISEAU':
        return '🐦';
      case 'RABBIT':
      case 'LAPIN':
        return '🐰';
      default:
        return '🐾';
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Patients</h1>
            <p className="text-gray-600 mt-1">
              Consultez vos patients et scannez les QR codes
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="secondary" onClick={fetchPatients}>
              <RefreshCw size={16} className="mr-2" />
              Actualiser
            </Button>
            <Button onClick={startQrScanner}>
              <QrCode size={16} className="mr-2" />
              Scanner QR
            </Button>
          </div>
        </div>

        {/* QR Scanned Pet View */}
        {scannedPet && (
          <Card className="border-2 border-primary-500">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-primary-600">
                Carnet scanné
              </h2>
              <button onClick={closePetView} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            {/* Pet info */}
            <div className="flex items-start space-x-4 mb-6">
              <div className="w-16 h-16 bg-primary-100 rounded-xl flex items-center justify-center text-3xl">
                {getSpeciesEmoji(scannedPet.species)}
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-semibold text-gray-900">{scannedPet.name}</h3>
                <p className="text-gray-500">
                  {scannedPet.species} {scannedPet.breed && `- ${scannedPet.breed}`}
                </p>
                <div className="flex flex-wrap gap-4 mt-2 text-sm">
                  {scannedPet.gender && (
                    <span>{scannedPet.gender === 'MALE' ? '♂️ Mâle' : '♀️ Femelle'}</span>
                  )}
                  {scannedPet.birthDate && (
                    <span>🎂 {format(new Date(scannedPet.birthDate), 'dd/MM/yyyy')}</span>
                  )}
                  {scannedPet.weight && <span>⚖️ {scannedPet.weight} kg</span>}
                </div>
              </div>
            </div>

            {/* Add record button */}
            <Button onClick={() => setShowAddRecordModal(true)} className="mb-4">
              <Plus size={16} className="mr-2" />
              Ajouter un enregistrement
            </Button>

            {/* Vaccinations */}
            <div className="mb-4">
              <div className="flex items-center gap-2 mb-2">
                <Syringe size={18} className="text-green-600" />
                <h4 className="font-medium">Vaccinations</h4>
              </div>
              {scannedVaccinations.length === 0 ? (
                <p className="text-sm text-gray-500">Aucune vaccination</p>
              ) : (
                <div className="space-y-2">
                  {scannedVaccinations.slice(0, 5).map((v) => (
                    <div key={v.id} className="text-sm p-2 bg-gray-50 rounded">
                      <span className="font-medium">{v.name}</span>
                      <span className="text-gray-500 ml-2">
                        {format(new Date(v.date), 'dd/MM/yyyy')}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Medical Records */}
            <div>
              <div className="flex items-center gap-2 mb-2">
                <FileText size={18} className="text-blue-600" />
                <h4 className="font-medium">Historique médical</h4>
              </div>
              {scannedRecords.length === 0 ? (
                <p className="text-sm text-gray-500">Aucun enregistrement</p>
              ) : (
                <div className="space-y-2">
                  {scannedRecords.map((r) => (
                    <div key={r.id} className="p-3 bg-gray-50 rounded">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded">
                          {r.type}
                        </span>
                        <span className="text-xs text-gray-500">
                          {format(new Date(r.date), 'dd/MM/yyyy')}
                        </span>
                      </div>
                      <p className="font-medium">{r.title}</p>
                      {r.description && (
                        <p className="text-sm text-gray-600 mt-1">{r.description}</p>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </Card>
        )}

        {/* Search bar */}
        <Card>
          <div className="relative">
            <Search
              className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
              size={18}
            />
            <Input
              placeholder="Rechercher (nom, téléphone, animal)…"
              className="pl-10"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </Card>

        {/* Patients list */}
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
          </div>
        ) : filteredPatients.length === 0 ? (
          <Card className="text-center py-8">
            <User size={48} className="text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">Aucun patient</p>
          </Card>
        ) : (
          <div className="grid gap-3">
            {filteredPatients.map((patient) => (
              <Card key={patient.keyId} className="hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 bg-primary-100 rounded-full flex items-center justify-center">
                      <span className="text-lg font-bold text-primary-600">
                        {patient.name[0]?.toUpperCase() || '?'}
                      </span>
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{patient.name}</p>
                      <p className="text-sm text-gray-500">
                        {[
                          patient.lastPet,
                          patient.phone,
                          patient.lastAt
                            ? `Dernière visite: ${format(patient.lastAt, 'dd MMM yyyy', { locale: fr })}`
                            : null,
                          `${patient.visits} ${patient.visits > 1 ? 'visites' : 'visite'}`,
                        ]
                          .filter(Boolean)
                          .join(' • ')}
                      </p>
                    </div>
                  </div>
                  <Button variant="secondary" size="sm" onClick={() => handleShowHistory(patient)}>
                    Historique
                  </Button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>

      {/* QR Scanner Modal */}
      {showQrScanner && (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Scanner QR Code</h2>
              <button onClick={stopQrScanner} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            {qrError ? (
              <div className="text-red-500 text-center py-8">{qrError}</div>
            ) : (
              <div id="qr-reader" className="w-full" />
            )}

            <p className="text-sm text-gray-500 text-center mt-4">
              Pointez la caméra vers le QR code de l'animal
            </p>

            {/* Manual token input */}
            <div className="mt-4 pt-4 border-t">
              <p className="text-sm text-gray-600 mb-2">Ou entrez le token manuellement:</p>
              <div className="flex gap-2">
                <Input
                  placeholder="Token du QR code"
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      const input = e.currentTarget;
                      if (input.value) {
                        stopQrScanner();
                        handleQrResult(input.value);
                      }
                    }
                  }}
                />
              </div>
            </div>
          </Card>
        </div>
      )}

      {/* History Modal */}
      {showHistoryModal && selectedPatient && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-2xl max-h-[80vh] overflow-hidden flex flex-col">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Historique — {selectedPatient.name}</h2>
              <button
                onClick={() => setShowHistoryModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X size={20} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto">
              {patientBookings.length === 0 ? (
                <p className="text-gray-500 text-center py-8">
                  Aucun rendez-vous pour ce patient
                </p>
              ) : (
                <div className="space-y-3">
                  {patientBookings.map((booking) => (
                    <div
                      key={booking.id}
                      className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                    >
                      <div className="flex items-center gap-3">
                        <Calendar size={18} className="text-gray-400" />
                        <div>
                          <p className="font-medium">
                            {booking.service?.title || 'Consultation'}
                          </p>
                          <p className="text-sm text-gray-500">
                            {booking.scheduledAt
                              ? format(new Date(booking.scheduledAt), "dd/MM/yyyy 'à' HH:mm", {
                                  locale: fr,
                                })
                              : '—'}
                            {booking.pet && ` • ${booking.pet.name}`}
                            {' • '}
                            {booking.status}
                          </p>
                        </div>
                      </div>
                      <span className="font-medium text-gray-700">
                        {booking.service?.price
                          ? `${booking.service.price.toLocaleString('fr-DZ')} DA`
                          : '—'}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </Card>
        </div>
      )}

      {/* Add Record Modal */}
      {showAddRecordModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4">Ajouter un enregistrement</h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Type
                </label>
                <select
                  value={newRecord.type}
                  onChange={(e) => setNewRecord({ ...newRecord, type: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <option value="CONSULTATION">Consultation</option>
                  <option value="VACCINATION">Vaccination</option>
                  <option value="SURGERY">Chirurgie</option>
                  <option value="TREATMENT">Traitement</option>
                  <option value="DIAGNOSTIC">Diagnostic</option>
                  <option value="OTHER">Autre</option>
                </select>
              </div>

              <Input
                label="Titre"
                placeholder="Ex: Consultation de routine"
                value={newRecord.title}
                onChange={(e) => setNewRecord({ ...newRecord, title: e.target.value })}
              />

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description (optionnel)
                </label>
                <textarea
                  rows={3}
                  placeholder="Notes sur l'examen, le diagnostic..."
                  value={newRecord.description}
                  onChange={(e) =>
                    setNewRecord({ ...newRecord, description: e.target.value })
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <Button
                variant="secondary"
                className="flex-1"
                onClick={() => setShowAddRecordModal(false)}
              >
                Annuler
              </Button>
              <Button
                className="flex-1"
                onClick={handleAddRecord}
                isLoading={addingRecord}
                disabled={!newRecord.title}
              >
                Ajouter
              </Button>
            </div>
          </Card>
        </div>
      )}
    </DashboardLayout>
  );
}
