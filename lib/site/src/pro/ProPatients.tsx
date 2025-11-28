import { useEffect, useState } from 'react';
import { Search, User, FileText, Syringe } from 'lucide-react';
import { Card, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Pet, MedicalRecord, Vaccination } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

export function ProPatients() {
  const [patients, setPatients] = useState<Pet[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedPatient, setSelectedPatient] = useState<Pet | null>(null);
  const [medicalRecords, setMedicalRecords] = useState<MedicalRecord[]>([]);
  const [vaccinations, setVaccinations] = useState<Vaccination[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);

  useEffect(() => {
    fetchPatients();
  }, []);

  async function fetchPatients() {
    setLoading(true);
    try {
      const data = await api.getProviderPatients();
      setPatients(data);
    } catch (error) {
      console.error('Error fetching patients:', error);
    } finally {
      setLoading(false);
    }
  }

  async function fetchPatientDetails(petId: string) {
    setDetailLoading(true);
    try {
      const [records, vacc] = await Promise.all([
        api.getPetMedicalRecords(petId),
        api.getPetVaccinations(petId),
      ]);
      setMedicalRecords(records);
      setVaccinations(vacc);
    } catch (error) {
      console.error('Error fetching patient details:', error);
    } finally {
      setDetailLoading(false);
    }
  }

  const handleSelectPatient = (patient: Pet) => {
    setSelectedPatient(patient);
    fetchPatientDetails(patient.id);
  };

  const filteredPatients = patients.filter(
    (p) =>
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.species.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const getSpeciesEmoji = (species: string) => {
    switch (species.toUpperCase()) {
      case 'DOG':
        return '🐕';
      case 'CAT':
        return '🐈';
      case 'BIRD':
        return '🐦';
      case 'RABBIT':
        return '🐰';
      default:
        return '🐾';
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Patients</h1>
          <p className="text-gray-600 mt-1">Consultez les dossiers de vos patients</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Patients list */}
          <div className="lg:col-span-1">
            <Card>
              <div className="relative mb-4">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
                <Input
                  placeholder="Rechercher un patient..."
                  className="pl-10"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>

              {loading ? (
                <div className="flex items-center justify-center h-64">
                  <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
                </div>
              ) : filteredPatients.length === 0 ? (
                <div className="text-center py-8">
                  <User size={48} className="text-gray-300 mx-auto mb-4" />
                  <p className="text-gray-500">Aucun patient trouvé</p>
                </div>
              ) : (
                <div className="space-y-2 max-h-[600px] overflow-y-auto">
                  {filteredPatients.map((patient) => (
                    <button
                      key={patient.id}
                      className={`w-full text-left p-3 rounded-lg transition-colors ${
                        selectedPatient?.id === patient.id
                          ? 'bg-primary-50 border border-primary-200'
                          : 'bg-gray-50 hover:bg-gray-100'
                      }`}
                      onClick={() => handleSelectPatient(patient)}
                    >
                      <div className="flex items-center space-x-3">
                        {patient.photoUrl ? (
                          <img
                            src={patient.photoUrl}
                            alt={patient.name}
                            className="w-12 h-12 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-12 h-12 bg-primary-100 rounded-full flex items-center justify-center text-2xl">
                            {getSpeciesEmoji(patient.species)}
                          </div>
                        )}
                        <div>
                          <p className="font-medium text-gray-900">{patient.name}</p>
                          <p className="text-sm text-gray-500">
                            {patient.species} {patient.breed && `- ${patient.breed}`}
                          </p>
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </Card>
          </div>

          {/* Patient detail */}
          <div className="lg:col-span-2">
            {selectedPatient ? (
              <div className="space-y-6">
                {/* Patient info */}
                <Card>
                  <div className="flex items-start space-x-4">
                    {selectedPatient.photoUrl ? (
                      <img
                        src={selectedPatient.photoUrl}
                        alt={selectedPatient.name}
                        className="w-20 h-20 rounded-xl object-cover"
                      />
                    ) : (
                      <div className="w-20 h-20 bg-primary-100 rounded-xl flex items-center justify-center text-4xl">
                        {getSpeciesEmoji(selectedPatient.species)}
                      </div>
                    )}
                    <div className="flex-1">
                      <h2 className="text-xl font-semibold text-gray-900">{selectedPatient.name}</h2>
                      <p className="text-gray-500">
                        {selectedPatient.species}
                        {selectedPatient.breed && ` - ${selectedPatient.breed}`}
                      </p>

                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
                        {selectedPatient.gender && (
                          <div>
                            <p className="text-xs text-gray-500">Sexe</p>
                            <p className="font-medium">
                              {selectedPatient.gender === 'MALE' ? 'Mâle' : selectedPatient.gender === 'FEMALE' ? 'Femelle' : 'Inconnu'}
                            </p>
                          </div>
                        )}
                        {selectedPatient.birthDate && (
                          <div>
                            <p className="text-xs text-gray-500">Date de naissance</p>
                            <p className="font-medium">
                              {format(new Date(selectedPatient.birthDate), 'dd/MM/yyyy')}
                            </p>
                          </div>
                        )}
                        {selectedPatient.weight && (
                          <div>
                            <p className="text-xs text-gray-500">Poids</p>
                            <p className="font-medium">{selectedPatient.weight} kg</p>
                          </div>
                        )}
                        {selectedPatient.microchip && (
                          <div>
                            <p className="text-xs text-gray-500">Puce</p>
                            <p className="font-medium text-xs">{selectedPatient.microchip}</p>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </Card>

                {detailLoading ? (
                  <div className="flex items-center justify-center h-32">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" />
                  </div>
                ) : (
                  <>
                    {/* Vaccinations */}
                    <Card>
                      <div className="flex items-center space-x-2 mb-4">
                        <Syringe size={20} className="text-green-600" />
                        <h3 className="font-semibold text-gray-900">Vaccinations</h3>
                      </div>

                      {vaccinations.length === 0 ? (
                        <p className="text-gray-500 text-sm">Aucune vaccination enregistrée</p>
                      ) : (
                        <div className="space-y-3">
                          {vaccinations.map((vacc) => (
                            <div
                              key={vacc.id}
                              className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                            >
                              <div>
                                <p className="font-medium text-gray-900">{vacc.name}</p>
                                <p className="text-sm text-gray-500">
                                  {format(new Date(vacc.date), 'dd MMMM yyyy', { locale: fr })}
                                </p>
                              </div>
                              {vacc.nextDueDate && (
                                <div className="text-right">
                                  <p className="text-xs text-gray-500">Prochain rappel</p>
                                  <p className="text-sm font-medium text-primary-600">
                                    {format(new Date(vacc.nextDueDate), 'dd/MM/yyyy')}
                                  </p>
                                </div>
                              )}
                            </div>
                          ))}
                        </div>
                      )}
                    </Card>

                    {/* Medical records */}
                    <Card>
                      <div className="flex items-center space-x-2 mb-4">
                        <FileText size={20} className="text-blue-600" />
                        <h3 className="font-semibold text-gray-900">Historique médical</h3>
                      </div>

                      {medicalRecords.length === 0 ? (
                        <p className="text-gray-500 text-sm">Aucun enregistrement médical</p>
                      ) : (
                        <div className="space-y-3">
                          {medicalRecords.map((record) => (
                            <div
                              key={record.id}
                              className="p-3 bg-gray-50 rounded-lg"
                            >
                              <div className="flex items-center justify-between mb-2">
                                <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                                  {record.type}
                                </span>
                                <span className="text-xs text-gray-500">
                                  {format(new Date(record.date), 'dd MMMM yyyy', { locale: fr })}
                                </span>
                              </div>
                              <p className="font-medium text-gray-900">{record.title}</p>
                              {record.description && (
                                <p className="text-sm text-gray-600 mt-1">{record.description}</p>
                              )}
                              {record.veterinarian && (
                                <p className="text-xs text-gray-500 mt-2">
                                  Dr. {record.veterinarian}
                                </p>
                              )}
                            </div>
                          ))}
                        </div>
                      )}
                    </Card>
                  </>
                )}
              </div>
            ) : (
              <Card className="text-center py-12">
                <User size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez un patient pour voir son dossier</p>
              </Card>
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
