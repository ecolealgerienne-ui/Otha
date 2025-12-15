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
  ChevronRight,
  TrendingUp,
  ClipboardList,
  ArrowLeft,
  Scale,
  Thermometer,
  Upload,
  Image,
  Trash2,
  Edit2,
  AlertTriangle,
  Clock,
  Hash,
} from 'lucide-react';
import { Html5Qrcode } from 'html5-qrcode';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Prescription, DiseaseTracking, Booking, Pet } from '../types';
import { format, differenceInHours } from 'date-fns';
import { fr } from 'date-fns/locale';
import { useScannedPet } from '../contexts/ScannedPetContext';

/**
 * Parse ISO date string as local time (ignore timezone offset)
 * Correspond au comportement Flutter: DateTime.parse(iso).toUtc()
 */
function parseISOAsLocal(isoString: string): Date {
  const d = new Date(isoString);
  return new Date(
    d.getUTCFullYear(),
    d.getUTCMonth(),
    d.getUTCDate(),
    d.getUTCHours(),
    d.getUTCMinutes(),
    d.getUTCSeconds()
  );
}

// Access window in hours for recent patients
const ACCESS_WINDOW_HOURS = 24;

interface RecentPatient {
  booking: Booking;
  pet: Pet;
  accessExpiresAt: Date;
  hoursRemaining: number;
}

// View modes for the pet card
type ViewMode = 'hub' | 'medical-history' | 'vaccinations' | 'prescriptions' | 'health-stats' | 'diseases';

