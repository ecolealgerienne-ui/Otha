import { useEffect, useState, useRef, useCallback } from 'react';
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
  ChevronRight,
  TrendingUp,
  ClipboardList,
  ArrowLeft,
  Scale,
} from 'lucide-react';
import { Html5Qrcode } from 'html5-qrcode';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Pet, MedicalRecord, Vaccination, Booking } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

// View modes for the pet card
type ViewMode = 'hub' | 'medical-history' | 'vaccinations';

export function ProPatients() {
  // QR Scanner state
  const [showQrScanner, setShowQrScanner] = useState(false);
  const [scannedPet, setScannedPet] = useState<Pet | null>(null);
  const [scannedRecords, setScannedRecords] = useState<MedicalRecord[]>([]);
  const [scannedVaccinations, setScannedVaccinations] = useState<Vaccination[]>([]);
  const [currentToken, setCurrentToken] = useState<string | null>(null);
  const [qrError, setQrError] = useState<string | null>(null);
  const [scanLoading, setScanLoading] = useState(false);
  const scannerRef = useRef<Html5Qrcode | null>(null);

  // View mode for pet card
  const [viewMode, setViewMode] = useState<ViewMode>('hub');

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

  // Polling for phone scan
  const [isPolling, setIsPolling] = useState(false);
  const [lastScannedAt, setLastScannedAt] = useState<string | null>(null);
  const pollingRef = useRef<number | null>(null);

  // Poll for scanned pet from Flutter app
  const pollForScannedPet = useCallback(async () => {
    try {
      const result = await api.getScannedPet();
      if (result.pet && result.scannedAt !== lastScannedAt) {
        // New pet scanned from phone!
        setLastScannedAt(result.scannedAt);
        setScannedPet(result.pet);
        setScannedRecords((result.pet as any).medicalRecords || []);
        setScannedVaccinations((result.pet as any).vaccinations || []);
        setIsPolling(false);
        // Clear on server
        api.clearScannedPet().catch(() => {});
      }
    } catch (error) {
      console.log('Poll error:', error);
    }
  }, [lastScannedAt]);

  // Start/stop polling
  useEffect(() => {
    if (isPolling) {
      // Poll every 2 seconds
      pollingRef.current = window.setInterval(pollForScannedPet, 2000);
      // Initial poll
      pollForScannedPet();
    } else {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
    }

    return () => {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
      }
    };
  }, [isPolling, pollForScannedPet]);

  useEffect(() => {
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(() => {});
      }
    };
  }, []);

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

    console.log('QR scanned, token:', token);
    setCurrentToken(token);
    setShowQrScanner(false);
    setActiveBooking(null);
    setBookingConfirmed(false);
    setScanLoading(true);

    try {
      // Step 1: Get pet data from token
      console.log('Fetching pet by token...');
      const result = await api.getPetByToken(token);
      console.log('Pet by token result:', result);

      if (!result || !result.pet) {
        throw new Error('Aucun animal trouvé pour ce QR code');
      }

      // Set pet data immediately so user sees the carnet
      setScannedPet(result.pet);
      setScannedRecords(result.medicalRecords || []);
      setScannedVaccinations(result.vaccinations || []);

      // Step 2: Try to find active booking (optional - don't block on this)
      if (result.pet?.id) {
        try {
          console.log('Checking for active booking for pet:', result.pet.id);
          const booking = await api.getActiveBookingForPet(result.pet.id);

          if (booking) {
            console.log('Found active booking:', booking);
            setActiveBooking(booking);

            // Try to auto-confirm
            try {
              await api.proConfirmBooking(booking.id, 'QR_SCAN');
              setBookingConfirmed(true);
              console.log('Booking confirmed via QR scan');
            } catch (confirmErr) {
              console.error('Could not auto-confirm booking:', confirmErr);
            }
          } else {
            console.log('No active booking found for this pet today');
          }
        } catch (bookingErr) {
          // This is OK - just means no active booking or endpoint not available
          console.log('Could not check for active booking:', bookingErr);
        }
      }
    } catch (error) {
      console.error('Error fetching pet by token:', error);
      const message = error instanceof Error ? error.message : 'QR code invalide ou expiré';
      alert(message);
    } finally {
      setScanLoading(false);
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
    setScanLoading(false);
    setIsPolling(false);
    setViewMode('hub');
  };

  // Start waiting for phone scan
  const startPhoneScan = () => {
    setIsPolling(true);
  };

  const stopPhoneScan = () => {
    setIsPolling(false);
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
          /* Pet Health Hub - Similar to Flutter pet_health_hub_screen */
          <Card className="border-2 border-primary-500">
            {/* Header with back button if in sub-view */}
            <div className="flex items-center justify-between mb-4">
              {viewMode !== 'hub' ? (
                <button
                  onClick={() => setViewMode('hub')}
                  className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
                >
                  <ArrowLeft size={20} />
                  <span className="font-medium">Retour</span>
                </button>
              ) : (
                <h2 className="text-lg font-bold text-primary-600">
                  Santé de {scannedPet.name}
                </h2>
              )}
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

            {viewMode === 'hub' ? (
              /* Hub View - Main screen with action cards */
              <>
                {/* Pet info header */}
                <div className="flex items-start space-x-4 mb-6 p-4 bg-gradient-to-r from-primary-50 to-teal-50 rounded-xl border border-primary-100">
                  <div className="w-16 h-16 bg-white rounded-xl flex items-center justify-center text-3xl shadow-sm">
                    {getSpeciesEmoji(scannedPet.species)}
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-bold text-gray-900">{scannedPet.name}</h3>
                    <p className="text-gray-600">
                      {scannedPet.species} {scannedPet.breed && `• ${scannedPet.breed}`}
                    </p>
                    <div className="flex flex-wrap gap-3 mt-2 text-sm text-gray-600">
                      {scannedPet.gender && (
                        <span className="flex items-center gap-1">
                          {scannedPet.gender === 'MALE' ? '♂️' : '♀️'}
                          {scannedPet.gender === 'MALE' ? 'Mâle' : 'Femelle'}
                        </span>
                      )}
                      {scannedPet.weight && (
                        <span className="flex items-center gap-1">
                          <Scale size={14} />
                          {scannedPet.weight} kg
                        </span>
                      )}
                    </div>
                    {scannedPet.user && (
                      <p className="text-sm text-gray-500 mt-2">
                        👤 {scannedPet.user.firstName || 'Client'}
                        {scannedPet.user.phone && ` • ${scannedPet.user.phone}`}
                      </p>
                    )}
                  </div>
                </div>

                {/* Quick stats overview */}
                <div className="grid grid-cols-3 gap-3 mb-6">
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <Scale className="mx-auto text-primary-500 mb-1" size={20} />
                    <p className="text-lg font-bold text-gray-900">{scannedPet.weight || '—'}</p>
                    <p className="text-xs text-gray-500">Poids (kg)</p>
                  </div>
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <Syringe className="mx-auto text-green-500 mb-1" size={20} />
                    <p className="text-lg font-bold text-gray-900">{scannedVaccinations.length}</p>
                    <p className="text-xs text-gray-500">Vaccins</p>
                  </div>
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <FileText className="mx-auto text-blue-500 mb-1" size={20} />
                    <p className="text-lg font-bold text-gray-900">{scannedRecords.length}</p>
                    <p className="text-xs text-gray-500">Actes</p>
                  </div>
                </div>

                {/* Section title */}
                <h4 className="font-bold text-gray-900 mb-4">Accès rapide</h4>

                {/* Action Cards */}
                <div className="space-y-3">
                  {/* Add medical record */}
                  <button
                    onClick={() => setShowAddRecordModal(true)}
                    className="w-full p-4 bg-gradient-to-r from-white to-primary-50 rounded-xl border-2 border-primary-200 hover:border-primary-400 transition-colors flex items-center gap-4 text-left"
                  >
                    <div className="w-12 h-12 bg-gradient-to-br from-primary-500 to-primary-600 rounded-xl flex items-center justify-center shadow-lg shadow-primary-200">
                      <Plus className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Ajouter un acte</p>
                      <p className="text-sm text-gray-500">Consultation, traitement, diagnostic</p>
                    </div>
                    <ChevronRight className="text-primary-400" size={20} />
                  </button>

                  {/* Medical history */}
                  <button
                    onClick={() => setViewMode('medical-history')}
                    className="w-full p-4 bg-gradient-to-r from-white to-blue-50 rounded-xl border-2 border-blue-200 hover:border-blue-400 transition-colors flex items-center gap-4 text-left"
                  >
                    <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl flex items-center justify-center shadow-lg shadow-blue-200">
                      <ClipboardList className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Historique médical</p>
                      <p className="text-sm text-gray-500">Consultations, diagnostics, traitements</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full font-medium">
                        {scannedRecords.length}
                      </span>
                      <ChevronRight className="text-blue-400" size={20} />
                    </div>
                  </button>

                  {/* Vaccinations */}
                  <button
                    onClick={() => setViewMode('vaccinations')}
                    className="w-full p-4 bg-gradient-to-r from-white to-green-50 rounded-xl border-2 border-green-200 hover:border-green-400 transition-colors flex items-center gap-4 text-left"
                  >
                    <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-green-600 rounded-xl flex items-center justify-center shadow-lg shadow-green-200">
                      <Syringe className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Vaccinations</p>
                      <p className="text-sm text-gray-500">Calendrier et rappels de vaccins</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">
                        {scannedVaccinations.length}
                      </span>
                      <ChevronRight className="text-green-400" size={20} />
                    </div>
                  </button>

                  {/* Health stats */}
                  <button
                    className="w-full p-4 bg-gradient-to-r from-white to-orange-50 rounded-xl border-2 border-orange-200 hover:border-orange-400 transition-colors flex items-center gap-4 text-left opacity-60 cursor-not-allowed"
                    disabled
                  >
                    <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl flex items-center justify-center shadow-lg shadow-orange-200">
                      <TrendingUp className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Statistiques de santé</p>
                      <p className="text-sm text-gray-500">Poids, température (bientôt)</p>
                    </div>
                    <ChevronRight className="text-orange-400" size={20} />
                  </button>
                </div>

                {/* Button to scan another */}
                <div className="mt-6 pt-4 border-t">
                  <Button variant="secondary" onClick={closePetView} className="w-full">
                    <QrCode size={16} className="mr-2" />
                    Scanner un autre patient
                  </Button>
                </div>
              </>
            ) : viewMode === 'medical-history' ? (
              /* Medical History Detail View */
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <ClipboardList className="text-blue-600" size={24} />
                  Historique médical
                </h3>

                {scannedRecords.length === 0 ? (
                  <div className="text-center py-12">
                    <FileText className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucun historique médical</p>
                    <Button onClick={() => setShowAddRecordModal(true)} className="mt-4">
                      <Plus size={16} className="mr-2" />
                      Ajouter un acte
                    </Button>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {scannedRecords.map((r) => {
                      const typeInfo = getRecordTypeIcon(r.type);
                      const IconComponent = typeInfo.icon;
                      return (
                        <div key={r.id} className="p-4 bg-white border border-gray-200 rounded-xl">
                          <div className="flex items-start gap-3">
                            <div className={`p-2.5 ${typeInfo.bg} rounded-xl flex-shrink-0`}>
                              <IconComponent size={18} className={typeInfo.color} />
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
                              <p className="font-semibold text-gray-900">{r.title}</p>
                              {r.description && (
                                <p className="text-sm text-gray-600 mt-1">{r.description}</p>
                              )}
                              {r.veterinarian && (
                                <p className="text-xs text-gray-400 mt-2">Dr. {r.veterinarian}</p>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}

                <div className="mt-6">
                  <Button onClick={() => setShowAddRecordModal(true)} className="w-full">
                    <Plus size={16} className="mr-2" />
                    Ajouter un acte médical
                  </Button>
                </div>
              </>
            ) : viewMode === 'vaccinations' ? (
              /* Vaccinations Detail View */
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <Syringe className="text-green-600" size={24} />
                  Vaccinations
                </h3>

                {scannedVaccinations.length === 0 ? (
                  <div className="text-center py-12">
                    <Syringe className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucune vaccination enregistrée</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {scannedVaccinations.map((v) => (
                      <div key={v.id} className="p-4 bg-gradient-to-r from-green-50 to-white rounded-xl border border-green-200">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div className="p-2.5 bg-green-100 rounded-xl">
                              <Syringe size={18} className="text-green-600" />
                            </div>
                            <div>
                              <p className="font-semibold text-gray-900">{v.name}</p>
                              <p className="text-sm text-gray-500">
                                Administré le {format(new Date(v.date), 'dd MMMM yyyy', { locale: fr })}
                              </p>
                            </div>
                          </div>
                          {v.nextDueDate && (
                            <div className="text-right">
                              <p className="text-xs text-orange-600 font-medium">Rappel</p>
                              <p className="text-sm text-orange-700 font-semibold">
                                {format(new Date(v.nextDueDate), 'dd/MM/yyyy')}
                              </p>
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </>
            ) : null}
          </Card>
        ) : isPolling ? (
          /* Waiting for phone scan */
          <Card className="text-center py-12">
            <div className="w-24 h-24 bg-orange-100 rounded-full flex items-center justify-center mx-auto mb-6">
              <Smartphone size={48} className="text-orange-600 animate-pulse" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">
              En attente du scan téléphone...
            </h2>
            <p className="text-gray-500 mb-8 max-w-md mx-auto">
              Ouvrez l'application Otha sur votre téléphone et scannez le QR code du patient.
              Le carnet s'affichera automatiquement ici.
            </p>

            <div className="flex items-center justify-center gap-3 mb-6">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-orange-600" />
              <span className="text-gray-600">En attente...</span>
            </div>

            <Button variant="secondary" onClick={stopPhoneScan}>
              Annuler
            </Button>
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

            {scanLoading ? (
              <div className="flex items-center justify-center gap-3">
                <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
                <span className="text-gray-600">Chargement du carnet...</span>
              </div>
            ) : (
              <div className="flex flex-col sm:flex-row gap-4 justify-center max-w-md mx-auto">
                <Button onClick={startQrScanner} size="lg" className="flex-1">
                  <Monitor size={20} className="mr-2" />
                  Scanner avec PC
                </Button>
                <Button onClick={startPhoneScan} variant="secondary" size="lg" className="flex-1">
                  <Smartphone size={20} className="mr-2" />
                  Scanner avec téléphone
                </Button>
              </div>
            )}

            <p className="text-xs text-gray-400 mt-6">
              Utilisez la webcam de votre PC ou l'application Otha sur votre téléphone
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
