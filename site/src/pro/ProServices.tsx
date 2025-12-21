import { useEffect, useState } from 'react';
import { Plus, Edit2, Trash2, Clock, DollarSign, Info } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { Service } from '../types';

// Commission par défaut (sera remplacée par la valeur du provider)
const DEFAULT_COMMISSION_DA = 100;

interface ServiceFormData {
  title: string;
  description: string;
  durationMin: number;
  basePrice: number; // Prix de base (ce que le pro reçoit)
}

export function ProServices() {
  const [services, setServices] = useState<Service[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingService, setEditingService] = useState<Service | null>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [commissionDa, setCommissionDa] = useState(DEFAULT_COMMISSION_DA);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<ServiceFormData>();

  useEffect(() => {
    fetchServices();
    fetchProviderCommission();
  }, []);

  async function fetchProviderCommission() {
    try {
      const provider = await api.myProvider();
      if (provider && typeof provider.vetCommissionDa === 'number') {
        setCommissionDa(provider.vetCommissionDa);
      }
    } catch (error) {
      console.error('Error fetching provider commission:', error);
    }
  }

  async function fetchServices() {
    setLoading(true);
    try {
      const data = await api.myServices();
      setServices(data);
    } catch (error) {
      console.error('Error fetching services:', error);
    } finally {
      setLoading(false);
    }
  }

  const openCreateModal = () => {
    setEditingService(null);
    reset({
      title: '',
      description: '',
      durationMin: 30,
      basePrice: 0,
    });
    setShowModal(true);
  };

  const openEditModal = (service: Service) => {
    setEditingService(service);
    // Le prix stocké = total (base + commission), on extrait le base
    const basePrice = Math.max(0, service.price - commissionDa);
    reset({
      title: service.title,
      description: service.description || '',
      durationMin: service.durationMin,
      basePrice,
    });
    setShowModal(true);
  };

  const onSubmit = async (data: ServiceFormData) => {
    setActionLoading(true);
    try {
      // On envoie le total (base + commission) au backend
      const totalPrice = data.basePrice + commissionDa;
      const payload = {
        title: data.title,
        description: data.description,
        durationMin: data.durationMin,
        price: totalPrice,
      };

      if (editingService) {
        await api.updateMyService(editingService.id, payload);
      } else {
        await api.createMyService(payload);
      }
      await fetchServices();
      setShowModal(false);
    } catch (error) {
      console.error('Error saving service:', error);
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async (serviceId: string) => {
    if (!confirm('Êtes-vous sûr de vouloir supprimer ce service ?')) return;

    try {
      await api.deleteMyService(serviceId);
      setServices((prev) => prev.filter((s) => s.id !== serviceId));
    } catch (error) {
      console.error('Error deleting service:', error);
    }
  };

  // Calcul du prix de base à partir du total stocké
  const getBasePrice = (totalPrice: number) => Math.max(0, totalPrice - commissionDa);

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Mes Services</h1>
            <p className="text-gray-600 mt-1">Gérez vos prestations et tarifs</p>
          </div>
          <Button onClick={openCreateModal}>
            <Plus size={16} className="mr-2" />
            Nouveau service
          </Button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
          </div>
        ) : services.length === 0 ? (
          <Card className="text-center py-12">
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Plus size={32} className="text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">Aucun service</h3>
            <p className="text-gray-500 mb-6">
              Commencez par créer votre premier service pour recevoir des réservations
            </p>
            <Button onClick={openCreateModal}>
              <Plus size={16} className="mr-2" />
              Créer un service
            </Button>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {services.map((service) => {
              const basePrice = getBasePrice(service.price);
              return (
                <Card key={service.id}>
                  <div className="flex items-start justify-between mb-4">
                    <h3 className="font-semibold text-gray-900">{service.title}</h3>
                    <div className="flex space-x-1">
                      <button
                        onClick={() => openEditModal(service)}
                        className="p-2 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
                      >
                        <Edit2 size={16} />
                      </button>
                      <button
                        onClick={() => handleDelete(service.id)}
                        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>

                  {service.description && (
                    <p className="text-sm text-gray-500 mb-4 line-clamp-2">{service.description}</p>
                  )}

                  <div className="flex items-center justify-between pt-4 border-t border-gray-100">
                    <div className="flex items-center text-sm text-gray-500">
                      <Clock size={14} className="mr-1" />
                      {service.durationMin} min
                    </div>
                    <div className="text-right">
                      <div className="flex items-center font-semibold text-primary-600">
                        <DollarSign size={14} className="mr-1" />
                        {basePrice} + {commissionDa} = {service.price} DA
                      </div>
                      <p className="text-xs text-gray-400">Votre prix + Commission = Total client</p>
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <h2 className="text-xl font-semibold text-gray-900 mb-6">
              {editingService ? 'Modifier le service' : 'Nouveau service'}
            </h2>

            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
              <div>
                <Input
                  label="Nom du service"
                  placeholder="Ex: Consultation générale"
                  {...register('title', { required: 'Nom requis' })}
                  error={errors.title?.message}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description (optionnelle)
                </label>
                <textarea
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  rows={3}
                  placeholder="Décrivez votre service..."
                  {...register('description')}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Input
                    type="number"
                    label="Durée (minutes)"
                    min={15}
                    step={15}
                    {...register('durationMin', {
                      required: 'Durée requise',
                      min: { value: 15, message: 'Minimum 15 min' },
                      valueAsNumber: true,
                    })}
                    error={errors.durationMin?.message}
                  />
                </div>

                <div>
                  <Input
                    type="number"
                    label="Votre prix (DA)"
                    min={0}
                    {...register('basePrice', {
                      required: 'Prix requis',
                      min: { value: 0, message: 'Prix invalide' },
                      valueAsNumber: true,
                    })}
                    error={errors.basePrice?.message}
                  />
                </div>
              </div>

              {/* Commission info */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 flex items-start gap-2">
                <Info size={16} className="text-blue-600 mt-0.5 flex-shrink-0" />
                <div className="text-sm text-blue-800">
                  <p className="font-medium">Commission Vegece: {commissionDa} DA</p>
                  <p className="text-blue-600">
                    Le client paiera: Votre prix + {commissionDa} DA
                  </p>
                </div>
              </div>

              <div className="flex space-x-3 pt-4">
                <Button
                  type="button"
                  variant="secondary"
                  className="flex-1"
                  onClick={() => setShowModal(false)}
                >
                  Annuler
                </Button>
                <Button type="submit" className="flex-1" isLoading={actionLoading}>
                  {editingService ? 'Enregistrer' : 'Créer'}
                </Button>
              </div>
            </form>
          </Card>
        </div>
      )}
    </DashboardLayout>
  );
}