export function ProPatients() {
  // Use global context for persistent state
  const {
    pet: scannedPet,
    token: currentToken,
    records: scannedRecords,
    vaccinations: scannedVaccinations,
    prescriptions,
    healthStats,
    diseases,
    activeBooking,
    bookingConfirmed,
    setPetData,
    setBooking,
    addRecord,
    addPrescription,
    addDisease,
    editPrescription,
    editDisease,
    removeRecord,
    removePrescription,
    removeDisease,
    clearPet,
    isPolling,
    startPolling,
    stopPolling,
  } = useScannedPet();

  // Debug: log when scannedPet changes
  useEffect(() => {
    console.log('🐾 scannedPet changed:', scannedPet ? `${scannedPet.name} (id: ${scannedPet.id})` : 'null');
  }, [scannedPet]);

  // Current provider ID (for ownership check)
  const [currentProviderId, setCurrentProviderId] = useState<string | null>(null);

  // QR Scanner state
  const [showQrScanner, setShowQrScanner] = useState(false);
  const [qrError, setQrError] = useState<string | null>(null);
  const [scanLoading, setScanLoading] = useState(false);
  const scannerRef = useRef<Html5Qrcode | null>(null);

  // View mode for pet card
  const [viewMode, setViewMode] = useState<ViewMode>('hub');

  // Modals
  const [showAddRecordModal, setShowAddRecordModal] = useState(false);
  const [showAddPrescriptionModal, setShowAddPrescriptionModal] = useState(false);
  const [showAddDiseaseModal, setShowAddDiseaseModal] = useState(false);
  const [showEditPrescriptionModal, setShowEditPrescriptionModal] = useState(false);
  const [showEditDiseaseModal, setShowEditDiseaseModal] = useState(false);
  const [showReferenceCodeModal, setShowReferenceCodeModal] = useState(false);

  // Reference code state
  const [referenceCode, setReferenceCode] = useState('');
  const [confirmingByCode, setConfirmingByCode] = useState(false);

  // Form states
  const [newRecord, setNewRecord] = useState({ title: '', type: 'CONSULTATION', description: '' });
  const [newPrescription, setNewPrescription] = useState({ title: '', description: '', imageUrl: '' });
  const [newDisease, setNewDisease] = useState({ name: '', description: '', status: 'ACTIVE' });

  // Edit states
  const [editingPrescription, setEditingPrescription] = useState<Prescription | null>(null);
  const [editingDisease, setEditingDisease] = useState<DiseaseTracking | null>(null);

  // Loading states
  const [addingRecord, setAddingRecord] = useState(false);
  const [addingPrescription, setAddingPrescription] = useState(false);
  const [addingDisease, setAddingDisease] = useState(false);
  const [savingPrescription, setSavingPrescription] = useState(false);
  const [savingDisease, setSavingDisease] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);

  // Recent patients state (24h access)
  const [recentPatients, setRecentPatients] = useState<RecentPatient[]>([]);
  const [loadingRecentPatients, setLoadingRecentPatients] = useState(true);

  // Get current provider ID and load recent patients on mount
  useEffect(() => {
    api.myProvider().then((provider) => {
      if (provider) setCurrentProviderId(provider.id);
    });
    loadRecentPatients();
  }, []);

  // ✅ Auto-start polling for Flutter scans when page opens
  useEffect(() => {
    console.log('🚀 ProPatients mounted, starting polling');
    startPolling();
    return () => {
      console.log('👋 ProPatients unmounting, stopping polling');
      stopPolling();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Only run on mount/unmount

  // Refresh countdown every minute
  useEffect(() => {
    const interval = setInterval(() => {
      setRecentPatients((prev) =>
        prev
          .map((p) => ({
            ...p,
            hoursRemaining: Math.max(0, differenceInHours(p.accessExpiresAt, new Date())),
          }))
          .filter((p) => p.hoursRemaining > 0)
      );
    }, 60000);
    return () => clearInterval(interval);
  }, []);

  // ✅ Listen for pet scanned from Flutter app to refresh recent patients
  useEffect(() => {
    const handleFlutterScan = () => {
      loadRecentPatients();
    };
    window.addEventListener('pet-scanned-from-flutter', handleFlutterScan);
    return () => window.removeEventListener('pet-scanned-from-flutter', handleFlutterScan);
  }, []);

  async function loadRecentPatients() {
    setLoadingRecentPatients(true);
    try {
      const now = new Date();
      const yesterday = new Date(now.getTime() - ACCESS_WINDOW_HOURS * 60 * 60 * 1000);
      // Add 1 day to include today's bookings (backend uses lt, not lte)
      const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      const fromIso = format(yesterday, 'yyyy-MM-dd');
      const toIso = format(tomorrow, 'yyyy-MM-dd');

      const bookings = await api.providerAgenda(fromIso, toIso);

      // Filter only CONFIRMED or COMPLETED bookings with a pet
      const validBookings = bookings.filter(
        (b: Booking) =>
          (b.status === 'CONFIRMED' || b.status === 'COMPLETED') &&
          b.pet &&
          b.pet.id
      );

      // Calculate access expiration for each
      const patients: RecentPatient[] = validBookings
        .map((b: Booking) => {
          const bookingTime = parseISOAsLocal(b.scheduledAt);
          const accessExpiresAt = new Date(bookingTime.getTime() + ACCESS_WINDOW_HOURS * 60 * 60 * 1000);
          const hoursRemaining = Math.max(0, differenceInHours(accessExpiresAt, now));

          return {
            booking: b,
            pet: b.pet!,
            accessExpiresAt,
            hoursRemaining,
          };
        })
        .filter((p: RecentPatient) => p.hoursRemaining > 0);

      // Deduplicate by pet ID (keep most recent booking)
      const uniquePatients = new Map<string, RecentPatient>();
      patients.forEach((p: RecentPatient) => {
        const existing = uniquePatients.get(p.pet.id);
        if (!existing || new Date(p.booking.scheduledAt) > new Date(existing.booking.scheduledAt)) {
          uniquePatients.set(p.pet.id, p);
        }
      });

      setRecentPatients(Array.from(uniquePatients.values()));
    } catch (error) {
      console.error('Error loading recent patients:', error);
    } finally {
      setLoadingRecentPatients(false);
    }
  }

  // Select a recent patient (load into scanned pet context)
  async function selectRecentPatient(patient: RecentPatient) {
    setScanLoading(true);
    try {
      // Generate PRO access token for this pet (requires recent confirmed booking)
      const token = await api.generateProPetAccessToken(patient.pet.id);

      if (!token) {
        throw new Error('Impossible de générer le token d\'accès');
      }

      // Load pet data via token
      const result = await api.getPetByToken(token);
      if (!result || !result.pet) {
        throw new Error('Impossible de charger les données du patient');
      }

      // Load additional data
      const [presc, stats, dis] = await Promise.all([
        api.getPetPrescriptions(result.pet.id).catch(() => []),
        api.getPetHealthStats(result.pet.id).catch(() => null),
        api.getPetDiseases(result.pet.id).catch(() => []),
      ]);

      setPetData(
        result.pet,
        token,
        result.medicalRecords || [],
        result.vaccinations || [],
        presc,
        stats,
        dis
      );

      // Set the booking info
      setBooking(patient.booking, patient.booking.status === 'COMPLETED' || patient.booking.status === 'CONFIRMED');
    } catch (error) {
      console.error('Error selecting patient:', error);
      alert(error instanceof Error ? error.message : 'Erreur lors du chargement');
    } finally {
      setScanLoading(false);
    }
  }

  useEffect(() => {
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(() => {});
      }
    };
  }, []);

  // Check if current user owns this record
  const isOwnRecord = (providerId?: string) => {
    return providerId === currentProviderId;
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
          { fps: 10, qrbox: { width: 250, height: 250 } },
          async (decodedText) => {
            await scanner.stop();
            scannerRef.current = null;
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
    let token = text;
    if (text.includes('/pet/')) {
      token = text.split('/pet/').pop() || text;
    } else if (text.includes('token=')) {
      token = text.split('token=').pop() || text;
    }

    setShowQrScanner(false);
    setScanLoading(true);

    try {
      const result = await api.getPetByToken(token);
      if (!result || !result.pet) {
        throw new Error('Aucun animal trouvé pour ce QR code');
      }

      // Load additional data
      const [presc, stats, dis] = await Promise.all([
        api.getPetPrescriptions(result.pet.id).catch(() => []),
        api.getPetHealthStats(result.pet.id).catch(() => null),
        api.getPetDiseases(result.pet.id).catch(() => []),
      ]);

      setPetData(
        result.pet,
        token,
        result.medicalRecords || [],
        result.vaccinations || [],
        presc,
        stats,  // HealthStatsAggregated | null
        dis
      );

      // Check for active booking
      if (result.pet?.id) {
        try {
          const booking = await api.getActiveBookingForPet(result.pet.id);
          if (booking) {
            setBooking(booking, false);
            try {
              await api.proConfirmBooking(booking.id, 'QR_SCAN');
              setBooking(booking, true);
              // Refresh recent patients list after confirmation
              loadRecentPatients();
            } catch (e) {
              console.error('Could not auto-confirm:', e);
            }
          }
        } catch (e) {
          console.log('No active booking:', e);
        }
      }
    } catch (error) {
      console.error('Error fetching pet:', error);
      alert(error instanceof Error ? error.message : 'QR code invalide');
    } finally {
      setScanLoading(false);
    }
  };

  // Handle confirmation by reference code (VGC-XXXXXX)
  const handleConfirmByReferenceCode = async () => {
    if (!referenceCode.trim()) return;
    setConfirmingByCode(true);
    try {
      const result = await api.confirmByReferenceCode(referenceCode.trim());

      if (result.success && result.pet && result.accessToken) {
        // Load additional data
        const [presc, stats, dis] = await Promise.all([
          api.getPetPrescriptions(result.pet.id).catch(() => []),
          api.getPetHealthStats(result.pet.id).catch(() => null),
          api.getPetDiseases(result.pet.id).catch(() => []),
        ]);

        // Set pet data in context
        setPetData(
          result.pet,
          result.accessToken,
          result.pet.medicalRecords || [],
          result.pet.vaccinations || [],
          presc,
          stats,
          dis
        );

        // Set booking as confirmed
        setBooking(result.booking, true);

        // Refresh recent patients list after confirmation
        loadRecentPatients();

        // Close modal and reset
        setShowReferenceCodeModal(false);
        setReferenceCode('');

        // Show success alert
        alert(`✅ ${result.message}\n\nPatient: ${result.pet.name}`);
      } else {
        throw new Error(result.message || 'Erreur lors de la confirmation');
      }
    } catch (error) {
      console.error('Error confirming by reference code:', error);
      alert(error instanceof Error ? error.message : 'Code de référence invalide');
    } finally {
      setConfirmingByCode(false);
    }
  };

  // Handle image upload for prescription
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      alert('Veuillez sélectionner une image');
      return;
    }

    setUploadingImage(true);
    try {
      const url = await api.uploadFile(file);
      setNewPrescription((prev) => ({ ...prev, imageUrl: url }));
    } catch (error) {
      console.error('Upload error:', error);
      alert("Erreur lors du téléversement de l'image");
    } finally {
      setUploadingImage(false);
    }
  };

  // Add handlers
  const handleAddRecord = async () => {
    if (!currentToken || !newRecord.title) return;
    setAddingRecord(true);
    try {
      const record = await api.createMedicalRecordByToken(currentToken, {
        title: newRecord.title,
        type: newRecord.type,
        description: newRecord.description || undefined,
      });
      addRecord(record);
      setShowAddRecordModal(false);
      setNewRecord({ title: '', type: 'CONSULTATION', description: '' });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout");
    } finally {
      setAddingRecord(false);
    }
  };

  const handleAddPrescription = async () => {
    if (!currentToken || !newPrescription.title) return;
    setAddingPrescription(true);
    try {
      const prescription = await api.createPrescriptionByToken(currentToken, {
        title: newPrescription.title,
        description: newPrescription.description || undefined,
        imageUrl: newPrescription.imageUrl || undefined,
      });
      addPrescription(prescription);
      setShowAddPrescriptionModal(false);
      setNewPrescription({ title: '', description: '', imageUrl: '' });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout");
    } finally {
      setAddingPrescription(false);
    }
  };

  const handleAddDisease = async () => {
    if (!currentToken || !newDisease.name) return;
    setAddingDisease(true);
    try {
      const disease = await api.createDiseaseByToken(currentToken, {
        name: newDisease.name,
        description: newDisease.description || undefined,
        status: newDisease.status,
      });
      addDisease(disease);
      setShowAddDiseaseModal(false);
      setNewDisease({ name: '', description: '', status: 'ACTIVE' });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout");
    } finally {
      setAddingDisease(false);
    }
  };

  // Delete handlers (only own records)
  const handleDeleteRecord = async (id: string) => {
    if (!confirm('Supprimer cet enregistrement ?')) return;
    try {
      await api.deleteMedicalRecord(id);
      removeRecord(id);
    } catch (error) {
      alert('Erreur lors de la suppression');
    }
  };

  const handleDeletePrescription = async (id: string) => {
    if (!confirm('Supprimer cette ordonnance ?')) return;
    try {
      await api.deletePrescription(id);
      removePrescription(id);
    } catch (error) {
      alert('Erreur lors de la suppression');
    }
  };

  const handleEditPrescription = (p: Prescription) => {
    setEditingPrescription(p);
    setShowEditPrescriptionModal(true);
  };

  const handleSavePrescription = async () => {
    if (!editingPrescription) return;
    setSavingPrescription(true);
    try {
      const updated = await api.updatePrescription(editingPrescription.id, {
        title: editingPrescription.title,
        description: editingPrescription.description,
        imageUrl: editingPrescription.imageUrl,
      });
      editPrescription(editingPrescription.id, updated);
      setShowEditPrescriptionModal(false);
      setEditingPrescription(null);
    } catch (error) {
      alert('Erreur lors de la modification');
    } finally {
      setSavingPrescription(false);
    }
  };

  const handleEditDisease = (d: DiseaseTracking) => {
    setEditingDisease(d);
    setShowEditDiseaseModal(true);
  };

  const handleSaveDisease = async () => {
    if (!editingDisease) return;
    setSavingDisease(true);
    try {
      const updated = await api.updateDisease(editingDisease.id, {
        name: editingDisease.name,
        description: editingDisease.description,
        status: editingDisease.status,
        notes: editingDisease.notes,
      });
      editDisease(editingDisease.id, updated);
      setShowEditDiseaseModal(false);
      setEditingDisease(null);
    } catch (error) {
      alert('Erreur lors de la modification');
    } finally {
      setSavingDisease(false);
    }
  };

  const handleDeleteDisease = async (id: string) => {
    if (!confirm('Supprimer ce suivi ?')) return;
    try {
      await api.deleteDisease(id);
      removeDisease(id);
    } catch (error) {
      alert('Erreur lors de la suppression');
    }
  };

  const closePetView = () => {
    clearPet();
    setViewMode('hub');
  };

  // Get icon for record type
  const getRecordTypeIcon = (type: string) => {
    switch (type.toUpperCase()) {
      case 'VACCINATION': return { icon: Syringe, color: 'text-green-600', bg: 'bg-green-100' };
      case 'SURGERY': return { icon: Scissors, color: 'text-red-600', bg: 'bg-red-100' };
      case 'CHECKUP':
      case 'CONSULTATION': return { icon: Stethoscope, color: 'text-blue-600', bg: 'bg-blue-100' };
      case 'TREATMENT': return { icon: Heart, color: 'text-orange-600', bg: 'bg-orange-100' };
      case 'MEDICATION': return { icon: Pill, color: 'text-purple-600', bg: 'bg-purple-100' };
      case 'DIAGNOSTIC': return { icon: Activity, color: 'text-cyan-600', bg: 'bg-cyan-100' };
      default: return { icon: FileText, color: 'text-gray-600', bg: 'bg-gray-100' };
    }
  };

  const getSpeciesEmoji = (species?: string) => {
    switch ((species || '').toUpperCase()) {
      case 'DOG': case 'CHIEN': return '🐕';
      case 'CAT': case 'CHAT': return '🐈';
      case 'BIRD': case 'OISEAU': return '🐦';
      case 'RABBIT': case 'LAPIN': return '🐰';
      default: return '🐾';
    }
  };

  // Get latest stat from aggregated health stats
  const getLatestStat = (type: string) => {
    if (!healthStats) return null;
    if (type === 'WEIGHT') return healthStats.weight?.current;
    if (type === 'TEMPERATURE') return healthStats.temperature?.current;
    if (type === 'HEART_RATE') return healthStats.heartRate?.current;
    return null;
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Scanner Patient</h1>
            <p className="text-gray-600 mt-1">Scannez le QR code du carnet de santé</p>
          </div>
        </div>

        {scannedPet ? (
          <Card className="border-2 border-primary-500">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
              {viewMode !== 'hub' ? (
                <button onClick={() => setViewMode('hub')} className="flex items-center gap-2 text-gray-600 hover:text-gray-900">
                  <ArrowLeft size={20} />
                  <span className="font-medium">Retour</span>
                </button>
              ) : (
                <h2 className="text-lg font-bold text-primary-600">Santé de {scannedPet.name}</h2>
              )}
              <button onClick={closePetView} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            {/* Booking banner */}
            {activeBooking && (
              <div className={`mb-4 p-3 rounded-lg flex items-center gap-3 ${bookingConfirmed ? 'bg-green-50 border border-green-200' : 'bg-yellow-50 border border-yellow-200'}`}>
                {bookingConfirmed ? (
                  <>
                    <CheckCircle className="text-green-600" size={24} />
                    <div>
                      <p className="font-medium text-green-800">Rendez-vous confirmé !</p>
                      <p className="text-sm text-green-600">
                        {activeBooking.service?.title || 'Consultation'} - {activeBooking.scheduledAt && format(parseISOAsLocal(activeBooking.scheduledAt), "HH:mm", { locale: fr })}
                      </p>
                    </div>
                  </>
                ) : (
                  <>
                    <Calendar className="text-yellow-600" size={24} />
                    <div>
                      <p className="font-medium text-yellow-800">RDV en cours...</p>
                      <p className="text-sm text-yellow-600">{activeBooking.service?.title || 'Consultation'}</p>
                    </div>
                  </>
                )}
              </div>
            )}

            {viewMode === 'hub' ? (
              <>
                {/* Pet info */}
                <div className="flex items-start space-x-4 mb-6 p-4 bg-gradient-to-r from-primary-50 to-teal-50 rounded-xl border border-primary-100">
                  <div className="w-16 h-16 bg-white rounded-xl flex items-center justify-center text-3xl shadow-sm">
                    {getSpeciesEmoji(scannedPet.species)}
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-bold text-gray-900">{scannedPet.name}</h3>
                    <p className="text-gray-600">{scannedPet.species} {scannedPet.breed && `• ${scannedPet.breed}`}</p>
                    <div className="flex flex-wrap gap-3 mt-2 text-sm text-gray-600">
                      {scannedPet.gender && (
                        <span>{scannedPet.gender === 'MALE' ? '♂️ Mâle' : '♀️ Femelle'}</span>
                      )}
                      {scannedPet.birthDate && (
                        <span>🎂 {format(new Date(scannedPet.birthDate), 'dd/MM/yyyy')}</span>
                      )}
                    </div>
                    {/* Note: User info (name, phone) not shown for privacy */}
                  </div>
                </div>

                {/* Quick stats */}
                <div className="grid grid-cols-4 gap-2 mb-6">
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <Scale className="mx-auto text-primary-500 mb-1" size={18} />
                    <p className="text-lg font-bold">{getLatestStat('WEIGHT') || '—'}</p>
                    <p className="text-xs text-gray-500">kg</p>
                  </div>
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <Thermometer className="mx-auto text-red-500 mb-1" size={18} />
                    <p className="text-lg font-bold">{getLatestStat('TEMPERATURE') || '—'}</p>
                    <p className="text-xs text-gray-500">°C</p>
                  </div>
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <Heart className="mx-auto text-pink-500 mb-1" size={18} />
                    <p className="text-lg font-bold">{getLatestStat('HEART_RATE') || '—'}</p>
                    <p className="text-xs text-gray-500">BPM</p>
                  </div>
                  <div className="p-3 bg-white rounded-xl border text-center">
                    <Syringe className="mx-auto text-green-500 mb-1" size={18} />
                    <p className="text-lg font-bold">{scannedVaccinations.length}</p>
                    <p className="text-xs text-gray-500">Vaccins</p>
                  </div>
                </div>

                {/* Action Cards */}
                <h4 className="font-bold text-gray-900 mb-4">Accès rapide</h4>
                <div className="space-y-3">
                  {/* Add record */}
                  <button onClick={() => setShowAddRecordModal(true)} className="w-full p-4 bg-gradient-to-r from-white to-primary-50 rounded-xl border-2 border-primary-200 hover:border-primary-400 transition-colors flex items-center gap-4 text-left">
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
                  <button onClick={() => setViewMode('medical-history')} className="w-full p-4 bg-gradient-to-r from-white to-blue-50 rounded-xl border-2 border-blue-200 hover:border-blue-400 transition-colors flex items-center gap-4 text-left">
                    <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl flex items-center justify-center shadow-lg shadow-blue-200">
                      <ClipboardList className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Historique médical</p>
                      <p className="text-sm text-gray-500">Consultations, diagnostics</p>
                    </div>
                    <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full font-medium">{scannedRecords.length}</span>
                  </button>

                  {/* Vaccinations */}
                  <button onClick={() => setViewMode('vaccinations')} className="w-full p-4 bg-gradient-to-r from-white to-green-50 rounded-xl border-2 border-green-200 hover:border-green-400 transition-colors flex items-center gap-4 text-left">
                    <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-green-600 rounded-xl flex items-center justify-center shadow-lg shadow-green-200">
                      <Syringe className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Vaccinations</p>
                      <p className="text-sm text-gray-500">Calendrier vaccinal</p>
                    </div>
                    <span className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">{scannedVaccinations.length}</span>
                  </button>

                  {/* Prescriptions */}
                  <button onClick={() => setViewMode('prescriptions')} className="w-full p-4 bg-gradient-to-r from-white to-purple-50 rounded-xl border-2 border-purple-200 hover:border-purple-400 transition-colors flex items-center gap-4 text-left">
                    <div className="w-12 h-12 bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg shadow-purple-200">
                      <FileText className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Ordonnances</p>
                      <p className="text-sm text-gray-500">Prescriptions médicales</p>
                    </div>
                    <span className="text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded-full font-medium">{prescriptions.length}</span>
                  </button>

                  {/* Health stats */}
                  <button onClick={() => setViewMode('health-stats')} className="w-full p-4 bg-gradient-to-r from-white to-orange-50 rounded-xl border-2 border-orange-200 hover:border-orange-400 transition-colors flex items-center gap-4 text-left">
                    <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl flex items-center justify-center shadow-lg shadow-orange-200">
                      <TrendingUp className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Statistiques de santé</p>
                      <p className="text-sm text-gray-500">Poids, température, BPM</p>
                    </div>
                    <span className="text-xs bg-orange-100 text-orange-700 px-2 py-1 rounded-full font-medium">{healthStats ? (healthStats.weight.data.length + healthStats.temperature.data.length + healthStats.heartRate.data.length) : 0}</span>
                  </button>

                  {/* Disease tracking */}
                  <button onClick={() => setViewMode('diseases')} className="w-full p-4 bg-gradient-to-r from-white to-red-50 rounded-xl border-2 border-red-200 hover:border-red-400 transition-colors flex items-center gap-4 text-left">
                    <div className="w-12 h-12 bg-gradient-to-br from-red-500 to-red-600 rounded-xl flex items-center justify-center shadow-lg shadow-red-200">
                      <AlertTriangle className="text-white" size={24} />
                    </div>
                    <div className="flex-1">
                      <p className="font-bold text-gray-900">Suivi de maladies</p>
                      <p className="text-sm text-gray-500">Pathologies en cours</p>
                    </div>
                    <span className="text-xs bg-red-100 text-red-700 px-2 py-1 rounded-full font-medium">{diseases.filter((d) => d.status !== 'RESOLVED').length}</span>
                  </button>
                </div>

                <div className="mt-6 pt-4 border-t">
                  <Button variant="secondary" onClick={closePetView} className="w-full">
                    <QrCode size={16} className="mr-2" />
                    Scanner un autre patient
                  </Button>
                </div>
              </>
            ) : viewMode === 'medical-history' ? (
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <ClipboardList className="text-blue-600" size={24} />
                  Historique médical
                </h3>
                {scannedRecords.length === 0 ? (
                  <div className="text-center py-12">
                    <FileText className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucun historique</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {scannedRecords.map((r) => {
                      const typeInfo = getRecordTypeIcon(r.type);
                      const IconComponent = typeInfo.icon;
                      const canDelete = isOwnRecord((r as any).providerId);
                      return (
                        <div key={r.id} className="p-4 bg-white border border-gray-200 rounded-xl">
                          <div className="flex items-start gap-3">
                            <div className={`p-2.5 ${typeInfo.bg} rounded-xl flex-shrink-0`}>
                              <IconComponent size={18} className={typeInfo.color} />
                            </div>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center justify-between mb-1">
                                <span className={`text-xs ${typeInfo.bg} ${typeInfo.color} px-2 py-0.5 rounded font-medium`}>{r.type}</span>
                                <div className="flex items-center gap-2">
                                  <span className="text-xs text-gray-500">{format(new Date(r.date), 'dd/MM/yyyy')}</span>
                                  {canDelete && (
                                    <button onClick={() => handleDeleteRecord(r.id)} className="text-red-400 hover:text-red-600">
                                      <Trash2 size={14} />
                                    </button>
                                  )}
                                </div>
                              </div>
                              <p className="font-semibold text-gray-900">{r.title}</p>
                              {r.description && <p className="text-sm text-gray-600 mt-1">{r.description}</p>}
                              {r.veterinarian && <p className="text-xs text-gray-400 mt-2">Dr. {r.veterinarian}</p>}
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
                    Ajouter un acte
                  </Button>
                </div>
              </>
            ) : viewMode === 'vaccinations' ? (
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <Syringe className="text-green-600" size={24} />
                  Vaccinations
                </h3>
                {scannedVaccinations.length === 0 ? (
                  <div className="text-center py-12">
                    <Syringe className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucune vaccination</p>
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
                              <p className="text-sm text-gray-500">{format(new Date(v.date), 'dd MMMM yyyy', { locale: fr })}</p>
                            </div>
                          </div>
                          {v.nextDueDate && (
                            <div className="text-right">
                              <p className="text-xs text-orange-600 font-medium">Rappel</p>
                              <p className="text-sm text-orange-700 font-semibold">{format(new Date(v.nextDueDate), 'dd/MM/yyyy')}</p>
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </>
            ) : viewMode === 'prescriptions' ? (
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <FileText className="text-purple-600" size={24} />
                  Ordonnances
                </h3>
                {prescriptions.length === 0 ? (
                  <div className="text-center py-12">
                    <FileText className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucune ordonnance</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {prescriptions.map((p) => {
                      const canDelete = isOwnRecord(p.providerId);
                      return (
                        <div key={p.id} className="p-4 bg-white border border-gray-200 rounded-xl">
                          <div className="flex items-start gap-3">
                            <div className="p-2.5 bg-purple-100 rounded-xl flex-shrink-0">
                              <FileText size={18} className="text-purple-600" />
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center justify-between mb-1">
                                <p className="font-semibold text-gray-900">{p.title}</p>
                                <div className="flex items-center gap-2">
                                  <span className="text-xs text-gray-500">{format(new Date(p.date), 'dd/MM/yyyy')}</span>
                                  {canDelete && (
                                    <>
                                      <button onClick={() => handleEditPrescription(p)} className="text-blue-400 hover:text-blue-600">
                                        <Edit2 size={14} />
                                      </button>
                                      <button onClick={() => handleDeletePrescription(p.id)} className="text-red-400 hover:text-red-600">
                                        <Trash2 size={14} />
                                      </button>
                                    </>
                                  )}
                                </div>
                              </div>
                              {p.description && <p className="text-sm text-gray-600">{p.description}</p>}
                              {p.imageUrl && (
                                <a href={p.imageUrl} target="_blank" rel="noopener noreferrer" className="mt-2 inline-flex items-center gap-1 text-sm text-purple-600 hover:text-purple-800">
                                  <Image size={14} />
                                  Voir l'ordonnance
                                </a>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
                <div className="mt-6">
                  <Button onClick={() => setShowAddPrescriptionModal(true)} className="w-full">
                    <Plus size={16} className="mr-2" />
                    Ajouter une ordonnance
                  </Button>
                </div>
              </>
            ) : viewMode === 'health-stats' ? (
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <TrendingUp className="text-orange-600" size={24} />
                  Statistiques de santé
                </h3>
                {!healthStats || (healthStats.weight.data.length === 0 && healthStats.temperature.data.length === 0 && healthStats.heartRate.data.length === 0) ? (
                  <div className="text-center py-12">
                    <TrendingUp className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucune mesure</p>
                    <p className="text-sm text-gray-400 mt-2">Les mesures sont enregistrées lors des visites vétérinaires</p>
                  </div>
                ) : (
                  <div className="space-y-6">
                    {/* Weight history */}
                    {healthStats.weight.data.length > 0 && (
                      <div>
                        <h4 className="font-medium text-gray-700 mb-3 flex items-center gap-2">
                          <Scale size={16} className="text-primary-600" />
                          Poids ({healthStats.weight.current?.toFixed(1)} kg actuel)
                        </h4>
                        <div className="space-y-2">
                          {healthStats.weight.data.slice(-5).reverse().map((w, i) => (
                            <div key={i} className="p-3 bg-white border border-gray-200 rounded-lg flex items-center justify-between">
                              <span className="font-semibold text-gray-900">{w.weightKg.toFixed(1)} kg</span>
                              <div className="text-right">
                                <span className="text-xs text-gray-500">{format(new Date(w.date), 'dd/MM/yyyy')}</span>
                                {w.context && <p className="text-xs text-gray-400">{w.context}</p>}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    {/* Temperature history */}
                    {healthStats.temperature.data.length > 0 && (
                      <div>
                        <h4 className="font-medium text-gray-700 mb-3 flex items-center gap-2">
                          <Thermometer size={16} className="text-red-600" />
                          Température ({healthStats.temperature.current?.toFixed(1)}°C actuel)
                        </h4>
                        <div className="space-y-2">
                          {healthStats.temperature.data.slice(-5).reverse().map((t, i) => (
                            <div key={i} className="p-3 bg-white border border-gray-200 rounded-lg flex items-center justify-between">
                              <span className="font-semibold text-gray-900">{t.temperatureC.toFixed(1)}°C</span>
                              <div className="text-right">
                                <span className="text-xs text-gray-500">{format(new Date(t.date), 'dd/MM/yyyy')}</span>
                                {t.context && <p className="text-xs text-gray-400">{t.context}</p>}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    {/* Heart rate history */}
                    {healthStats.heartRate.data.length > 0 && (
                      <div>
                        <h4 className="font-medium text-gray-700 mb-3 flex items-center gap-2">
                          <Heart size={16} className="text-pink-600" />
                          Fréquence cardiaque ({healthStats.heartRate.current} BPM actuel)
                        </h4>
                        <div className="space-y-2">
                          {healthStats.heartRate.data.slice(-5).reverse().map((h, i) => (
                            <div key={i} className="p-3 bg-white border border-gray-200 rounded-lg flex items-center justify-between">
                              <span className="font-semibold text-gray-900">{h.heartRate} BPM</span>
                              <div className="text-right">
                                <span className="text-xs text-gray-500">{format(new Date(h.date), 'dd/MM/yyyy')}</span>
                                {h.context && <p className="text-xs text-gray-400">{h.context}</p>}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
                <p className="text-xs text-gray-400 text-center mt-4">
                  Les statistiques sont automatiquement enregistrées lors des consultations vétérinaires
                </p>
              </>
            ) : viewMode === 'diseases' ? (
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <AlertTriangle className="text-red-600" size={24} />
                  Suivi de maladies
                </h3>
                {diseases.length === 0 ? (
                  <div className="text-center py-12">
                    <AlertTriangle className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucun suivi</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {diseases.map((d) => {
                      const canDelete = isOwnRecord(d.providerId);
                      const statusColor = d.status === 'ACTIVE' ? 'bg-red-100 text-red-700' : d.status === 'MONITORING' ? 'bg-yellow-100 text-yellow-700' : 'bg-green-100 text-green-700';
                      return (
                        <div key={d.id} className="p-4 bg-white border border-gray-200 rounded-xl">
                          <div className="flex items-start gap-3">
                            <div className="p-2.5 bg-red-100 rounded-xl flex-shrink-0">
                              <AlertTriangle size={18} className="text-red-600" />
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center justify-between mb-1">
                                <div className="flex items-center gap-2">
                                  <p className="font-semibold text-gray-900">{d.name}</p>
                                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor}`}>
                                    {d.status === 'ACTIVE' ? 'Actif' : d.status === 'MONITORING' ? 'Surveillance' : 'Résolu'}
                                  </span>
                                </div>
                                {canDelete && (
                                  <div className="flex items-center gap-2">
                                    <button onClick={() => handleEditDisease(d)} className="text-blue-400 hover:text-blue-600">
                                      <Edit2 size={14} />
                                    </button>
                                    <button onClick={() => handleDeleteDisease(d.id)} className="text-red-400 hover:text-red-600">
                                      <Trash2 size={14} />
                                    </button>
                                  </div>
                                )}
                              </div>
                              {d.description && <p className="text-sm text-gray-600">{d.description}</p>}
                              <p className="text-xs text-gray-400 mt-1">Diagnostiqué le {format(new Date(d.diagnosedDate), 'dd/MM/yyyy')}</p>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
                <div className="mt-6">
                  <Button onClick={() => setShowAddDiseaseModal(true)} className="w-full">
                    <Plus size={16} className="mr-2" />
                    Ajouter un suivi
                  </Button>
                </div>
              </>
            ) : null}
          </Card>
        ) : (
          <Card className="text-center py-12">
            <div className="w-24 h-24 bg-primary-100 rounded-full flex items-center justify-center mx-auto mb-6">
              <QrCode size={48} className="text-primary-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Scanner un patient</h2>
            <p className="text-gray-500 mb-8">Scannez le QR code du carnet de santé</p>
            {scanLoading ? (
              <div className="flex items-center justify-center gap-3">
                <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
                <span className="text-gray-600">Chargement...</span>
              </div>
            ) : (
              <>
                <div className="flex flex-col sm:flex-row gap-4 justify-center max-w-md mx-auto">
                  <Button onClick={startQrScanner} size="lg" className="flex-1">
                    <Monitor size={20} className="mr-2" />
                    Scanner avec PC
                  </Button>
                  <div className="flex-1 flex items-center justify-center gap-2 py-3 px-4 bg-green-50 border border-green-200 rounded-lg text-green-700">
                    <Smartphone size={20} />
                    <span className="text-sm font-medium">Écoute mobile active</span>
                    <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                  </div>
                </div>

                {/* Séparateur */}
                <div className="flex items-center gap-4 my-6 max-w-md mx-auto">
                  <div className="flex-1 h-px bg-gray-200" />
                  <span className="text-sm text-gray-400">ou</span>
                  <div className="flex-1 h-px bg-gray-200" />
                </div>

                {/* Bouton code de référence */}
                <Button
                  onClick={() => setShowReferenceCodeModal(true)}
                  variant="secondary"
                  size="lg"
                  className="max-w-md mx-auto w-full border-2 border-dashed border-primary-300 hover:border-primary-500 bg-primary-50"
                >
                  <Hash size={20} className="mr-2" />
                  Code de référence du dossier
                </Button>
                <p className="text-xs text-gray-400 mt-2">
                  Pour les clients sans QR code (ex: VGC-A2B3C4)
                </p>
              </>
            )}
          </Card>
        )}

        {/* Recent Patients Section (24h access) - Only show when no pet is scanned */}
        {!scannedPet && (
          <div className="mt-8">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-bold text-gray-900">Patients récents</h2>
                <p className="text-sm text-gray-500 flex items-center gap-1">
                  <Clock size={14} />
                  Accès limité à 24h après le RDV
                </p>
              </div>
            </div>

            {loadingRecentPatients ? (
              <Card className="text-center py-8">
                <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600 mx-auto" />
                <p className="text-gray-500 mt-3 text-sm">Chargement...</p>
              </Card>
            ) : recentPatients.length === 0 ? (
              <Card className="text-center py-8">
                <p className="text-gray-500">Aucun patient récent</p>
                <p className="text-xs text-gray-400 mt-1">Les patients apparaîtront après un RDV confirmé</p>
              </Card>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {recentPatients.map((patient) => (
                  <Card
                    key={patient.pet.id}
                    className="cursor-pointer hover:border-primary-300 hover:shadow-md transition-all"
                    onClick={() => selectRecentPatient(patient)}
                    padding="sm"
                  >
                    <div className="flex items-start gap-3">
                      {/* Pet photo or emoji fallback */}
                      {patient.pet.photoUrl ? (
                        <img
                          src={patient.pet.photoUrl}
                          alt={patient.pet.name}
                          className="w-14 h-14 rounded-xl object-cover flex-shrink-0 border-2 border-primary-100"
                        />
                      ) : (
                        <div className="w-14 h-14 bg-primary-100 rounded-xl flex items-center justify-center text-2xl flex-shrink-0">
                          {getSpeciesEmoji(patient.pet.species)}
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2">
                          <h3 className="font-bold text-gray-900 truncate">{patient.pet.name}</h3>
                          <span className={`text-xs px-2 py-0.5 rounded-full flex items-center gap-1 flex-shrink-0 ${
                            patient.hoursRemaining <= 2 ? 'bg-red-100 text-red-700' :
                            patient.hoursRemaining <= 6 ? 'bg-orange-100 text-orange-700' :
                            'bg-green-100 text-green-700'
                          }`}>
                            <Clock size={10} />
                            {patient.hoursRemaining}h
                          </span>
                        </div>
                        <p className="text-sm text-gray-600 truncate">
                          {patient.pet.species} {patient.pet.breed && `• ${patient.pet.breed}`}
                        </p>
                        <div className="flex items-center gap-2 mt-1">
                          <p className="text-xs text-primary-600 truncate">
                            🩺 {patient.booking.service?.title || 'Consultation'}
                          </p>
                          <span className="text-xs text-gray-400">•</span>
                          <p className="text-xs font-medium text-gray-700">
                            {format(parseISOAsLocal(patient.booking.scheduledAt), 'HH:mm', { locale: fr })}
                          </p>
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* QR Scanner Modal */}
      {showQrScanner && (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Scanner QR Code</h2>
              <button onClick={stopQrScanner} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
            </div>
            {qrError ? (
              <div className="text-red-500 text-center py-8">{qrError}</div>
            ) : (
              <div id="qr-reader" className="w-full" />
            )}
            <p className="text-sm text-gray-500 text-center mt-4">Pointez vers le QR code</p>
            <div className="mt-4 pt-4 border-t">
              <p className="text-sm text-gray-600 mb-2">Ou entrez le token:</p>
              <Input
                placeholder="Token"
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && e.currentTarget.value) {
                    stopQrScanner();
                    handleQrResult(e.currentTarget.value);
                  }
                }}
              />
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
                <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
                <select value={newRecord.type} onChange={(e) => setNewRecord({ ...newRecord, type: e.target.value })} className="w-full px-3 py-2 border rounded-lg">
                  <option value="CONSULTATION">Consultation</option>
                  <option value="VACCINATION">Vaccination</option>
                  <option value="SURGERY">Chirurgie</option>
                  <option value="TREATMENT">Traitement</option>
                  <option value="DIAGNOSTIC">Diagnostic</option>
                  <option value="OTHER">Autre</option>
                </select>
              </div>
              <Input label="Titre" placeholder="Ex: Consultation de routine" value={newRecord.title} onChange={(e) => setNewRecord({ ...newRecord, title: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea rows={3} placeholder="Notes..." value={newRecord.description} onChange={(e) => setNewRecord({ ...newRecord, description: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddRecordModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddRecord} isLoading={addingRecord} disabled={!newRecord.title}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Prescription Modal */}
      {showAddPrescriptionModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4">Ajouter une ordonnance</h2>
            <div className="space-y-4">
              <Input label="Titre" placeholder="Ex: Antibiotiques" value={newPrescription.title} onChange={(e) => setNewPrescription({ ...newPrescription, title: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea rows={3} placeholder="Posologie, durée..." value={newPrescription.description} onChange={(e) => setNewPrescription({ ...newPrescription, description: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Image (optionnel)</label>
                {newPrescription.imageUrl ? (
                  <div className="relative">
                    <img src={newPrescription.imageUrl} alt="Ordonnance" className="w-full h-32 object-cover rounded-lg" />
                    <button onClick={() => setNewPrescription({ ...newPrescription, imageUrl: '' })} className="absolute top-2 right-2 bg-red-500 text-white p-1 rounded-full"><X size={14} /></button>
                  </div>
                ) : (
                  <label className="flex items-center justify-center w-full h-32 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-primary-400">
                    <input type="file" accept="image/*" onChange={handleImageUpload} className="hidden" />
                    {uploadingImage ? (
                      <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
                    ) : (
                      <div className="text-center">
                        <Upload className="mx-auto text-gray-400 mb-2" size={24} />
                        <span className="text-sm text-gray-500">Téléverser une image</span>
                      </div>
                    )}
                  </label>
                )}
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddPrescriptionModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddPrescription} isLoading={addingPrescription} disabled={!newPrescription.title}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Disease Modal */}
      {showAddDiseaseModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4">Ajouter un suivi de maladie</h2>
            <div className="space-y-4">
              <Input label="Nom de la pathologie" placeholder="Ex: Otite" value={newDisease.name} onChange={(e) => setNewDisease({ ...newDisease, name: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea rows={3} placeholder="Symptômes, observations..." value={newDisease.description} onChange={(e) => setNewDisease({ ...newDisease, description: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Statut</label>
                <select value={newDisease.status} onChange={(e) => setNewDisease({ ...newDisease, status: e.target.value })} className="w-full px-3 py-2 border rounded-lg">
                  <option value="ACTIVE">Actif</option>
                  <option value="MONITORING">Surveillance</option>
                  <option value="RESOLVED">Résolu</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddDiseaseModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddDisease} isLoading={addingDisease} disabled={!newDisease.name}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Edit Prescription Modal */}
      {showEditPrescriptionModal && editingPrescription && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4">Modifier l'ordonnance</h2>
            <div className="space-y-4">
              <Input label="Titre" placeholder="Ex: Antibiotiques" value={editingPrescription.title} onChange={(e) => setEditingPrescription({ ...editingPrescription, title: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea rows={3} placeholder="Posologie, durée..." value={editingPrescription.description || ''} onChange={(e) => setEditingPrescription({ ...editingPrescription, description: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              {editingPrescription.imageUrl && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Image actuelle</label>
                  <a href={editingPrescription.imageUrl} target="_blank" rel="noopener noreferrer" className="text-sm text-purple-600 hover:text-purple-800 flex items-center gap-1">
                    <Image size={14} />
                    Voir l'ordonnance
                  </a>
                </div>
              )}
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => { setShowEditPrescriptionModal(false); setEditingPrescription(null); }}>Annuler</Button>
              <Button className="flex-1" onClick={handleSavePrescription} isLoading={savingPrescription} disabled={!editingPrescription.title}>Enregistrer</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Edit Disease Modal */}
      {showEditDiseaseModal && editingDisease && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4">Modifier le suivi de maladie</h2>
            <div className="space-y-4">
              <Input label="Nom de la pathologie" placeholder="Ex: Otite" value={editingDisease.name} onChange={(e) => setEditingDisease({ ...editingDisease, name: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea rows={3} placeholder="Symptômes, observations..." value={editingDisease.description || ''} onChange={(e) => setEditingDisease({ ...editingDisease, description: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Statut</label>
                <select value={editingDisease.status} onChange={(e) => setEditingDisease({ ...editingDisease, status: e.target.value as "ACTIVE" | "MONITORING" | "RESOLVED" })} className="w-full px-3 py-2 border rounded-lg">
                  <option value="ACTIVE">Actif</option>
                  <option value="MONITORING">Surveillance</option>
                  <option value="RESOLVED">Résolu</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
                <textarea rows={2} placeholder="Notes additionnelles..." value={editingDisease.notes || ''} onChange={(e) => setEditingDisease({ ...editingDisease, notes: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => { setShowEditDiseaseModal(false); setEditingDisease(null); }}>Annuler</Button>
              <Button className="flex-1" onClick={handleSaveDisease} isLoading={savingDisease} disabled={!editingDisease.name}>Enregistrer</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Reference Code Modal */}
      {showReferenceCodeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold flex items-center gap-2">
                <Hash size={20} className="text-primary-600" />
                Code de référence
              </h2>
              <button onClick={() => { setShowReferenceCodeModal(false); setReferenceCode(''); }} className="text-gray-400 hover:text-gray-600">
                <X size={20} />
              </button>
            </div>

            <p className="text-sm text-gray-600 mb-4">
              Entrez le code de référence donné par le client pour confirmer son rendez-vous et accéder à son carnet de santé.
            </p>

            <div className="space-y-4">
              <Input
                label="Code de référence"
                placeholder="VGC-A2B3C4"
                value={referenceCode}
                onChange={(e) => setReferenceCode(e.target.value.toUpperCase())}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && referenceCode.trim()) {
                    handleConfirmByReferenceCode();
                  }
                }}
                className="text-center text-xl font-mono tracking-widest"
              />

              <div className="bg-gray-50 rounded-lg p-3">
                <p className="text-xs text-gray-500 flex items-start gap-2">
                  <span className="text-primary-600">💡</span>
                  Le code de référence est au format VGC-XXXXXX (6 caractères après le tiret).
                  Il est visible sur l'application du client lors de son rendez-vous.
                </p>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <Button
                variant="secondary"
                className="flex-1"
                onClick={() => { setShowReferenceCodeModal(false); setReferenceCode(''); }}
              >
                Annuler
              </Button>
              <Button
                className="flex-1"
                onClick={handleConfirmByReferenceCode}
                isLoading={confirmingByCode}
                disabled={!referenceCode.trim() || referenceCode.trim().length < 6}
              >
                <CheckCircle size={16} className="mr-2" />
                Confirmer le RDV
              </Button>
            </div>
          </Card>
        </div>
      )}
    </DashboardLayout>
  );
}
