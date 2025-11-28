import { useEffect, useState, useRef } from 'react';
import {
  FileText,
  Syringe,
  QrCode,
  X,
  Plus,
  Calendar,
  CheckCircle,
  Stethoscope,
  Scissors,
  Pill,
  Activity,
  Heart,
  Smartphone,
  Monitor,
} from 'lucide-react';
import { Html5Qrcode } from 'html5-qrcode';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Pet, MedicalRecord, Vaccination, Booking } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

export function ProPatients() {
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

  // Active booking found for scanned pet
  const [activeBooking, setActiveBooking] = useState<Booking | null>(null);
  const [bookingConfirmed, setBookingConfirmed] = useState(false);

  // Choice modal (PC or Phone)
  const [showChoiceModal, setShowChoiceModal] = useState(false);

  useEffect(() => {
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(() => {});
      }
    };
  }, []);

  // Scan via PC webcam
  const handleScanPC = () => {
    setShowChoiceModal(false);
    startQrScanner();
  };

  // Scan via Phone - open Flutter app
  const handleScanPhone = () => {
    setShowChoiceModal(false);
    // Open deep link to Flutter app's scanner
    const deepLink = 'otha://vet/scan';
    window.location.href = deepLink;

    // Fallback: if deep link doesn't work after 2 seconds, show message
    setTimeout(() => {
      // The page is still here, so deep link probably didn't work
      alert("Ouvrez l'application Otha sur votre téléphone et allez dans 'Scanner patient'");
    }, 2000);
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
    setActiveBooking(null);
    setBookingConfirmed(false);

    try {
      const result = await api.getPetByToken(token);
      console.log('Pet by token result:', result);
      setScannedPet(result.pet);
      setScannedRecords(result.medicalRecords || []);
      setScannedVaccinations(result.vaccinations || []);

      // Check for active booking for this pet
      if (result.pet?.id) {
        try {
          const booking = await api.getActiveBookingForPet(result.pet.id);
          if (booking) {
            setActiveBooking(booking);
            console.log('Found active booking:', booking);

            // Auto-confirm the booking via QR scan
            try {
              await api.proConfirmBooking(booking.id, 'QR_SCAN');
              setBookingConfirmed(true);
            } catch (confirmError) {
              console.error('Error auto-confirming booking:', confirmError);
            }
          }
        } catch (bookingError) {
          // No active booking found - that's OK
          console.log('No active booking for pet');
        }
      }
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
    setActiveBooking(null);
    setBookingConfirmed(false);
  };

  // Get icon and color for medical record type
  const getRecordTypeIcon = (type: string) => {
    switch (type.toUpperCase()) {
      case 'VACCINATION':
        return { icon: Syringe, color: 'text-green-600', bg: 'bg-green-100' };
      case 'SURGERY':
        return { icon: Scissors, color: 'text-red-600', bg: 'bg-red-100' };
      case 'CHECKUP':
      case 'CONSULTATION':
        return { icon: Stethoscope, color: 'text-blue-600', bg: 'bg-blue-100' };
      case 'TREATMENT':
        return { icon: Heart, color: 'text-orange-600', bg: 'bg-orange-100' };
      case 'MEDICATION':
        return { icon: Pill, color: 'text-purple-600', bg: 'bg-purple-100' };
      case 'DIAGNOSTIC':
        return { icon: Activity, color: 'text-cyan-600', bg: 'bg-cyan-100' };
      default:
        return { icon: FileText, color: 'text-gray-600', bg: 'bg-gray-100' };
    }
  };

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
            <h1 className="text-2xl font-bold text-gray-900">Scanner Patient</h1>
            <p className="text-gray-600 mt-1">
              Scannez le QR code du carnet de santé de l'animal
            </p>
          </div>
        </div>

        {/* Main content - Scanner buttons or Pet view */}
        {scannedPet ? (
          /* QR Scanned Pet View - Carnet de Santé */
          <Card className="border-2 border-primary-500">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-primary-600">
                🩺 Carnet de santé
              </h2>
              <button onClick={closePetView} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            {/* Booking confirmation banner */}
            {activeBooking && (
              <div className={`mb-4 p-3 rounded-lg flex items-center gap-3 ${
                bookingConfirmed
                  ? 'bg-green-50 border border-green-200'
                  : 'bg-yellow-50 border border-yellow-200'
              }`}>
                {bookingConfirmed ? (
                  <>
                    <CheckCircle className="text-green-600" size={24} />
                    <div>
                      <p className="font-medium text-green-800">Rendez-vous confirmé !</p>
                      <p className="text-sm text-green-600">
                        {activeBooking.service?.title || 'Consultation'} - {' '}
                        {activeBooking.scheduledAt && format(new Date(activeBooking.scheduledAt), "HH:mm", { locale: fr })}
                      </p>
                    </div>
                  </>
                ) : (
                  <>
                    <Calendar className="text-yellow-600" size={24} />
                    <div>
                      <p className="font-medium text-yellow-800">RDV en cours de confirmation...</p>
                      <p className="text-sm text-yellow-600">
                        {activeBooking.service?.title || 'Consultation'}
                      </p>
                    </div>
                  </>
                )}
              </div>
            )}

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
                  {scannedPet.microchip && <span>📟 {scannedPet.microchip}</span>}
                </div>
                {scannedPet.user && (
                  <p className="text-sm text-gray-500 mt-2">
                    Propriétaire: {scannedPet.user.firstName || scannedPet.user.email?.split('@')[0] || 'Client'}
                    {scannedPet.user.phone && ` • ${scannedPet.user.phone}`}
                  </p>
                )}
              </div>
            </div>

            {/* Add record button */}
            <Button onClick={() => setShowAddRecordModal(true)} className="mb-4">
              <Plus size={16} className="mr-2" />
              Ajouter un acte
            </Button>

            {/* Vaccinations */}
            <div className="mb-6">
              <div className="flex items-center gap-2 mb-3">
                <div className="p-1.5 bg-green-100 rounded-lg">
                  <Syringe size={18} className="text-green-600" />
                </div>
                <h4 className="font-semibold">Vaccinations</h4>
                <span className="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full">
                  {scannedVaccinations.length}
                </span>
              </div>
              {scannedVaccinations.length === 0 ? (
                <p className="text-sm text-gray-500 italic">Aucune vaccination enregistrée</p>
              ) : (
                <div className="space-y-2">
                  {scannedVaccinations.slice(0, 5).map((v) => (
                    <div key={v.id} className="flex items-center justify-between p-3 bg-green-50 rounded-lg">
                      <div className="flex items-center gap-3">
                        <Syringe size={16} className="text-green-600" />
                        <span className="font-medium">{v.name}</span>
                      </div>
                      <div className="text-right text-sm">
                        <span className="text-gray-600">
                          {format(new Date(v.date), 'dd/MM/yyyy')}
                        </span>
                        {v.nextDueDate && (
                          <p className="text-xs text-orange-600">
                            Rappel: {format(new Date(v.nextDueDate), 'dd/MM/yyyy')}
                          </p>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Medical Records - Historique médical */}
            <div>
              <div className="flex items-center gap-2 mb-3">
                <div className="p-1.5 bg-blue-100 rounded-lg">
                  <FileText size={18} className="text-blue-600" />
                </div>
                <h4 className="font-semibold">Historique médical</h4>
                <span className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full">
                  {scannedRecords.length}
                </span>
              </div>
              {scannedRecords.length === 0 ? (
                <p className="text-sm text-gray-500 italic">Aucun historique médical</p>
              ) : (
                <div className="space-y-2">
                  {scannedRecords.map((r) => {
                    const typeInfo = getRecordTypeIcon(r.type);
                    const IconComponent = typeInfo.icon;
                    return (
                      <div key={r.id} className="p-3 bg-white border border-gray-200 rounded-lg">
                        <div className="flex items-start gap-3">
                          <div className={`p-2 ${typeInfo.bg} rounded-lg flex-shrink-0`}>
                            <IconComponent size={16} className={typeInfo.color} />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between mb-1">
                              <span className={`text-xs ${typeInfo.bg} ${typeInfo.color} px-2 py-0.5 rounded font-medium`}>
                                {r.type}
                              </span>
                              <span className="text-xs text-gray-500">
                                {format(new Date(r.date), 'dd/MM/yyyy')}
                              </span>
                            </div>
                            <p className="font-medium text-gray-900">{r.title}</p>
                            {r.description && (
                              <p className="text-sm text-gray-600 mt-1">{r.description}</p>
                            )}
                            {r.veterinarian && (
                              <p className="text-xs text-gray-400 mt-1">Dr. {r.veterinarian}</p>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Button to scan another */}
            <div className="mt-6 pt-4 border-t">
              <Button variant="secondary" onClick={closePetView} className="w-full">
                <QrCode size={16} className="mr-2" />
                Scanner un autre patient
              </Button>
            </div>
          </Card>
        ) : (
          /* Scanner choice buttons */
          <Card className="text-center py-12">
            <div className="w-24 h-24 bg-primary-100 rounded-full flex items-center justify-center mx-auto mb-6">
              <QrCode size={48} className="text-primary-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">
              Scanner un patient
            </h2>
            <p className="text-gray-500 mb-8 max-w-md mx-auto">
              Scannez le QR code du carnet de santé de l'animal pour accéder à son historique médical et confirmer le rendez-vous.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center max-w-md mx-auto">
              <Button onClick={handleScanPC} size="lg" className="flex-1">
                <Monitor size={20} className="mr-2" />
                Scanner avec PC
              </Button>
              <Button onClick={handleScanPhone} variant="secondary" size="lg" className="flex-1">
                <Smartphone size={20} className="mr-2" />
                Scanner avec téléphone
              </Button>
            </div>

            <p className="text-xs text-gray-400 mt-6">
              Le scan par téléphone ouvrira l'application Otha
            </p>
          </Card>
        )}
      </div>

      {/* QR Scanner Modal (PC webcam) */}
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

      {/* Choice Modal */}
      {showChoiceModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-sm">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-semibold">Comment scanner ?</h2>
              <button onClick={() => setShowChoiceModal(false)} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            <div className="space-y-3">
              <button
                onClick={handleScanPC}
                className="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-primary-500 hover:bg-primary-50 transition-colors flex items-center gap-4"
              >
                <div className="p-3 bg-primary-100 rounded-lg">
                  <Monitor size={24} className="text-primary-600" />
                </div>
                <div className="text-left">
                  <p className="font-semibold text-gray-900">Webcam PC</p>
                  <p className="text-sm text-gray-500">Utiliser la caméra de l'ordinateur</p>
                </div>
              </button>

              <button
                onClick={handleScanPhone}
                className="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-primary-500 hover:bg-primary-50 transition-colors flex items-center gap-4"
              >
                <div className="p-3 bg-orange-100 rounded-lg">
                  <Smartphone size={24} className="text-orange-600" />
                </div>
                <div className="text-left">
                  <p className="font-semibold text-gray-900">Téléphone</p>
                  <p className="text-sm text-gray-500">Ouvrir l'app Otha sur le téléphone</p>
                </div>
              </button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Record Modal */}
      {showAddRecordModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4">Ajouter un acte médical</h2>

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
