import { useEffect, useState } from 'react';
import { Search, User as UserIcon, Mail, Phone, MapPin, Calendar } from 'lucide-react';
import { Card, Input, Button } from '../shared/components';
import { DashboardLayout } from '../shared/layouts/DashboardLayout';
import api from '../api/client';
import type { User } from '../types';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

export function AdminUsers() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  // Default to 'USER' role (clients) like mobile admin
  const [selectedRole, setSelectedRole] = useState<string>('USER');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  useEffect(() => {
    fetchUsers();
  }, [searchQuery, selectedRole]);

  async function fetchUsers() {
    setLoading(true);
    try {
      const data = await api.adminListUsers(
        searchQuery || undefined,
        50,
        0,
        selectedRole || undefined
      );
      // Ensure data is always an array
      setUsers(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching users:', error);
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    fetchUsers();
  };

  const getRoleBadgeColor = (role: string) => {
    switch (role) {
      case 'ADMIN':
        return 'bg-purple-100 text-purple-700';
      case 'PRO':
        return 'bg-blue-100 text-blue-700';
      default:
        return 'bg-gray-100 text-gray-700';
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {selectedRole === 'USER' ? 'Clients' : selectedRole === 'PRO' ? 'Professionnels' : 'Utilisateurs'}
          </h1>
          <p className="text-gray-600 mt-1">Gérez les utilisateurs de la plateforme</p>
        </div>

        {/* Search and filters */}
        <Card>
          <form onSubmit={handleSearch} className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
              <Input
                placeholder="Rechercher nom, email, téléphone..."
                className="pl-10"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <select
              className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              value={selectedRole}
              onChange={(e) => setSelectedRole(e.target.value)}
            >
              <option value="">Tous les rôles</option>
              <option value="USER">Utilisateurs</option>
              <option value="PRO">Professionnels</option>
              <option value="ADMIN">Administrateurs</option>
            </select>
            <Button type="submit">Rechercher</Button>
          </form>
        </Card>

        {/* Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* List */}
          <div className="lg:col-span-2">
            {loading ? (
              <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600" />
              </div>
            ) : users.length === 0 ? (
              <Card className="text-center py-12">
                <p className="text-gray-500">Aucun utilisateur trouvé</p>
              </Card>
            ) : (
              <div className="space-y-3">
                {users.map((user) => {
                  // Build display name like mobile
                  const firstName = user.firstName || '';
                  const lastName = user.lastName || '';
                  const displayName = [firstName, lastName].filter(Boolean).join(' ').trim();
                  const avatarLetter = (displayName || user.email || '?').charAt(0).toUpperCase();

                  return (
                    <Card
                      key={user.id}
                      className={`cursor-pointer transition-all ${
                        selectedUser?.id === user.id
                          ? 'ring-2 ring-primary-500'
                          : 'hover:shadow-md'
                      }`}
                      onClick={() => setSelectedUser(user)}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                          {user.photoUrl ? (
                            <img
                              src={user.photoUrl}
                              alt={user.email}
                              className="w-12 h-12 rounded-full object-cover"
                            />
                          ) : (
                            <div className="w-12 h-12 bg-primary-100 rounded-full flex items-center justify-center">
                              <span className="text-primary-700 font-bold text-lg">
                                {avatarLetter}
                              </span>
                            </div>
                          )}
                          <div>
                            <p className="font-medium text-gray-900">
                              {displayName || '(Sans nom)'}
                            </p>
                            <p className="text-sm text-gray-500">{user.email}</p>
                            {user.phone && (
                              <p className="text-xs text-gray-400">{user.phone}</p>
                            )}
                          </div>
                        </div>
                        <span className={`text-xs px-2 py-1 rounded-full ${getRoleBadgeColor(user.role)}`}>
                          {user.role}
                        </span>
                      </div>
                    </Card>
                  );
                })}
              </div>
            )}
          </div>

          {/* Detail panel */}
          <div className="lg:col-span-1">
            {selectedUser ? (() => {
              // Build display name like mobile
              const firstName = selectedUser.firstName || '';
              const lastName = selectedUser.lastName || '';
              const displayName = [firstName, lastName].filter(Boolean).join(' ').trim();
              const avatarLetter = (displayName || selectedUser.email || '?').charAt(0).toUpperCase();

              return (
                <Card className="sticky top-6">
                  <h3 className="font-semibold text-gray-900 mb-4">Détails de l'utilisateur</h3>

                  {/* Avatar */}
                  <div className="flex justify-center mb-4">
                    {selectedUser.photoUrl ? (
                      <img
                        src={selectedUser.photoUrl}
                        alt={selectedUser.email}
                        className="w-24 h-24 rounded-full object-cover"
                      />
                    ) : (
                      <div className="w-24 h-24 bg-primary-100 rounded-full flex items-center justify-center">
                        <span className="text-primary-700 font-bold text-3xl">
                          {avatarLetter}
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Name */}
                  <p className="text-center font-semibold text-gray-900 text-lg mb-2">
                    {displayName || '(Sans nom)'}
                  </p>

                  <div className="text-center mb-4">
                    <span className={`text-sm px-3 py-1 rounded-full ${getRoleBadgeColor(selectedUser.role)}`}>
                      {selectedUser.role}
                    </span>
                  </div>

                  <div className="space-y-4">
                    <div className="flex items-center space-x-3 text-sm">
                      <Mail size={16} className="text-gray-400" />
                      <div>
                        <p className="text-gray-500">Email</p>
                        <p className="font-medium">{selectedUser.email}</p>
                      </div>
                    </div>

                    {selectedUser.phone && (
                      <div className="flex items-center space-x-3 text-sm">
                        <Phone size={16} className="text-gray-400" />
                        <div>
                          <p className="text-gray-500">Téléphone</p>
                          <p className="font-medium">{selectedUser.phone}</p>
                        </div>
                      </div>
                    )}

                    {selectedUser.city && (
                      <div className="flex items-center space-x-3 text-sm">
                        <MapPin size={16} className="text-gray-400" />
                        <div>
                          <p className="text-gray-500">Ville</p>
                          <p className="font-medium">{selectedUser.city}</p>
                        </div>
                      </div>
                    )}

                    <div className="flex items-center space-x-3 text-sm">
                      <Calendar size={16} className="text-gray-400" />
                      <div>
                        <p className="text-gray-500">Inscrit le</p>
                        <p className="font-medium">
                          {format(new Date(selectedUser.createdAt), 'dd MMMM yyyy', { locale: fr })}
                        </p>
                      </div>
                    </div>
                  </div>
                </Card>
              );
            })() : (
              <Card className="text-center py-12">
                <UserIcon size={48} className="text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">Sélectionnez un utilisateur pour voir les détails</p>
              </Card>
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
