import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { User, FileText, Camera, Save } from 'lucide-react';
import { Card, Button, Input } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import { useAuthStore } from '../store/authStore';
import api from '../api/client';

interface ProfileFormData {
  displayName: string;
  bio: string;
  address: string;
  specialties: string;
}

export function ProSettings() {
  const { provider, setProvider } = useAuthStore();
  const [loading, setLoading] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingAvn, setUploadingAvn] = useState<'front' | 'back' | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<ProfileFormData>();

  useEffect(() => {
    if (provider) {
      reset({
        displayName: provider.displayName || '',
        bio: provider.bio || '',
        address: provider.address || '',
        specialties: provider.specialties?.join(', ') || '',
      });
    }
  }, [provider, reset]);

  const onSubmit = async (data: ProfileFormData) => {
    setLoading(true);
    try {
      const updated = await api.upsertMyProvider({
        displayName: data.displayName,
        bio: data.bio,
        address: data.address,
        specialties: data.specialties.split(',').map((s) => s.trim()).filter(Boolean),
      });
      setProvider(updated);
      alert('Profil mis à jour !');
    } catch (error) {
      console.error('Error updating profile:', error);
      alert('Erreur lors de la mise à jour');
    } finally {
      setLoading(false);
    }
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadingAvatar(true);
    try {
      const url = await api.uploadFile(file);
      const updated = await api.upsertMyProvider({ avatarUrl: url });
      setProvider(updated);
    } catch (error) {
      console.error('Error uploading avatar:', error);
      alert('Erreur lors du téléchargement');
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handleAvnUpload = async (
    e: React.ChangeEvent<HTMLInputElement>,
    side: 'front' | 'back'
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadingAvn(side);
    try {
      const url = await api.uploadFile(file);
      const updateData = side === 'front' ? { avnCardFront: url } : { avnCardBack: url };
      const updated = await api.upsertMyProvider(updateData);
      setProvider(updated);
    } catch (error) {
      console.error('Error uploading AVN card:', error);
      alert('Erreur lors du téléchargement');
    } finally {
      setUploadingAvn(null);
    }
  };

  const handleVisibilityToggle = async () => {
    if (!provider) return;

    try {
      const updated = await api.setMyVisibility(!provider.visible);
      setProvider(updated);
    } catch (error) {
      console.error('Error toggling visibility:', error);
    }
  };

  const handleReapply = async () => {
    if (!confirm('Voulez-vous soumettre à nouveau votre demande ?')) return;

    try {
      const updated = await api.reapplyMyProvider();
      setProvider(updated);
      alert('Demande soumise !');
    } catch (error) {
      console.error('Error reapplying:', error);
      alert('Erreur lors de la soumission');
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-6 max-w-3xl">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Paramètres</h1>
          <p className="text-gray-600 mt-1">Gérez votre profil professionnel</p>
        </div>

        {/* Status banner */}
        {provider?.status === 'PENDING' && (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <p className="text-yellow-800 font-medium">Votre profil est en attente d'approbation</p>
            <p className="text-yellow-600 text-sm mt-1">
              Vous serez notifié dès que votre demande sera traitée
            </p>
          </div>
        )}

        {provider?.status === 'REJECTED' && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-red-800 font-medium">Votre demande a été rejetée</p>
            <p className="text-red-600 text-sm mt-1">
              Veuillez vérifier vos informations et soumettre à nouveau
            </p>
            <Button className="mt-3" onClick={handleReapply}>
              Soumettre à nouveau
            </Button>
          </div>
        )}

        {/* Avatar */}
        <Card>
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Photo de profil</h2>
          <div className="flex items-center space-x-6">
            <div className="relative">
              {provider?.avatarUrl ? (
                <img
                  src={provider.avatarUrl}
                  alt="Avatar"
                  className="w-24 h-24 rounded-xl object-cover"
                />
              ) : (
                <div className="w-24 h-24 bg-primary-100 rounded-xl flex items-center justify-center">
                  <User size={40} className="text-primary-600" />
                </div>
              )}
              <label className="absolute bottom-0 right-0 p-2 bg-white rounded-full shadow-md cursor-pointer hover:bg-gray-50">
                {uploadingAvatar ? (
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600" />
                ) : (
                  <Camera size={20} className="text-gray-600" />
                )}
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={handleAvatarUpload}
                  disabled={uploadingAvatar}
                />
              </label>
            </div>
            <div>
              <p className="text-sm text-gray-500">
                Téléchargez une photo professionnelle.
                <br />
                Format JPG ou PNG, max 5MB.
              </p>
            </div>
          </div>
        </Card>

        {/* Profile form */}
        <Card>
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Informations du profil</h2>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <Input
              label="Nom affiché"
              placeholder="Dr. Jean Dupont"
              {...register('displayName', { required: 'Nom requis' })}
              error={errors.displayName?.message}
            />

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Bio</label>
              <textarea
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                rows={4}
                placeholder="Décrivez votre expérience et vos spécialités..."
                {...register('bio')}
              />
            </div>

            <Input
              label="Adresse du cabinet"
              placeholder="123 Rue de la Clinique, Alger"
              {...register('address')}
            />

            <Input
              label="Spécialités (séparées par des virgules)"
              placeholder="Chirurgie, Dermatologie, Cardiologie"
              {...register('specialties')}
            />

            <Button type="submit" isLoading={loading}>
              <Save size={16} className="mr-2" />
              Enregistrer
            </Button>
          </form>
        </Card>

        {/* AVN Card */}
        <Card>
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Carte AVN</h2>
          <p className="text-sm text-gray-500 mb-4">
            Téléchargez le recto et le verso de votre carte d'autorisation vétérinaire nationale
          </p>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Front */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Recto</label>
              <div className="relative">
                {provider?.avnCardFront ? (
                  <a
                    href={provider.avnCardFront}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <img
                      src={provider.avnCardFront}
                      alt="AVN Front"
                      className="w-full h-32 object-cover rounded-lg border"
                    />
                  </a>
                ) : (
                  <div className="w-full h-32 bg-gray-100 rounded-lg flex items-center justify-center">
                    <FileText size={32} className="text-gray-400" />
                  </div>
                )}
                <label className="absolute bottom-2 right-2 p-2 bg-white rounded-lg shadow cursor-pointer hover:bg-gray-50">
                  {uploadingAvn === 'front' ? (
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600" />
                  ) : (
                    <Camera size={16} className="text-gray-600" />
                  )}
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => handleAvnUpload(e, 'front')}
                    disabled={uploadingAvn !== null}
                  />
                </label>
              </div>
            </div>

            {/* Back */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Verso</label>
              <div className="relative">
                {provider?.avnCardBack ? (
                  <a
                    href={provider.avnCardBack}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <img
                      src={provider.avnCardBack}
                      alt="AVN Back"
                      className="w-full h-32 object-cover rounded-lg border"
                    />
                  </a>
                ) : (
                  <div className="w-full h-32 bg-gray-100 rounded-lg flex items-center justify-center">
                    <FileText size={32} className="text-gray-400" />
                  </div>
                )}
                <label className="absolute bottom-2 right-2 p-2 bg-white rounded-lg shadow cursor-pointer hover:bg-gray-50">
                  {uploadingAvn === 'back' ? (
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600" />
                  ) : (
                    <Camera size={16} className="text-gray-600" />
                  )}
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => handleAvnUpload(e, 'back')}
                    disabled={uploadingAvn !== null}
                  />
                </label>
              </div>
            </div>
          </div>
        </Card>

        {/* Visibility */}
        {provider?.status === 'APPROVED' && (
          <Card>
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Visibilité</h2>
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium text-gray-900">Profil visible</p>
                <p className="text-sm text-gray-500">
                  Les clients peuvent voir votre profil et prendre rendez-vous
                </p>
              </div>
              <button
                onClick={handleVisibilityToggle}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                  provider.visible ? 'bg-primary-600' : 'bg-gray-200'
                }`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    provider.visible ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
