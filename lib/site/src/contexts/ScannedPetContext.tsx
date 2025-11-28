import { createContext, useContext, useState, useCallback, ReactNode, useEffect, useRef } from 'react';
import type { Pet, MedicalRecord, Vaccination, Prescription, HealthStat, DiseaseTracking, Booking } from '../types';
import api from '../api/client';

interface ScannedPetState {
  pet: Pet | null;
  token: string | null;
  records: MedicalRecord[];
  vaccinations: Vaccination[];
  prescriptions: Prescription[];
  healthStats: HealthStat[];
  diseases: DiseaseTracking[];
  activeBooking: Booking | null;
  bookingConfirmed: boolean;
}

interface ScannedPetContextType extends ScannedPetState {
  // Actions
  setPetData: (
    pet: Pet,
    token: string,
    records?: MedicalRecord[],
    vaccinations?: Vaccination[],
    prescriptions?: Prescription[],
    healthStats?: HealthStat[],
    diseases?: DiseaseTracking[]
  ) => void;
  setBooking: (booking: Booking | null, confirmed?: boolean) => void;
  updateRecords: (records: MedicalRecord[]) => void;
  updateVaccinations: (vaccinations: Vaccination[]) => void;
  updatePrescriptions: (prescriptions: Prescription[]) => void;
  updateHealthStats: (stats: HealthStat[]) => void;
  updateDiseases: (diseases: DiseaseTracking[]) => void;
  addRecord: (record: MedicalRecord) => void;
  addPrescription: (prescription: Prescription) => void;
  addHealthStat: (stat: HealthStat) => void;
  addDisease: (disease: DiseaseTracking) => void;
  removeRecord: (id: string) => void;
  removePrescription: (id: string) => void;
  removeHealthStat: (id: string) => void;
  removeDisease: (id: string) => void;
  clearPet: () => void;
  // Polling
  isPolling: boolean;
  startPolling: () => void;
  stopPolling: () => void;
}

const initialState: ScannedPetState = {
  pet: null,
  token: null,
  records: [],
  vaccinations: [],
  prescriptions: [],
  healthStats: [],
  diseases: [],
  activeBooking: null,
  bookingConfirmed: false,
};

const ScannedPetContext = createContext<ScannedPetContextType | null>(null);

export function ScannedPetProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<ScannedPetState>(initialState);
  const [isPolling, setIsPolling] = useState(false);
  const [lastScannedAt, setLastScannedAt] = useState<string | null>(null);
  const pollingRef = useRef<number | null>(null);

  // Poll for scanned pet from Flutter app
  const pollForScannedPet = useCallback(async () => {
    try {
      const result = await api.getScannedPet();
      if (result.pet && result.scannedAt !== lastScannedAt) {
        setLastScannedAt(result.scannedAt);
        const petData = result.pet as Pet & {
          medicalRecords?: MedicalRecord[];
          vaccinations?: Vaccination[];
          prescriptions?: Prescription[];
          healthStats?: HealthStat[];
          diseases?: DiseaseTracking[];
        };

        setState({
          pet: petData,
          token: '', // Token is handled by backend
          records: petData.medicalRecords || [],
          vaccinations: petData.vaccinations || [],
          prescriptions: petData.prescriptions || [],
          healthStats: petData.healthStats || [],
          diseases: petData.diseases || [],
          activeBooking: null,
          bookingConfirmed: false,
        });

        setIsPolling(false);
        api.clearScannedPet().catch(() => {});
      }
    } catch (error) {
      console.log('Poll error:', error);
    }
  }, [lastScannedAt]);

  // Start/stop polling
  useEffect(() => {
    if (isPolling) {
      pollingRef.current = window.setInterval(pollForScannedPet, 2000);
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

  const setPetData = useCallback(
    (
      pet: Pet,
      token: string,
      records: MedicalRecord[] = [],
      vaccinations: Vaccination[] = [],
      prescriptions: Prescription[] = [],
      healthStats: HealthStat[] = [],
      diseases: DiseaseTracking[] = []
    ) => {
      setState({
        pet,
        token,
        records,
        vaccinations,
        prescriptions,
        healthStats,
        diseases,
        activeBooking: null,
        bookingConfirmed: false,
      });
    },
    []
  );

  const setBooking = useCallback((booking: Booking | null, confirmed = false) => {
    setState((prev) => ({
      ...prev,
      activeBooking: booking,
      bookingConfirmed: confirmed,
    }));
  }, []);

  const updateRecords = useCallback((records: MedicalRecord[]) => {
    setState((prev) => ({ ...prev, records }));
  }, []);

  const updateVaccinations = useCallback((vaccinations: Vaccination[]) => {
    setState((prev) => ({ ...prev, vaccinations }));
  }, []);

  const updatePrescriptions = useCallback((prescriptions: Prescription[]) => {
    setState((prev) => ({ ...prev, prescriptions }));
  }, []);

  const updateHealthStats = useCallback((healthStats: HealthStat[]) => {
    setState((prev) => ({ ...prev, healthStats }));
  }, []);

  const updateDiseases = useCallback((diseases: DiseaseTracking[]) => {
    setState((prev) => ({ ...prev, diseases }));
  }, []);

  const addRecord = useCallback((record: MedicalRecord) => {
    setState((prev) => ({ ...prev, records: [record, ...prev.records] }));
  }, []);

  const addPrescription = useCallback((prescription: Prescription) => {
    setState((prev) => ({ ...prev, prescriptions: [prescription, ...prev.prescriptions] }));
  }, []);

  const addHealthStat = useCallback((stat: HealthStat) => {
    setState((prev) => ({ ...prev, healthStats: [stat, ...prev.healthStats] }));
  }, []);

  const addDisease = useCallback((disease: DiseaseTracking) => {
    setState((prev) => ({ ...prev, diseases: [disease, ...prev.diseases] }));
  }, []);

  const removeRecord = useCallback((id: string) => {
    setState((prev) => ({ ...prev, records: prev.records.filter((r) => r.id !== id) }));
  }, []);

  const removePrescription = useCallback((id: string) => {
    setState((prev) => ({ ...prev, prescriptions: prev.prescriptions.filter((p) => p.id !== id) }));
  }, []);

  const removeHealthStat = useCallback((id: string) => {
    setState((prev) => ({ ...prev, healthStats: prev.healthStats.filter((s) => s.id !== id) }));
  }, []);

  const removeDisease = useCallback((id: string) => {
    setState((prev) => ({ ...prev, diseases: prev.diseases.filter((d) => d.id !== id) }));
  }, []);

  const clearPet = useCallback(() => {
    setState(initialState);
    setIsPolling(false);
  }, []);

  const startPolling = useCallback(() => {
    setIsPolling(true);
  }, []);

  const stopPolling = useCallback(() => {
    setIsPolling(false);
  }, []);

  return (
    <ScannedPetContext.Provider
      value={{
        ...state,
        setPetData,
        setBooking,
        updateRecords,
        updateVaccinations,
        updatePrescriptions,
        updateHealthStats,
        updateDiseases,
        addRecord,
        addPrescription,
        addHealthStat,
        addDisease,
        removeRecord,
        removePrescription,
        removeHealthStat,
        removeDisease,
        clearPet,
        isPolling,
        startPolling,
        stopPolling,
      }}
    >
      {children}
    </ScannedPetContext.Provider>
  );
}

export function useScannedPet() {
  const context = useContext(ScannedPetContext);
  if (!context) {
    throw new Error('useScannedPet must be used within a ScannedPetProvider');
  }
  return context;
}
