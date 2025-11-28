# Otha Site - Admin & Pro Dashboard

Site web React pour la gestion administrative et professionnelle de l'application Otha.

## Technologies

- **React 19** + **TypeScript**
- **Vite** - Build tool
- **Tailwind CSS v4** - Styling
- **React Router v7** - Routing
- **Zustand** - State management
- **Axios** - HTTP client
- **React Query** - Data fetching
- **React Hook Form** - Form management
- **date-fns** - Date utilities
- **Lucide React** - Icons

## Installation

```bash
# Installer les dépendances
npm install

# Copier le fichier d'environnement
cp .env.example .env
```

## Configuration

Modifier le fichier `.env` pour configurer l'URL de l'API:

```env
VITE_API_URL=https://api.piecespro.com/api/v1
```

## Développement

```bash
# Lancer le serveur de développement
npm run dev

# Le site sera accessible sur http://localhost:5173
```

## Build

```bash
# Compiler pour la production
npm run build

# Les fichiers seront dans le dossier dist/
```

## Déploiement

Pour déployer sur un VPS Ubuntu:

```bash
# Build le projet
npm run build

# Copier le dossier dist/ sur le serveur
# Configurer Nginx pour servir les fichiers statiques
```

Exemple de configuration Nginx:

```nginx
server {
    listen 80;
    server_name votredomaine.com;
    root /var/www/otha-site/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## Structure du projet

```
src/
├── admin/              # Pages d'administration
│   ├── AdminDashboard  - Dashboard principal
│   ├── AdminApplications - Gestion des demandes pro
│   ├── AdminUsers      - Gestion des utilisateurs
│   ├── AdminAdoptions  - Modération des adoptions
│   └── AdminEarnings   - Gestion des gains
│
├── pro/                # Pages professionnels vétérinaires
│   ├── ProDashboard    - Dashboard pro
│   ├── ProServices     - Gestion des services
│   ├── ProAgenda       - Calendrier des rendez-vous
│   ├── ProPatients     - Liste des patients
│   ├── ProAvailability - Gestion des disponibilités
│   ├── ProDaycare      - Gestion de la garderie
│   ├── ProEarnings     - Suivi des gains
│   └── ProSettings     - Paramètres du profil
│
├── auth/               # Authentification
│   └── LoginPage       - Page de connexion
│
├── shared/             # Composants partagés
│   ├── components/     - Button, Card, Input, etc.
│   └── layouts/        - DashboardLayout
│
├── api/                # Client API
│   └── client.ts       - ApiClient (axios)
│
├── store/              # State management (Zustand)
│   └── authStore.ts    - État d'authentification
│
├── types/              # Types TypeScript
│   └── index.ts        - Tous les types
│
└── hooks/              # Custom hooks
    └── useAuth.ts      - Hooks d'authentification
```

## Fonctionnalités Admin

- **Dashboard**: Vue d'ensemble des demandes en attente
- **Demandes Pro**: Approuver/rejeter les inscriptions des professionnels
- **Utilisateurs**: Lister et voir les détails des utilisateurs
- **Adoptions**: Modérer les annonces d'adoption
- **Gains**: Gérer les paiements des professionnels

## Fonctionnalités Pro

- **Dashboard**: Statistiques et RDV du jour
- **Services**: Créer/modifier/supprimer des services
- **Agenda**: Calendrier hebdomadaire des rendez-vous
- **Patients**: Voir les dossiers médicaux des animaux
- **Disponibilités**: Configurer les horaires de travail
- **Garderie**: Gérer les réservations de garderie
- **Gains**: Suivre les revenus mensuels
- **Paramètres**: Modifier le profil professionnel

## API

Le client API se connecte au backend NestJS à l'URL configurée dans `VITE_API_URL`.

Endpoints principaux:
- `/auth/*` - Authentification
- `/users/*` - Gestion utilisateurs
- `/providers/*` - Gestion professionnels
- `/bookings/*` - Réservations
- `/daycare/*` - Garderie
- `/adopt/*` - Adoptions
- `/earnings/*` - Gains

## Authentification

L'authentification utilise des tokens JWT avec refresh automatique:
- Les tokens sont stockés dans `localStorage`
- Refresh automatique sur 401
- Protection des routes par rôle (ADMIN, PRO)
