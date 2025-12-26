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
  Eye,
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
    addRecord: _addRecord,
    addPrescription,
    addDisease,
    editPrescription,
    editDisease,
    removeRecord,
    removePrescription,
    removeDisease,
    updateDiseases,
    clearPet,
    isPolling: _isPolling,
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
  const [_showAddRecordModal, _setShowAddRecordModal] = useState(false);
  const [showAddPrescriptionModal, setShowAddPrescriptionModal] = useState(false);
  const [showAddDiseaseModal, setShowAddDiseaseModal] = useState(false);
  const [showAddVaccinationModal, setShowAddVaccinationModal] = useState(false);
  const [showAddWeightModal, setShowAddWeightModal] = useState(false);
  const [showEditPrescriptionModal, setShowEditPrescriptionModal] = useState(false);
  const [showEditDiseaseModal, setShowEditDiseaseModal] = useState(false);
  const [showReferenceCodeModal, setShowReferenceCodeModal] = useState(false);

  // Reference code state
  const [referenceCode, setReferenceCode] = useState('');
  const [confirmingByCode, setConfirmingByCode] = useState(false);

  // Form states
  const [_newRecord, _setNewRecord] = useState({ title: '', type: 'CONSULTATION', description: '', temperatureC: '', heartRate: '' });
  const [newPrescription, setNewPrescription] = useState({ name: '', dosage: '', frequency: '', startDate: new Date().toISOString().split('T')[0], endDate: '', notes: '', attachments: [] as string[] });
  const [newDisease, setNewDisease] = useState({ name: '', description: '', status: 'ONGOING', severity: '', symptoms: '', treatment: '', notes: '', images: [] as string[] });
  const [newVaccination, setNewVaccination] = useState({ name: '', date: '', nextDueDate: '', batchNumber: '', notes: '' });
  const [newWeight, setNewWeight] = useState({ weightKg: '', date: new Date().toISOString().split('T')[0], context: '' });
  const [newHealthData, setNewHealthData] = useState({ temperatureC: '', heartRate: '', date: new Date().toISOString().split('T')[0], notes: '' });
  const [showAddHealthDataModal, setShowAddHealthDataModal] = useState(false);
  const [addingHealthData, setAddingHealthData] = useState(false);

  // Disease detail modal
  const [showDiseaseDetailModal, setShowDiseaseDetailModal] = useState(false);
  const [selectedDisease, setSelectedDisease] = useState<DiseaseTracking | null>(null);
  const [showAddProgressModal, setShowAddProgressModal] = useState(false);
  const [newProgress, setNewProgress] = useState({ notes: '', severity: '', treatmentUpdate: '', images: [] as string[] });
  const [addingProgress, setAddingProgress] = useState(false);

  // Image preview modal
  const [showImagePreviewModal, setShowImagePreviewModal] = useState(false);
  const [previewImageUrl, setPreviewImageUrl] = useState<string | null>(null);

  // Edit states
  const [editingPrescription, setEditingPrescription] = useState<Prescription | null>(null);
  const [editingDisease, setEditingDisease] = useState<DiseaseTracking | null>(null);

  // Loading states
  const [_addingRecord, _setAddingRecord] = useState(false);
  const [addingPrescription, setAddingPrescription] = useState(false);
  const [addingDisease, setAddingDisease] = useState(false);
  const [addingVaccination, setAddingVaccination] = useState(false);
  const [addingWeight, setAddingWeight] = useState(false);
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

  // Load diseases when switching to diseases view if empty
  useEffect(() => {
    if (viewMode === 'diseases' && diseases.length === 0 && currentToken && scannedPet) {
      (async () => {
        try {
          const loadedDiseases = await api.listDiseasesByToken(currentToken);
          if (loadedDiseases.length > 0) {
            updateDiseases(loadedDiseases);
          }
        } catch (error) {
          console.error('Error loading diseases:', error);
        }
      })();
    }
  }, [viewMode, diseases.length, currentToken, scannedPet, updateDiseases]);

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

      // Filter only COMPLETED bookings with a pet
      // (patient visible only after QR scan, reference code, or validation - not simple confirmation)
      const validBookings = bookings.filter(
        (b: Booking) =>
          b.status === 'COMPLETED' &&
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

      // Build health stats from the token response data (same as Flutter polling)
      const petData = result.pet as any;
      const medicalRecords = result.medicalRecords || [];
      const weightRecords = petData.weightRecords || [];

      // Extract health data from medical records
      const tempData = medicalRecords
        .filter((r: any) => r.temperatureC != null)
        .map((r: any) => ({ date: r.date, temperatureC: r.temperatureC }));
      const heartData = medicalRecords
        .filter((r: any) => r.heartRate != null)
        .map((r: any) => ({ date: r.date, heartRate: r.heartRate }));

      let healthStats: any = null;
      if (weightRecords.length > 0 || tempData.length > 0 || heartData.length > 0) {
        healthStats = {
          weight: weightRecords.length > 0 ? {
            current: weightRecords[0]?.weightKg,
            min: Math.min(...weightRecords.map((w: any) => parseFloat(w.weightKg))),
            max: Math.max(...weightRecords.map((w: any) => parseFloat(w.weightKg))),
            data: weightRecords,
          } : undefined,
          temperature: tempData.length > 0 ? {
            current: tempData[0]?.temperatureC,
            average: tempData.reduce((a: number, b: any) => a + parseFloat(b.temperatureC), 0) / tempData.length,
            data: tempData,
          } : undefined,
          heartRate: heartData.length > 0 ? {
            current: heartData[0]?.heartRate,
            average: Math.round(heartData.reduce((a: number, b: any) => a + b.heartRate, 0) / heartData.length),
            data: heartData,
          } : undefined,
        };
      }

      // Map diseaseTrackings to diseases (data comes from getPetByToken)
      // If not included in petData, load via API
      let diseases = (petData.diseaseTrackings || []);
      if (diseases.length === 0) {
        try {
          diseases = await api.listDiseasesByToken(token);
        } catch {
          // Diseases not available - that's ok
        }
      }
      // Map treatments to prescriptions format (Flutter uses treatments for "Ordonnances")
      const treatments = petData.treatments || [];
      const prescriptions = treatments.map((t: any) => ({
        id: t.id,
        petId: t.petId,
        providerId: t.providerId || null,
        title: t.name,
        description: [t.dosage, t.frequency, t.notes].filter(Boolean).join(' - '),
        imageUrl: t.attachments?.[0] || null,
        attachments: t.attachments || [],
        date: t.startDate,
        isActive: t.isActive,
        endDate: t.endDate,
      }));

      setPetData(
        result.pet,
        token,
        medicalRecords,
        result.vaccinations || [],
        prescriptions,
        healthStats,
        diseases
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

      // Build health stats from the token response data
      const petData = result.pet as any;
      const medicalRecords = result.medicalRecords || [];
      const weightRecords = petData.weightRecords || [];

      const tempData = medicalRecords
        .filter((r: any) => r.temperatureC != null)
        .map((r: any) => ({ date: r.date, temperatureC: r.temperatureC }));
      const heartData = medicalRecords
        .filter((r: any) => r.heartRate != null)
        .map((r: any) => ({ date: r.date, heartRate: r.heartRate }));

      let healthStats: any = null;
      if (weightRecords.length > 0 || tempData.length > 0 || heartData.length > 0) {
        healthStats = {
          weight: weightRecords.length > 0 ? {
            current: weightRecords[0]?.weightKg,
            min: Math.min(...weightRecords.map((w: any) => parseFloat(w.weightKg))),
            max: Math.max(...weightRecords.map((w: any) => parseFloat(w.weightKg))),
            data: weightRecords,
          } : undefined,
          temperature: tempData.length > 0 ? {
            current: tempData[0]?.temperatureC,
            average: tempData.reduce((a: number, b: any) => a + parseFloat(b.temperatureC), 0) / tempData.length,
            data: tempData,
          } : undefined,
          heartRate: heartData.length > 0 ? {
            current: heartData[0]?.heartRate,
            average: Math.round(heartData.reduce((a: number, b: any) => a + b.heartRate, 0) / heartData.length),
            data: heartData,
          } : undefined,
        };
      }

      const diseases = (petData.diseaseTrackings || []);
      // Map treatments to prescriptions format (Flutter uses treatments for "Ordonnances")
      const treatments = petData.treatments || [];
      const prescriptions = treatments.map((t: any) => ({
        id: t.id,
        petId: t.petId,
        providerId: t.providerId || null,
        title: t.name,
        description: [t.dosage, t.frequency, t.notes].filter(Boolean).join(' - '),
        imageUrl: t.attachments?.[0] || null,
        attachments: t.attachments || [],
        date: t.startDate,
        isActive: t.isActive,
        endDate: t.endDate,
      }));

      setPetData(
        result.pet,
        token,
        medicalRecords,
        result.vaccinations || [],
        prescriptions,
        healthStats,
        diseases
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
        // Build health stats from the pet data
        const petData = result.pet as any;
        const medicalRecords = petData.medicalRecords || [];
        const weightRecords = petData.weightRecords || [];

        const tempData = medicalRecords
          .filter((r: any) => r.temperatureC != null)
          .map((r: any) => ({ date: r.date, temperatureC: r.temperatureC }));
        const heartData = medicalRecords
          .filter((r: any) => r.heartRate != null)
          .map((r: any) => ({ date: r.date, heartRate: r.heartRate }));

        let healthStats: any = null;
        if (weightRecords.length > 0 || tempData.length > 0 || heartData.length > 0) {
          healthStats = {
            weight: weightRecords.length > 0 ? {
              current: weightRecords[0]?.weightKg,
              min: Math.min(...weightRecords.map((w: any) => parseFloat(w.weightKg))),
              max: Math.max(...weightRecords.map((w: any) => parseFloat(w.weightKg))),
              data: weightRecords,
            } : undefined,
            temperature: tempData.length > 0 ? {
              current: tempData[0]?.temperatureC,
              average: tempData.reduce((a: number, b: any) => a + parseFloat(b.temperatureC), 0) / tempData.length,
              data: tempData,
            } : undefined,
            heartRate: heartData.length > 0 ? {
              current: heartData[0]?.heartRate,
              average: Math.round(heartData.reduce((a: number, b: any) => a + b.heartRate, 0) / heartData.length),
              data: heartData,
            } : undefined,
          };
        }

        const diseases = (petData.diseaseTrackings || []);
        // Map treatments to prescriptions format (Flutter uses treatments for "Ordonnances")
        const treatments = petData.treatments || [];
        const prescriptions = treatments.map((t: any) => ({
          id: t.id,
          petId: t.petId,
          providerId: t.providerId || null,
          title: t.name,
          description: [t.dosage, t.frequency, t.notes].filter(Boolean).join(' - '),
          imageUrl: t.attachments?.[0] || null,
          date: t.startDate,
          isActive: t.isActive,
          endDate: t.endDate,
        }));

        // Set pet data in context
        setPetData(
          result.pet,
          result.accessToken,
          medicalRecords,
          petData.vaccinations || [],
          prescriptions,
          healthStats,
          diseases
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

  // Handle image upload for prescription (add to attachments array)
  const handlePrescriptionImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      alert('Veuillez sélectionner une image');
      return;
    }

    setUploadingImage(true);
    try {
      const url = await api.uploadFile(file);
      setNewPrescription((prev) => ({ ...prev, attachments: [...prev.attachments, url] }));
    } catch (error) {
      console.error('Upload error:', error);
      alert("Erreur lors du téléversement de l'image");
    } finally {
      setUploadingImage(false);
    }
  };

  const removePrescriptionImage = (index: number) => {
    setNewPrescription((prev) => ({
      ...prev,
      attachments: prev.attachments.filter((_, i) => i !== index)
    }));
  };

  // Disease image upload handlers
  const [uploadingDiseaseImage, setUploadingDiseaseImage] = useState(false);

  const handleDiseaseImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      alert('Veuillez sélectionner une image');
      return;
    }

    setUploadingDiseaseImage(true);
    try {
      const url = await api.uploadFile(file);
      console.log('📷 Disease image uploaded:', url);
      if (url && typeof url === 'string' && url.length > 0) {
        setNewDisease((prev) => ({ ...prev, images: [...prev.images, url] }));
      } else {
        console.error('Invalid upload URL:', url);
        alert("Erreur: URL de l'image invalide");
      }
    } catch (error) {
      console.error('Upload error:', error);
      alert("Erreur lors du téléversement de l'image");
    } finally {
      setUploadingDiseaseImage(false);
    }
  };

  const removeDiseaseImage = (index: number) => {
    setNewDisease((prev) => ({
      ...prev,
      images: prev.images.filter((_, i) => i !== index)
    }));
  };

  const handleProgressImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      alert('Veuillez sélectionner une image');
      return;
    }

    setUploadingDiseaseImage(true);
    try {
      const url = await api.uploadFile(file);
      setNewProgress((prev) => ({ ...prev, images: [...prev.images, url] }));
    } catch (error) {
      console.error('Upload error:', error);
      alert("Erreur lors du téléversement de l'image");
    } finally {
      setUploadingDiseaseImage(false);
    }
  };

  const removeProgressImage = (index: number) => {
    setNewProgress((prev) => ({
      ...prev,
      images: prev.images.filter((_, i) => i !== index)
    }));
  };

  // Add handlers
  const handleAddPrescription = async () => {
    if (!currentToken || !newPrescription.name) return;
    setAddingPrescription(true);
    try {
      // Filter out any null/undefined attachments
      const validAttachments = newPrescription.attachments.filter((url): url is string => !!url);
      // Use treatments API (Flutter uses treatments for "Ordonnances")
      const treatment = await api.createTreatmentByToken(currentToken, {
        name: newPrescription.name,
        dosage: newPrescription.dosage || undefined,
        frequency: newPrescription.frequency || undefined,
        startDate: newPrescription.startDate || undefined,
        endDate: newPrescription.endDate || undefined,
        notes: newPrescription.notes || undefined,
        attachments: validAttachments.length > 0 ? validAttachments : undefined,
      });
      // Map treatment to prescription format for display
      const prescriptionForDisplay = {
        id: treatment.id,
        petId: treatment.petId,
        providerId: treatment.providerId || null,
        title: treatment.name,
        description: [treatment.dosage, treatment.frequency, treatment.notes].filter(Boolean).join(' - '),
        imageUrl: treatment.attachments?.[0] || null,
        date: treatment.startDate,
        isActive: treatment.isActive,
        endDate: treatment.endDate,
      };
      addPrescription(prescriptionForDisplay as any);
      setShowAddPrescriptionModal(false);
      setNewPrescription({ name: '', dosage: '', frequency: '', startDate: new Date().toISOString().split('T')[0], endDate: '', notes: '', attachments: [] });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout de l'ordonnance");
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
        severity: newDisease.severity || undefined,
        symptoms: newDisease.symptoms || undefined,
        treatment: newDisease.treatment || undefined,
        notes: newDisease.notes || undefined,
        images: newDisease.images.length > 0 ? newDisease.images : undefined,
      });
      addDisease(disease);
      setShowAddDiseaseModal(false);
      setNewDisease({ name: '', description: '', status: 'ONGOING', severity: '', symptoms: '', treatment: '', notes: '', images: [] });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout");
    } finally {
      setAddingDisease(false);
    }
  };

  const handleViewDiseaseDetail = async (disease: DiseaseTracking) => {
    if (!currentToken) return;
    try {
      // Fetch fresh disease data with progress entries
      const freshDisease = await api.getDiseaseByToken(currentToken, disease.id);
      setSelectedDisease(freshDisease);
      setShowDiseaseDetailModal(true);
    } catch (error) {
      console.error('Error fetching disease:', error);
      // Fallback to existing data
      setSelectedDisease(disease);
      setShowDiseaseDetailModal(true);
    }
  };

  const handleAddProgress = async () => {
    if (!currentToken || !selectedDisease || !newProgress.notes) return;
    setAddingProgress(true);
    try {
      await api.addProgressEntryByToken(currentToken, selectedDisease.id, {
        notes: newProgress.notes,
        severity: newProgress.severity || undefined,
        treatmentUpdate: newProgress.treatmentUpdate || undefined,
        images: newProgress.images.length > 0 ? newProgress.images : undefined,
      });
      // Refresh disease detail
      const freshDisease = await api.getDiseaseByToken(currentToken, selectedDisease.id);
      setSelectedDisease(freshDisease);
      // Also refresh diseases list
      const diseases = await api.listDiseasesByToken(currentToken);
      // Update via context's updateDiseases if available, otherwise refresh all
      if (scannedPet) {
        const result = await api.getPetByToken(currentToken);
        if (result) {
          setPetData(result.pet, currentToken, result.medicalRecords || [], result.vaccinations || [], [], null, diseases);
        }
      }
      setShowAddProgressModal(false);
      setNewProgress({ notes: '', severity: '', treatmentUpdate: '', images: [] });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout de la mise à jour");
    } finally {
      setAddingProgress(false);
    }
  };

  const handleAddVaccination = async () => {
    if (!currentToken || !newVaccination.name) return;
    setAddingVaccination(true);
    try {
      await api.createVaccinationByToken(currentToken, {
        name: newVaccination.name,
        date: newVaccination.date || undefined,
        nextDueDate: newVaccination.nextDueDate || undefined,
        batchNumber: newVaccination.batchNumber || undefined,
        notes: newVaccination.notes || undefined,
      });
      // Add to local state (need to update context to support this)
      // For now, just refresh the pet data
      if (scannedPet && currentToken) {
        const result = await api.getPetByToken(currentToken);
        if (result) {
          const [presc, stats, dis] = await Promise.all([
            api.getPetPrescriptions(result.pet.id).catch(() => []),
            api.getPetHealthStats(result.pet.id).catch(() => null),
            api.getPetDiseases(result.pet.id).catch(() => []),
          ]);
          setPetData(result.pet, currentToken, result.medicalRecords || [], result.vaccinations || [], presc, stats, dis);
        }
      }
      setShowAddVaccinationModal(false);
      setNewVaccination({ name: '', date: '', nextDueDate: '', batchNumber: '', notes: '' });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout de la vaccination");
    } finally {
      setAddingVaccination(false);
    }
  };

  const handleAddWeight = async () => {
    if (!currentToken || !newWeight.weightKg) return;
    const weightValue = parseFloat(newWeight.weightKg);
    if (isNaN(weightValue) || weightValue <= 0) {
      alert('Veuillez entrer un poids valide');
      return;
    }
    setAddingWeight(true);
    try {
      await api.createWeightRecordByToken(currentToken, {
        weightKg: weightValue,
        date: newWeight.date || undefined,
        context: newWeight.context || undefined,
      });
      // Refresh pet data to update health stats
      if (scannedPet && currentToken) {
        const result = await api.getPetByToken(currentToken);
        if (result?.pet) {
          const petData = result.pet as any;
          const medicalRecords = petData.medicalRecords || result.medicalRecords || [];
          const treatments = petData.treatments || [];
          const prescriptions = treatments.map((t: any) => ({
            id: t.id, petId: t.petId, providerId: t.providerId || null, title: t.name,
            description: [t.dosage, t.frequency, t.notes].filter(Boolean).join(' - '),
            imageUrl: t.attachments?.[0] || null, attachments: t.attachments || [],
            date: t.startDate, isActive: t.isActive, endDate: t.endDate,
          }));
          // Build health stats from weightRecords and medicalRecords
          const weightRecords = petData.weightRecords || [];
          const tempData = medicalRecords.filter((r: any) => r.temperatureC).map((r: any) => ({ temperatureC: r.temperatureC, date: r.date }));
          const heartData = medicalRecords.filter((r: any) => r.heartRate).map((r: any) => ({ heartRate: r.heartRate, date: r.date }));
          const healthStats: any = {
            petId: result.pet.id,
            weight: weightRecords.length > 0 ? { current: weightRecords[0]?.weightKg, data: weightRecords } : undefined,
            temperature: tempData.length > 0 ? { current: tempData[0]?.temperatureC, average: tempData.reduce((a: number, b: any) => a + parseFloat(b.temperatureC), 0) / tempData.length, data: tempData } : undefined,
            heartRate: heartData.length > 0 ? { current: heartData[0]?.heartRate, average: Math.round(heartData.reduce((a: number, b: any) => a + b.heartRate, 0) / heartData.length), data: heartData } : undefined,
          };
          setPetData(result.pet, currentToken, medicalRecords, petData.vaccinations || result.vaccinations || [], prescriptions, healthStats, []);
        }
      }
      setShowAddWeightModal(false);
      setNewWeight({ weightKg: '', date: new Date().toISOString().split('T')[0], context: '' });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout du poids");
    } finally {
      setAddingWeight(false);
    }
  };

  const handleAddHealthData = async () => {
    if (!currentToken) return;
    if (!newHealthData.temperatureC && !newHealthData.heartRate) {
      alert('Veuillez entrer au moins une donnée (température ou rythme cardiaque)');
      return;
    }
    const temp = newHealthData.temperatureC ? parseFloat(newHealthData.temperatureC) : undefined;
    const hr = newHealthData.heartRate ? parseInt(newHealthData.heartRate) : undefined;
    if (temp !== undefined && (temp < 30 || temp > 45)) {
      alert('Température invalide (30-45°C)');
      return;
    }
    if (hr !== undefined && (hr < 20 || hr > 300)) {
      alert('Rythme cardiaque invalide (20-300 bpm)');
      return;
    }
    setAddingHealthData(true);
    try {
      await api.createMedicalRecordByToken(currentToken, {
        title: 'Contrôle de santé',
        type: 'HEALTH_CHECK',
        description: newHealthData.notes || 'Données de santé enregistrées',
        temperatureC: temp,
        heartRate: hr,
        date: newHealthData.date,
      });
      // Refresh pet data
      if (scannedPet && currentToken) {
        const result = await api.getPetByToken(currentToken);
        if (result?.pet) {
          const petData = result.pet as any;
          const medicalRecords = petData.medicalRecords || result.medicalRecords || [];
          const treatments = petData.treatments || [];
          const prescriptions = treatments.map((t: any) => ({
            id: t.id, petId: t.petId, providerId: t.providerId || null, title: t.name,
            description: [t.dosage, t.frequency, t.notes].filter(Boolean).join(' - '),
            imageUrl: t.attachments?.[0] || null, attachments: t.attachments || [],
            date: t.startDate, isActive: t.isActive, endDate: t.endDate,
          }));
          const weightRecords = petData.weightRecords || [];
          const tempData = medicalRecords.filter((r: any) => r.temperatureC).map((r: any) => ({ temperatureC: r.temperatureC, date: r.date }));
          const heartData = medicalRecords.filter((r: any) => r.heartRate).map((r: any) => ({ heartRate: r.heartRate, date: r.date }));
          const healthStats: any = {
            petId: result.pet.id,
            weight: weightRecords.length > 0 ? { current: weightRecords[0]?.weightKg, data: weightRecords } : undefined,
            temperature: tempData.length > 0 ? { current: tempData[0]?.temperatureC, average: tempData.reduce((a: number, b: any) => a + parseFloat(b.temperatureC), 0) / tempData.length, data: tempData } : undefined,
            heartRate: heartData.length > 0 ? { current: heartData[0]?.heartRate, average: Math.round(heartData.reduce((a: number, b: any) => a + b.heartRate, 0) / heartData.length), data: heartData } : undefined,
          };
          setPetData(result.pet, currentToken, medicalRecords, petData.vaccinations || result.vaccinations || [], prescriptions, healthStats, []);
        }
      }
      setShowAddHealthDataModal(false);
      setNewHealthData({ temperatureC: '', heartRate: '', date: new Date().toISOString().split('T')[0], notes: '' });
    } catch (error) {
      console.error('Error:', error);
      alert("Erreur lors de l'ajout des données de santé");
    } finally {
      setAddingHealthData(false);
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
                    <span className="text-xs bg-orange-100 text-orange-700 px-2 py-1 rounded-full font-medium">{healthStats ? ((healthStats.weight?.data?.length || 0) + (healthStats.temperature?.data?.length || 0) + (healthStats.heartRate?.data?.length || 0)) : 0}</span>
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
                <div className="mt-6">
                  <Button onClick={() => setShowAddVaccinationModal(true)} className="w-full">
                    <Plus size={16} className="mr-2" />
                    Ajouter une vaccination
                  </Button>
                </div>
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
                      const pAny = p as any;
                      const attachments = pAny.attachments || (pAny.imageUrl ? [pAny.imageUrl] : []);
                      const isActive = pAny.isActive !== false;
                      return (
                        <div key={p.id} className={`p-4 bg-white rounded-xl border-2 ${isActive ? 'border-teal-200' : 'border-gray-200'} shadow-sm`}>
                          <div className="flex items-start gap-3">
                            <div className={`p-2.5 rounded-xl flex-shrink-0 ${isActive ? 'bg-teal-100' : 'bg-gray-100'}`}>
                              <Pill size={18} className={isActive ? 'text-teal-600' : 'text-gray-500'} />
                            </div>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center justify-between mb-1">
                                <div className="flex items-center gap-2">
                                  <p className="font-bold text-gray-900">{p.title}</p>
                                  {isActive && (
                                    <span className="text-[10px] bg-teal-100 text-teal-700 px-1.5 py-0.5 rounded font-semibold">En cours</span>
                                  )}
                                </div>
                                <div className="flex items-center gap-2">
                                  {canDelete && (
                                    <>
                                      <button onClick={() => handleEditPrescription(p)} className="p-1 text-blue-400 hover:text-blue-600 hover:bg-blue-50 rounded">
                                        <Edit2 size={14} />
                                      </button>
                                      <button onClick={() => handleDeletePrescription(p.id)} className="p-1 text-red-400 hover:text-red-600 hover:bg-red-50 rounded">
                                        <Trash2 size={14} />
                                      </button>
                                    </>
                                  )}
                                </div>
                              </div>
                              {p.description && <p className="text-sm text-gray-600 mb-2">{p.description}</p>}
                              <div className="flex items-center gap-3 text-xs text-gray-500">
                                <span className="flex items-center gap-1">
                                  <Calendar size={12} />
                                  {format(new Date(p.date), 'dd/MM/yyyy')}
                                </span>
                                {pAny.endDate && (
                                  <span className="flex items-center gap-1">
                                    → {format(new Date(pAny.endDate), 'dd/MM/yyyy')}
                                  </span>
                                )}
                              </div>
                              {/* Image Attachments Preview - click to open modal */}
                              {attachments.length > 0 && (
                                <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
                                  {attachments.filter((url: string) => url && typeof url === 'string').map((url: string, idx: number) => (
                                    <button
                                      key={idx}
                                      onClick={() => { setPreviewImageUrl(url); setShowImagePreviewModal(true); }}
                                      className="flex-shrink-0 group relative w-16 h-16 rounded-lg border border-gray-200 hover:border-purple-400 transition-colors bg-gradient-to-br from-purple-50 to-teal-50 overflow-hidden"
                                    >
                                      {/* Fallback - visible when image fails */}
                                      <div className="absolute inset-0 flex flex-col items-center justify-center text-purple-600 z-0">
                                        <FileText size={20} />
                                        <span className="text-[8px] font-medium mt-0.5">Voir</span>
                                      </div>
                                      {/* Image on top */}
                                      <img
                                        src={url}
                                        alt={`Ordonnance ${idx + 1}`}
                                        className="absolute inset-0 w-full h-full object-cover z-10"
                                        onError={(e) => {
                                          // Hide broken image to show fallback underneath
                                          (e.target as HTMLImageElement).style.display = 'none';
                                        }}
                                      />
                                      {/* Hover overlay */}
                                      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-colors flex items-center justify-center z-20">
                                        <Eye size={20} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-lg" />
                                      </div>
                                    </button>
                                  ))}
                                </div>
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
                {!healthStats || ((healthStats.weight?.data?.length || 0) === 0 && (healthStats.temperature?.data?.length || 0) === 0 && (healthStats.heartRate?.data?.length || 0) === 0) ? (
                  <div className="text-center py-12">
                    <TrendingUp className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucune mesure</p>
                    <p className="text-sm text-gray-400 mt-2">Les mesures sont enregistrées lors des visites vétérinaires</p>
                  </div>
                ) : (
                  <div className="space-y-6">
                    {/* Weight Section */}
                    {(healthStats.weight?.data?.length || 0) > 0 && (
                      <div className="bg-white border-2 border-coral-100 rounded-xl overflow-hidden">
                        <div className="bg-gradient-to-r from-coral-500 to-coral-400 px-4 py-3 flex items-center justify-between">
                          <div className="flex items-center gap-2 text-white">
                            <Scale size={20} />
                            <span className="font-bold">Poids</span>
                          </div>
                          <div className="text-white text-right">
                            <span className="text-2xl font-bold">{parseFloat(String(healthStats.weight?.current || 0)).toFixed(1)}</span>
                            <span className="text-sm ml-1 opacity-90">kg</span>
                          </div>
                        </div>
                        <div className="p-4 flex gap-4">
                          {/* Liste à gauche - newest first */}
                          <div className="w-1/3 space-y-2 max-h-48 overflow-y-auto pr-2 border-r border-gray-100">
                            {healthStats.weight!.data.slice(0, 10).map((w: any, i: number) => (
                              <div key={i} className={`p-2 rounded-lg ${i === 0 ? 'bg-coral-100 border-2 border-coral-300' : 'bg-gray-50'}`}>
                                <p className={`font-bold ${i === 0 ? 'text-coral-700' : 'text-gray-700'}`}>{parseFloat(String(w.weightKg || 0)).toFixed(1)} kg</p>
                                <p className="text-[10px] text-gray-500">{format(new Date(w.date), 'dd/MM/yy')}</p>
                              </div>
                            ))}
                          </div>
                          {/* Graphique à droite avec échelle - chronological (oldest to newest) */}
                          <div className="flex-1">
                            <svg viewBox="0 0 320 140" className="w-full h-48">
                              {(() => {
                                const data = healthStats.weight!.data.slice(0, 10).slice().reverse();
                                if (data.length < 1) return null;
                                const values = data.map((d: any) => parseFloat(String(d.weightKg || 0)));
                                const minVal = Math.floor(Math.min(...values) * 0.9);
                                const maxVal = Math.ceil(Math.max(...values) * 1.1);
                                const range = maxVal - minVal || 1;
                                const yLabels = [maxVal, Math.round((maxVal + minVal) / 2), minVal];
                                return (
                                  <>
                                    <defs>
                                      <linearGradient id="wGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                                        <stop offset="0%" stopColor="#F36C6C" stopOpacity="0.4" />
                                        <stop offset="100%" stopColor="#F36C6C" stopOpacity="0.05" />
                                      </linearGradient>
                                    </defs>
                                    {/* Grid lines */}
                                    {yLabels.map((label, i) => {
                                      const y = 20 + (i * 50);
                                      return (
                                        <g key={i}>
                                          <line x1="45" y1={y} x2="310" y2={y} stroke="#e5e7eb" strokeDasharray="4,4" />
                                          <text x="40" y={y + 4} textAnchor="end" fontSize="11" fill="#9ca3af">{label}</text>
                                        </g>
                                      );
                                    })}
                                    {/* Y axis label */}
                                    <text x="12" y="75" textAnchor="middle" fontSize="10" fill="#F36C6C" transform="rotate(-90, 12, 75)">kg</text>
                                    {/* Area + Line */}
                                    {data.length >= 2 && (() => {
                                      const pts = values.map((v: number, i: number) => {
                                        const x = 55 + (i / (values.length - 1)) * 245;
                                        const y = 120 - ((v - minVal) / range) * 100;
                                        return { x, y, v };
                                      });
                                      const linePts = pts.map(p => `${p.x},${p.y}`).join(' ');
                                      const areaPts = `55,120 ${linePts} ${pts[pts.length-1].x},120`;
                                      return (
                                        <>
                                          <polygon points={areaPts} fill="url(#wGrad)" />
                                          <polyline points={linePts} fill="none" stroke="#F36C6C" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                                          {pts.map((p, i) => (
                                            <g key={i}>
                                              <circle cx={p.x} cy={p.y} r="6" fill="#fff" stroke="#F36C6C" strokeWidth="3" />
                                              {i === pts.length - 1 && <text x={p.x} y={p.y - 12} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#F36C6C">{p.v.toFixed(1)}</text>}
                                            </g>
                                          ))}
                                        </>
                                      );
                                    })()}
                                    {data.length === 1 && (
                                      <circle cx="180" cy={120 - ((values[0] - minVal) / range) * 100} r="8" fill="#F36C6C" />
                                    )}
                                  </>
                                );
                              })()}
                            </svg>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Temperature Section */}
                    {(healthStats.temperature?.data?.length || 0) > 0 && (
                      <div className="bg-white border-2 border-teal-100 rounded-xl overflow-hidden">
                        <div className="bg-gradient-to-r from-teal-500 to-teal-400 px-4 py-3 flex items-center justify-between">
                          <div className="flex items-center gap-2 text-white">
                            <Thermometer size={20} />
                            <span className="font-bold">Température</span>
                          </div>
                          <div className="text-white text-right">
                            <span className="text-2xl font-bold">{parseFloat(String(healthStats.temperature?.current || 0)).toFixed(1)}</span>
                            <span className="text-sm ml-1 opacity-90">°C</span>
                          </div>
                        </div>
                        <div className="p-4 flex gap-4">
                          <div className="w-1/3 space-y-2 max-h-48 overflow-y-auto pr-2 border-r border-gray-100">
                            {healthStats.temperature!.data.slice(0, 10).map((t: any, i: number) => {
                              const temp = parseFloat(String(t.temperatureC || 0));
                              const isNormal = temp >= 38 && temp <= 39;
                              return (
                                <div key={i} className={`p-2 rounded-lg ${i === 0 ? 'bg-teal-100 border-2 border-teal-300' : 'bg-gray-50'}`}>
                                  <p className={`font-bold ${i === 0 ? 'text-teal-700' : 'text-gray-700'}`}>
                                    {temp.toFixed(1)}°C
                                    {!isNormal && <span className="text-[10px] ml-1 text-orange-500">⚠</span>}
                                  </p>
                                  <p className="text-[10px] text-gray-500">{format(new Date(t.date), 'dd/MM/yy')}</p>
                                </div>
                              );
                            })}
                          </div>
                          <div className="flex-1">
                            <svg viewBox="0 0 320 140" className="w-full h-48">
                              {(() => {
                                const data = healthStats.temperature!.data.slice(0, 10).slice().reverse();
                                if (data.length < 1) return null;
                                const values = data.map((d: any) => parseFloat(String(d.temperatureC || 0)));
                                const minVal = Math.floor(Math.min(...values, 37) - 0.5);
                                const maxVal = Math.ceil(Math.max(...values, 40) + 0.5);
                                const range = maxVal - minVal || 1;
                                const yLabels = [maxVal, (maxVal + minVal) / 2, minVal];
                                return (
                                  <>
                                    <defs>
                                      <linearGradient id="tGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                                        <stop offset="0%" stopColor="#4ECDC4" stopOpacity="0.4" />
                                        <stop offset="100%" stopColor="#4ECDC4" stopOpacity="0.05" />
                                      </linearGradient>
                                    </defs>
                                    {/* Normal range band (38-39°C) */}
                                    <rect x="45" y={120 - ((39 - minVal) / range) * 100} width="265" height={((39 - 38) / range) * 100} fill="#4ECDC4" fillOpacity="0.1" />
                                    {/* Grid lines */}
                                    {yLabels.map((label, i) => {
                                      const y = 20 + (i * 50);
                                      return (
                                        <g key={i}>
                                          <line x1="45" y1={y} x2="310" y2={y} stroke="#e5e7eb" strokeDasharray="4,4" />
                                          <text x="40" y={y + 4} textAnchor="end" fontSize="11" fill="#9ca3af">{label.toFixed(1)}</text>
                                        </g>
                                      );
                                    })}
                                    <text x="12" y="75" textAnchor="middle" fontSize="10" fill="#4ECDC4" transform="rotate(-90, 12, 75)">°C</text>
                                    {data.length >= 2 && (() => {
                                      const pts = values.map((v: number, i: number) => {
                                        const x = 55 + (i / (values.length - 1)) * 245;
                                        const y = 120 - ((v - minVal) / range) * 100;
                                        return { x, y, v };
                                      });
                                      const linePts = pts.map(p => `${p.x},${p.y}`).join(' ');
                                      const areaPts = `55,120 ${linePts} ${pts[pts.length-1].x},120`;
                                      return (
                                        <>
                                          <polygon points={areaPts} fill="url(#tGrad)" />
                                          <polyline points={linePts} fill="none" stroke="#4ECDC4" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                                          {pts.map((p, i) => (
                                            <g key={i}>
                                              <circle cx={p.x} cy={p.y} r="6" fill="#fff" stroke="#4ECDC4" strokeWidth="3" />
                                              {i === pts.length - 1 && <text x={p.x} y={p.y - 12} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#4ECDC4">{p.v.toFixed(1)}</text>}
                                            </g>
                                          ))}
                                        </>
                                      );
                                    })()}
                                    {data.length === 1 && (
                                      <circle cx="180" cy={120 - ((values[0] - minVal) / range) * 100} r="8" fill="#4ECDC4" />
                                    )}
                                  </>
                                );
                              })()}
                            </svg>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Heart Rate Section */}
                    {(healthStats.heartRate?.data?.length || 0) > 0 && (
                      <div className="bg-white border-2 border-purple-100 rounded-xl overflow-hidden">
                        <div className="bg-gradient-to-r from-purple-500 to-purple-400 px-4 py-3 flex items-center justify-between">
                          <div className="flex items-center gap-2 text-white">
                            <Heart size={20} />
                            <span className="font-bold">Rythme cardiaque</span>
                          </div>
                          <div className="text-white text-right">
                            <span className="text-2xl font-bold">{healthStats.heartRate?.current || 0}</span>
                            <span className="text-sm ml-1 opacity-90">BPM</span>
                          </div>
                        </div>
                        <div className="p-4 flex gap-4">
                          <div className="w-1/3 space-y-2 max-h-48 overflow-y-auto pr-2 border-r border-gray-100">
                            {healthStats.heartRate!.data.slice(0, 10).map((h: any, i: number) => {
                              const hr = h.heartRate || 0;
                              const isNormal = hr >= 60 && hr <= 140;
                              return (
                                <div key={i} className={`p-2 rounded-lg ${i === 0 ? 'bg-purple-100 border-2 border-purple-300' : 'bg-gray-50'}`}>
                                  <p className={`font-bold ${i === 0 ? 'text-purple-700' : 'text-gray-700'}`}>
                                    {hr} BPM
                                    {!isNormal && <span className="text-[10px] ml-1 text-orange-500">⚠</span>}
                                  </p>
                                  <p className="text-[10px] text-gray-500">{format(new Date(h.date), 'dd/MM/yy')}</p>
                                </div>
                              );
                            })}
                          </div>
                          <div className="flex-1">
                            <svg viewBox="0 0 320 140" className="w-full h-48">
                              {(() => {
                                const data = healthStats.heartRate!.data.slice(0, 10).slice().reverse();
                                if (data.length < 1) return null;
                                const values = data.map((d: any) => d.heartRate || 0);
                                const minVal = Math.floor(Math.min(...values, 60) * 0.85);
                                const maxVal = Math.ceil(Math.max(...values, 140) * 1.15);
                                const range = maxVal - minVal || 1;
                                const yLabels = [maxVal, Math.round((maxVal + minVal) / 2), minVal];
                                return (
                                  <>
                                    <defs>
                                      <linearGradient id="hGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                                        <stop offset="0%" stopColor="#9B59B6" stopOpacity="0.4" />
                                        <stop offset="100%" stopColor="#9B59B6" stopOpacity="0.05" />
                                      </linearGradient>
                                    </defs>
                                    {/* Normal range band (60-140 BPM) */}
                                    <rect x="45" y={120 - ((140 - minVal) / range) * 100} width="265" height={((140 - 60) / range) * 100} fill="#9B59B6" fillOpacity="0.1" />
                                    {yLabels.map((label, i) => {
                                      const y = 20 + (i * 50);
                                      return (
                                        <g key={i}>
                                          <line x1="45" y1={y} x2="310" y2={y} stroke="#e5e7eb" strokeDasharray="4,4" />
                                          <text x="40" y={y + 4} textAnchor="end" fontSize="11" fill="#9ca3af">{label}</text>
                                        </g>
                                      );
                                    })}
                                    <text x="12" y="75" textAnchor="middle" fontSize="10" fill="#9B59B6" transform="rotate(-90, 12, 75)">BPM</text>
                                    {data.length >= 2 && (() => {
                                      const pts = values.map((v: number, i: number) => {
                                        const x = 55 + (i / (values.length - 1)) * 245;
                                        const y = 120 - ((v - minVal) / range) * 100;
                                        return { x, y, v };
                                      });
                                      const linePts = pts.map(p => `${p.x},${p.y}`).join(' ');
                                      const areaPts = `55,120 ${linePts} ${pts[pts.length-1].x},120`;
                                      return (
                                        <>
                                          <polygon points={areaPts} fill="url(#hGrad)" />
                                          <polyline points={linePts} fill="none" stroke="#9B59B6" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                                          {pts.map((p, i) => (
                                            <g key={i}>
                                              <circle cx={p.x} cy={p.y} r="6" fill="#fff" stroke="#9B59B6" strokeWidth="3" />
                                              {i === pts.length - 1 && <text x={p.x} y={p.y - 12} textAnchor="middle" fontSize="11" fontWeight="bold" fill="#9B59B6">{p.v}</text>}
                                            </g>
                                          ))}
                                        </>
                                      );
                                    })()}
                                    {data.length === 1 && (
                                      <circle cx="180" cy={120 - ((values[0] - minVal) / range) * 100} r="8" fill="#9B59B6" />
                                    )}
                                  </>
                                );
                              })()}
                            </svg>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )}
                <div className="mt-6 space-y-3">
                  <Button onClick={() => setShowAddWeightModal(true)} className="w-full">
                    <Scale size={16} className="mr-2" />
                    Ajouter un poids
                  </Button>
                  <Button onClick={() => setShowAddHealthDataModal(true)} variant="secondary" className="w-full">
                    <Activity size={16} className="mr-2" />
                    Ajouter température / BPM
                  </Button>
                </div>
              </>
            ) : viewMode === 'diseases' ? (
              <>
                <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <AlertTriangle className="text-orange-600" size={24} />
                  Suivi de maladies
                </h3>
                {diseases.length === 0 ? (
                  <div className="text-center py-12">
                    <AlertTriangle className="mx-auto text-gray-300 mb-4" size={48} />
                    <p className="text-gray-500">Aucune maladie suivie</p>
                    <p className="text-sm text-gray-400 mt-2">Les suivis de maladies apparaîtront ici</p>
                  </div>
                ) : (
                  <div className="space-y-6">
                    {(() => {
                      const ongoing = diseases.filter((d: any) => d.status === 'ONGOING');
                      const chronic = diseases.filter((d: any) => d.status === 'CHRONIC');
                      const monitoring = diseases.filter((d: any) => d.status === 'MONITORING');
                      const cured = diseases.filter((d: any) => d.status === 'CURED');

                      const renderDiseaseCard = (d: any) => {
                        const canDelete = isOwnRecord(d.providerId);
                        const progressCount = d.progressEntries?.length || 0;
                        const statusCfg: Record<string, { bg: string; text: string; border: string; iconBg: string }> = {
                          ONGOING: { bg: 'bg-red-50', text: 'text-red-600', border: 'border-red-200', iconBg: 'bg-red-100' },
                          CHRONIC: { bg: 'bg-orange-50', text: 'text-orange-600', border: 'border-orange-200', iconBg: 'bg-orange-100' },
                          MONITORING: { bg: 'bg-purple-50', text: 'text-purple-600', border: 'border-purple-200', iconBg: 'bg-purple-100' },
                          CURED: { bg: 'bg-teal-50', text: 'text-teal-600', border: 'border-teal-200', iconBg: 'bg-teal-100' },
                        };
                        const sevCfg: Record<string, { bg: string; text: string }> = {
                          MILD: { bg: 'bg-teal-100', text: 'text-teal-700' },
                          MODERATE: { bg: 'bg-orange-100', text: 'text-orange-700' },
                          SEVERE: { bg: 'bg-red-100', text: 'text-red-700' },
                        };
                        const cfg = statusCfg[d.status] || statusCfg.ONGOING;
                        const sev = d.severity ? sevCfg[d.severity] : null;

                        return (
                          <div key={d.id} onClick={() => handleViewDiseaseDetail(d)} className={`p-4 bg-white rounded-xl border-2 ${cfg.border} shadow-sm cursor-pointer hover:shadow-md transition-shadow`}>
                            <div className="flex items-start gap-3">
                              <div className={`p-2.5 ${cfg.iconBg} rounded-xl flex-shrink-0`}>
                                <AlertTriangle size={18} className={cfg.text} />
                              </div>
                              <div className="flex-1 min-w-0">
                                <div className="flex items-center justify-between mb-1">
                                  <div className="flex items-center gap-2 flex-wrap">
                                    <p className="font-bold text-gray-900">{d.name}</p>
                                    <span className={`text-[10px] ${cfg.bg} ${cfg.text} px-1.5 py-0.5 rounded font-semibold`}>
                                      {d.status === 'ONGOING' ? 'En cours' : d.status === 'CHRONIC' ? 'Chronique' : d.status === 'MONITORING' ? 'Surveillance' : 'Guérie'}
                                    </span>
                                    {sev && <span className={`text-[10px] ${sev.bg} ${sev.text} px-1.5 py-0.5 rounded font-semibold`}>{d.severity === 'MILD' ? 'Légère' : d.severity === 'MODERATE' ? 'Modérée' : 'Sévère'}</span>}
                                  </div>
                                  {canDelete && (
                                    <div className="flex items-center gap-1" onClick={(e) => e.stopPropagation()}>
                                      <button onClick={() => handleEditDisease(d)} className="p-1 text-blue-400 hover:text-blue-600 hover:bg-blue-50 rounded"><Edit2 size={14} /></button>
                                      <button onClick={() => handleDeleteDisease(d.id)} className="p-1 text-red-400 hover:text-red-600 hover:bg-red-50 rounded"><Trash2 size={14} /></button>
                                    </div>
                                  )}
                                </div>
                                {d.description && <p className="text-sm text-gray-600 mb-2 line-clamp-2">{d.description}</p>}
                                <div className="flex items-center gap-3 text-xs text-gray-500">
                                  <span className="flex items-center gap-1"><Calendar size={12} />{format(new Date(d.diagnosisDate || d.diagnosedDate), 'dd/MM/yyyy')}</span>
                                  {d.curedDate && <span className="flex items-center gap-1 text-teal-600"><CheckCircle size={12} />Guéri: {format(new Date(d.curedDate), 'dd/MM/yyyy')}</span>}
                                  {progressCount > 0 && <span className={`flex items-center gap-1 ${cfg.text} font-medium`}><Clock size={12} />{progressCount} mise{progressCount > 1 ? 's' : ''} à jour</span>}
                                </div>
                              </div>
                              <ChevronRight size={20} className="text-gray-400 flex-shrink-0" />
                            </div>
                          </div>
                        );
                      };

                      const renderSection = (title: string, items: any[], dotColor: string) => items.length === 0 ? null : (
                        <div key={title}>
                          <div className="flex items-center gap-2 mb-3">
                            <span className={`w-2 h-2 rounded-full ${dotColor}`} />
                            <span className="text-sm font-bold text-gray-700">{title}</span>
                            <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full font-medium">{items.length}</span>
                          </div>
                          <div className="space-y-3">{items.map(renderDiseaseCard)}</div>
                        </div>
                      );

                      return (
                        <>
                          {renderSection('En cours', ongoing, 'bg-red-500')}
                          {renderSection('Chronique', chronic, 'bg-orange-500')}
                          {renderSection('Sous surveillance', monitoring, 'bg-purple-500')}
                          {renderSection('Guéries', cured, 'bg-teal-500')}
                        </>
                      );
                    })()}
                  </div>
                )}
                <div className="mt-6">
                  <Button onClick={() => setShowAddDiseaseModal(true)} className="w-full bg-orange-500 hover:bg-orange-600">
                    <Plus size={16} className="mr-2" />
                    Ajouter un suivi de maladie
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

      {/* Add Prescription/Treatment Modal */}
      {showAddPrescriptionModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={() => setShowAddPrescriptionModal(false)}>
          <Card className="w-full max-w-md max-h-[90vh] overflow-y-auto" onClick={(e: React.MouseEvent) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Pill className="text-purple-600" size={20} />
              Ajouter une ordonnance
            </h2>
            <div className="space-y-4">
              <Input label="Médicament *" placeholder="Ex: Amoxicilline" value={newPrescription.name} onChange={(e) => setNewPrescription({ ...newPrescription, name: e.target.value })} />
              <Input label="Posologie" placeholder="Ex: 1 comprimé 2x/jour" value={newPrescription.dosage} onChange={(e) => setNewPrescription({ ...newPrescription, dosage: e.target.value })} />
              <Input label="Fréquence" placeholder="Ex: Matin et soir" value={newPrescription.frequency} onChange={(e) => setNewPrescription({ ...newPrescription, frequency: e.target.value })} />
              <div className="grid grid-cols-2 gap-3">
                <Input type="date" label="Date de début" value={newPrescription.startDate} onChange={(e) => setNewPrescription({ ...newPrescription, startDate: e.target.value })} />
                <Input type="date" label="Date de fin (opt.)" value={newPrescription.endDate} onChange={(e) => setNewPrescription({ ...newPrescription, endDate: e.target.value })} />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
                <textarea rows={2} placeholder="Informations complémentaires..." value={newPrescription.notes} onChange={(e) => setNewPrescription({ ...newPrescription, notes: e.target.value })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              </div>
              {/* Image Upload Section */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Photo de l'ordonnance</label>
                {newPrescription.attachments.length > 0 ? (
                  <div className="flex gap-2 overflow-x-auto pb-2">
                    {newPrescription.attachments.map((url, idx) => (
                      <div key={idx} className="relative flex-shrink-0">
                        <img src={url} alt={`Ordonnance ${idx + 1}`} className="w-20 h-20 object-cover rounded-lg border border-gray-200" />
                        <button
                          onClick={() => removePrescriptionImage(idx)}
                          className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 shadow-md hover:bg-red-600"
                        >
                          <X size={12} />
                        </button>
                      </div>
                    ))}
                    <label className="w-20 h-20 flex-shrink-0 flex items-center justify-center border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-purple-400 hover:bg-purple-50 transition-colors">
                      <input type="file" accept="image/*" onChange={handlePrescriptionImageUpload} className="hidden" />
                      {uploadingImage ? (
                        <div className="animate-spin rounded-full h-5 w-5 border-2 border-purple-600 border-t-transparent" />
                      ) : (
                        <Plus className="text-gray-400" size={24} />
                      )}
                    </label>
                  </div>
                ) : (
                  <label className="flex items-center justify-center w-full h-24 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-purple-400 hover:bg-purple-50 transition-colors">
                    <input type="file" accept="image/*" onChange={handlePrescriptionImageUpload} className="hidden" />
                    {uploadingImage ? (
                      <div className="animate-spin rounded-full h-6 w-6 border-2 border-purple-600 border-t-transparent" />
                    ) : (
                      <div className="text-center">
                        <Upload className="mx-auto text-gray-400 mb-2" size={24} />
                        <span className="text-sm text-gray-500">Ajouter une photo</span>
                      </div>
                    )}
                  </label>
                )}
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddPrescriptionModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddPrescription} isLoading={addingPrescription} disabled={!newPrescription.name}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Disease Modal - Temporarily disabled due to backend schema mismatch */}
      {showAddDiseaseModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <AlertTriangle className="text-orange-600" size={20} />
              Nouveau suivi de maladie
            </h2>
            <div className="space-y-4">
              <Input label="Nom de la maladie *" placeholder="Ex: Otite, Allergie cutanée..." value={newDisease.name} onChange={(e) => setNewDisease({ ...newDisease, name: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea rows={2} placeholder="Description de la maladie..." value={newDisease.description} onChange={(e) => setNewDisease({ ...newDisease, description: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Statut</label>
                  <select value={newDisease.status} onChange={(e) => setNewDisease({ ...newDisease, status: e.target.value })} className="w-full px-3 py-2 border rounded-lg">
                    <option value="ONGOING">En cours</option>
                    <option value="CHRONIC">Chronique</option>
                    <option value="MONITORING">Surveillance</option>
                    <option value="CURED">Guérie</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Sévérité</label>
                  <select value={newDisease.severity} onChange={(e) => setNewDisease({ ...newDisease, severity: e.target.value })} className="w-full px-3 py-2 border rounded-lg">
                    <option value="">Non spécifiée</option>
                    <option value="MILD">Légère</option>
                    <option value="MODERATE">Modérée</option>
                    <option value="SEVERE">Sévère</option>
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Symptômes</label>
                <textarea rows={2} placeholder="Symptômes observés..." value={newDisease.symptoms} onChange={(e) => setNewDisease({ ...newDisease, symptoms: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Traitement</label>
                <textarea rows={2} placeholder="Traitement prescrit..." value={newDisease.treatment} onChange={(e) => setNewDisease({ ...newDisease, treatment: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
                <textarea rows={2} placeholder="Notes additionnelles..." value={newDisease.notes} onChange={(e) => setNewDisease({ ...newDisease, notes: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              {/* Image upload section */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Photos</label>
                <div className="flex flex-wrap gap-2 mb-2">
                  {newDisease.images.map((url, idx) => (
                    <div key={idx} className="relative w-16 h-16 group rounded-lg border overflow-hidden bg-gray-100">
                      <img
                        src={url}
                        alt={`Photo ${idx + 1}`}
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          console.error('Image load error for URL:', url);
                          (e.target as HTMLImageElement).style.display = 'none';
                          const parent = (e.target as HTMLImageElement).parentElement;
                          if (parent && !parent.querySelector('.img-error-fallback')) {
                            const fallback = document.createElement('div');
                            fallback.className = 'img-error-fallback absolute inset-0 flex flex-col items-center justify-center bg-red-50 text-red-500';
                            fallback.innerHTML = '<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg><span class="text-[8px] mt-0.5">Erreur</span>';
                            parent.appendChild(fallback);
                          }
                        }}
                      />
                      <button
                        onClick={() => removeDiseaseImage(idx)}
                        className="absolute -top-1 -right-1 bg-red-500 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity z-10"
                      >
                        <X size={12} />
                      </button>
                    </div>
                  ))}
                  <label className="w-16 h-16 border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center cursor-pointer hover:border-orange-400 hover:bg-orange-50 transition-colors">
                    {uploadingDiseaseImage ? (
                      <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-orange-500" />
                    ) : (
                      <>
                        <Upload size={18} className="text-gray-400" />
                        <span className="text-[9px] text-gray-400 mt-0.5">Ajouter</span>
                      </>
                    )}
                    <input type="file" accept="image/*" onChange={handleDiseaseImageUpload} className="hidden" disabled={uploadingDiseaseImage} />
                  </label>
                </div>
                <p className="text-xs text-gray-500">Photos de la lésion, symptômes visibles, etc.</p>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => { setShowAddDiseaseModal(false); setNewDisease({ ...newDisease, images: [] }); }}>Annuler</Button>
              <Button className="flex-1 bg-orange-500 hover:bg-orange-600" onClick={handleAddDisease} isLoading={addingDisease} disabled={!newDisease.name || uploadingDiseaseImage}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Disease Detail Modal */}
      {showDiseaseDetailModal && selectedDisease && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            {(() => {
              const d = selectedDisease as any;
              const statusCfg: Record<string, { bg: string; text: string; gradient: string }> = {
                ONGOING: { bg: 'bg-red-500', text: 'text-red-600', gradient: 'from-red-500 to-red-400' },
                CHRONIC: { bg: 'bg-orange-500', text: 'text-orange-600', gradient: 'from-orange-500 to-orange-400' },
                MONITORING: { bg: 'bg-purple-500', text: 'text-purple-600', gradient: 'from-purple-500 to-purple-400' },
                CURED: { bg: 'bg-teal-500', text: 'text-teal-600', gradient: 'from-teal-500 to-teal-400' },
              };
              const sevCfg: Record<string, { bg: string; text: string }> = {
                MILD: { bg: 'bg-teal-500', text: 'Légère' },
                MODERATE: { bg: 'bg-orange-500', text: 'Modérée' },
                SEVERE: { bg: 'bg-red-500', text: 'Sévère' },
              };
              const cfg = statusCfg[d.status] || statusCfg.ONGOING;
              const progressEntries = d.progressEntries || [];

              return (
                <>
                  {/* Header */}
                  <div className={`-mx-6 -mt-6 mb-6 p-6 bg-gradient-to-r ${cfg.gradient} text-white rounded-t-xl`}>
                    <div className="flex items-center justify-between">
                      <div>
                        <h2 className="text-xl font-bold">{d.name}</h2>
                        <div className="flex items-center gap-2 mt-2">
                          <span className="text-xs bg-white/20 px-2 py-1 rounded font-medium">
                            {d.status === 'ONGOING' ? 'En cours' : d.status === 'CHRONIC' ? 'Chronique' : d.status === 'MONITORING' ? 'Surveillance' : 'Guérie'}
                          </span>
                          {d.severity && sevCfg[d.severity] && (
                            <span className="text-xs bg-white/20 px-2 py-1 rounded font-medium">{sevCfg[d.severity].text}</span>
                          )}
                        </div>
                      </div>
                      <button onClick={() => setShowDiseaseDetailModal(false)} className="p-2 hover:bg-white/20 rounded-lg"><X size={20} /></button>
                    </div>
                  </div>

                  {/* Description */}
                  {d.description && <p className="text-gray-700 mb-4">{d.description}</p>}

                  {/* Info Cards */}
                  <div className="grid grid-cols-2 gap-3 mb-6">
                    <div className="p-3 bg-gray-50 rounded-lg">
                      <p className="text-xs text-gray-500 mb-1">Date de diagnostic</p>
                      <p className="font-medium">{format(new Date(d.diagnosisDate || d.diagnosedDate), 'dd/MM/yyyy')}</p>
                    </div>
                    {d.curedDate && (
                      <div className="p-3 bg-teal-50 rounded-lg">
                        <p className="text-xs text-teal-600 mb-1">Date de guérison</p>
                        <p className="font-medium text-teal-700">{format(new Date(d.curedDate), 'dd/MM/yyyy')}</p>
                      </div>
                    )}
                    {d.vetName && (
                      <div className="p-3 bg-gray-50 rounded-lg">
                        <p className="text-xs text-gray-500 mb-1">Vétérinaire</p>
                        <p className="font-medium">{d.vetName}</p>
                      </div>
                    )}
                  </div>

                  {/* Symptoms */}
                  {d.symptoms && (
                    <div className="mb-4">
                      <h4 className="font-semibold text-gray-800 mb-2 flex items-center gap-2"><Activity size={16} />Symptômes</h4>
                      <p className="text-gray-600 bg-gray-50 p-3 rounded-lg">{d.symptoms}</p>
                    </div>
                  )}

                  {/* Treatment */}
                  {d.treatment && (
                    <div className="mb-4">
                      <h4 className="font-semibold text-gray-800 mb-2 flex items-center gap-2"><Pill size={16} />Traitement</h4>
                      <p className="text-gray-600 bg-teal-50 p-3 rounded-lg">{d.treatment}</p>
                    </div>
                  )}

                  {/* Notes */}
                  {d.notes && (
                    <div className="mb-4">
                      <h4 className="font-semibold text-gray-800 mb-2 flex items-center gap-2"><FileText size={16} />Notes</h4>
                      <p className="text-gray-600 bg-gray-50 p-3 rounded-lg">{d.notes}</p>
                    </div>
                  )}

                  {/* Disease Images */}
                  {d.images && d.images.length > 0 && (
                    <div className="mb-4">
                      <h4 className="font-semibold text-gray-800 mb-2 flex items-center gap-2"><Image size={16} />Photos ({d.images.length})</h4>
                      <div className="flex flex-wrap gap-2">
                        {d.images.map((url: string, idx: number) => (
                          <button
                            key={idx}
                            onClick={() => { setPreviewImageUrl(url); setShowImagePreviewModal(true); }}
                            className="relative w-20 h-20 rounded-lg overflow-hidden border-2 border-gray-200 hover:border-orange-400 transition-colors group"
                          >
                            <img src={url} alt={`Photo ${idx + 1}`} className="w-full h-full object-cover" />
                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-colors flex items-center justify-center">
                              <Eye size={20} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-lg" />
                            </div>
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Timeline */}
                  {progressEntries.length > 0 && (
                    <div className="mb-4">
                      <h4 className="font-semibold text-gray-800 mb-4 flex items-center gap-2"><Clock size={16} />Évolution ({progressEntries.length})</h4>
                      <div className="space-y-4">
                        {progressEntries.map((entry: any, idx: number) => (
                          <div key={entry.id || idx} className="flex gap-3">
                            <div className="flex flex-col items-center">
                              <div className={`w-3 h-3 rounded-full ${cfg.bg}`} />
                              {idx < progressEntries.length - 1 && <div className={`w-0.5 flex-1 ${cfg.bg} opacity-30 mt-1`} />}
                            </div>
                            <div className="flex-1 pb-4">
                              <div className="bg-white border rounded-lg p-3 shadow-sm">
                                <div className="flex items-center gap-2 text-xs text-gray-500 mb-2">
                                  <Calendar size={12} />
                                  {format(new Date(entry.date), 'dd/MM/yyyy HH:mm')}
                                  {entry.severity && (
                                    <span className={`${sevCfg[entry.severity]?.bg || 'bg-gray-500'} text-white px-1.5 py-0.5 rounded text-[10px]`}>
                                      {sevCfg[entry.severity]?.text || entry.severity}
                                    </span>
                                  )}
                                </div>
                                <p className="text-gray-700">{entry.notes}</p>
                                {entry.treatmentUpdate && (
                                  <div className="mt-2 p-2 bg-teal-50 rounded flex items-start gap-2">
                                    <Pill size={14} className="text-teal-600 mt-0.5" />
                                    <p className="text-sm text-teal-700">{entry.treatmentUpdate}</p>
                                  </div>
                                )}
                                {/* Progress entry images */}
                                {entry.images && entry.images.length > 0 && (
                                  <div className="mt-2 flex flex-wrap gap-1.5">
                                    {entry.images.map((url: string, imgIdx: number) => (
                                      <button
                                        key={imgIdx}
                                        onClick={() => { setPreviewImageUrl(url); setShowImagePreviewModal(true); }}
                                        className="relative w-14 h-14 rounded-lg overflow-hidden border border-gray-200 hover:border-orange-400 transition-colors group"
                                      >
                                        <img src={url} alt={`Photo ${imgIdx + 1}`} className="w-full h-full object-cover" />
                                        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-colors flex items-center justify-center">
                                          <Eye size={14} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-lg" />
                                        </div>
                                      </button>
                                    ))}
                                  </div>
                                )}
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Actions */}
                  <div className="flex gap-3 mt-6 pt-4 border-t">
                    <Button variant="secondary" className="flex-1" onClick={() => setShowDiseaseDetailModal(false)}>Fermer</Button>
                    {d.status !== 'CURED' && (
                      <Button className="flex-1 bg-orange-500 hover:bg-orange-600" onClick={() => setShowAddProgressModal(true)}>
                        <Plus size={16} className="mr-2" />
                        Ajouter une mise à jour
                      </Button>
                    )}
                  </div>
                </>
              );
            })()}
          </Card>
        </div>
      )}

      {/* Add Progress Entry Modal */}
      {showAddProgressModal && selectedDisease && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Clock className="text-orange-600" size={20} />
              Ajouter une mise à jour
            </h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes d'évolution *</label>
                <textarea rows={3} placeholder="Évolution observée..." value={newProgress.notes} onChange={(e) => setNewProgress({ ...newProgress, notes: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Sévérité actuelle</label>
                <select value={newProgress.severity} onChange={(e) => setNewProgress({ ...newProgress, severity: e.target.value })} className="w-full px-3 py-2 border rounded-lg">
                  <option value="">Pas de changement</option>
                  <option value="MILD">Légère</option>
                  <option value="MODERATE">Modérée</option>
                  <option value="SEVERE">Sévère</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Mise à jour traitement</label>
                <textarea rows={2} placeholder="Changement de dosage, nouveau médicament..." value={newProgress.treatmentUpdate} onChange={(e) => setNewProgress({ ...newProgress, treatmentUpdate: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              {/* Image upload section */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Photos d'évolution</label>
                <div className="flex flex-wrap gap-2 mb-2">
                  {newProgress.images.map((url, idx) => (
                    <div key={idx} className="relative w-16 h-16 group">
                      <img src={url} alt={`Photo ${idx + 1}`} className="w-full h-full object-cover rounded-lg border" />
                      <button
                        onClick={() => removeProgressImage(idx)}
                        className="absolute -top-1 -right-1 bg-red-500 text-white rounded-full p-0.5 opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X size={12} />
                      </button>
                    </div>
                  ))}
                  <label className="w-16 h-16 border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center cursor-pointer hover:border-orange-400 hover:bg-orange-50 transition-colors">
                    {uploadingDiseaseImage ? (
                      <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-orange-500" />
                    ) : (
                      <>
                        <Upload size={18} className="text-gray-400" />
                        <span className="text-[9px] text-gray-400 mt-0.5">Ajouter</span>
                      </>
                    )}
                    <input type="file" accept="image/*" onChange={handleProgressImageUpload} className="hidden" disabled={uploadingDiseaseImage} />
                  </label>
                </div>
                <p className="text-xs text-gray-500">Documentez l'évolution avec des photos</p>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => { setShowAddProgressModal(false); setNewProgress({ notes: '', severity: '', treatmentUpdate: '', images: [] }); }}>Annuler</Button>
              <Button className="flex-1 bg-orange-500 hover:bg-orange-600" onClick={handleAddProgress} isLoading={addingProgress} disabled={!newProgress.notes || uploadingDiseaseImage}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Vaccination Modal */}
      {showAddVaccinationModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Syringe className="text-green-600" size={20} />
              Ajouter une vaccination
            </h2>
            <div className="space-y-4">
              <Input label="Nom du vaccin *" placeholder="Ex: Rage, Typhus, Coryza..." value={newVaccination.name} onChange={(e) => setNewVaccination({ ...newVaccination, name: e.target.value })} />
              <Input type="date" label="Date d'administration" value={newVaccination.date} onChange={(e) => setNewVaccination({ ...newVaccination, date: e.target.value })} />
              <Input type="date" label="Date de rappel (optionnel)" value={newVaccination.nextDueDate} onChange={(e) => setNewVaccination({ ...newVaccination, nextDueDate: e.target.value })} />
              <Input label="Numéro de lot (optionnel)" placeholder="Ex: LOT12345" value={newVaccination.batchNumber} onChange={(e) => setNewVaccination({ ...newVaccination, batchNumber: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes (optionnel)</label>
                <textarea rows={2} placeholder="Observations, réactions..." value={newVaccination.notes} onChange={(e) => setNewVaccination({ ...newVaccination, notes: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddVaccinationModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddVaccination} isLoading={addingVaccination} disabled={!newVaccination.name}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Weight Modal */}
      {showAddWeightModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Scale className="text-primary-600" size={20} />
              Ajouter un poids
            </h2>
            <div className="space-y-4">
              <Input type="number" step="0.1" min="0" label="Poids (kg) *" placeholder="Ex: 5.2" value={newWeight.weightKg} onChange={(e) => setNewWeight({ ...newWeight, weightKg: e.target.value })} />
              <Input type="date" label="Date" value={newWeight.date} onChange={(e) => setNewWeight({ ...newWeight, date: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes (optionnel)</label>
                <textarea rows={2} placeholder="Ex: Consultation de routine, post-opération..." value={newWeight.context} onChange={(e) => setNewWeight({ ...newWeight, context: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddWeightModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddWeight} isLoading={addingWeight} disabled={!newWeight.weightKg}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Add Health Data Modal */}
      {showAddHealthDataModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Activity className="text-red-600" size={20} />
              Ajouter des données de santé
            </h2>
            <p className="text-sm text-gray-500 mb-4">Ajoutez au moins une donnée (température ou rythme cardiaque)</p>
            <div className="space-y-4">
              <div>
                <Input type="number" step="0.1" min="30" max="45" label="Température (°C)" placeholder="Ex: 38.5" value={newHealthData.temperatureC} onChange={(e) => setNewHealthData({ ...newHealthData, temperatureC: e.target.value })} />
                <p className="text-xs text-gray-400 mt-1">Normal: 38-39°C</p>
              </div>
              <div>
                <Input type="number" min="20" max="300" label="Rythme cardiaque (bpm)" placeholder="Ex: 80" value={newHealthData.heartRate} onChange={(e) => setNewHealthData({ ...newHealthData, heartRate: e.target.value })} />
                <p className="text-xs text-gray-400 mt-1">Normal: 60-140 bpm</p>
              </div>
              <Input type="date" label="Date" value={newHealthData.date} onChange={(e) => setNewHealthData({ ...newHealthData, date: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Notes (optionnel)</label>
                <textarea rows={2} placeholder="Observations..." value={newHealthData.notes} onChange={(e) => setNewHealthData({ ...newHealthData, notes: e.target.value })} className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button variant="secondary" className="flex-1" onClick={() => setShowAddHealthDataModal(false)}>Annuler</Button>
              <Button className="flex-1" onClick={handleAddHealthData} isLoading={addingHealthData} disabled={!newHealthData.temperatureC && !newHealthData.heartRate}>Ajouter</Button>
            </div>
          </Card>
        </div>
      )}

      {/* Edit Prescription Modal */}
      {showEditPrescriptionModal && editingPrescription && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
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
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
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

      {/* Image Preview Modal */}
      {showImagePreviewModal && previewImageUrl && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowImagePreviewModal(false)}>
          <div className="relative max-w-4xl max-h-[90vh] w-full flex flex-col items-center justify-center" onClick={(e) => e.stopPropagation()}>
            <button
              onClick={() => setShowImagePreviewModal(false)}
              className="absolute -top-12 right-0 p-2 text-white hover:bg-white/20 rounded-lg transition-colors z-10"
            >
              <X size={24} />
            </button>
            {/* Use iframe as fallback for CORS/mixed content issues */}
            <div className="relative w-full h-[70vh] bg-black rounded-lg overflow-hidden flex items-center justify-center">
              <img
                src={previewImageUrl}
                alt="Aperçu"
                className="max-w-full max-h-full object-contain"
                onError={(e) => {
                  // Hide img and show fallback message
                  (e.target as HTMLImageElement).style.display = 'none';
                  const fallback = document.getElementById('img-preview-fallback');
                  if (fallback) fallback.style.display = 'flex';
                }}
                onLoad={(e) => {
                  // Show image when loaded
                  (e.target as HTMLImageElement).style.display = 'block';
                }}
              />
              <div id="img-preview-fallback" className="hidden flex-col items-center justify-center text-white gap-4">
                <Image size={48} className="text-gray-400" />
                <p className="text-gray-300">Impossible d'afficher l'image ici</p>
                <a
                  href={previewImageUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="bg-orange-500 hover:bg-orange-600 text-white px-6 py-3 rounded-lg font-medium flex items-center gap-2"
                >
                  <Eye size={18} />
                  Ouvrir l'image
                </a>
              </div>
            </div>
            <div className="mt-4 flex gap-3">
              <a
                href={previewImageUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="bg-white/90 hover:bg-white text-gray-800 px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2 shadow-lg"
              >
                <Eye size={16} />
                Ouvrir dans un nouvel onglet
              </a>
              <button
                onClick={() => setShowImagePreviewModal(false)}
                className="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-lg text-sm font-medium"
              >
                Fermer
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reference Code Modal */}
      {showReferenceCodeModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
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
