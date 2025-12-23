# Plan d'implémentation - Fonctionnalité Carrière

## Résumé de la fonctionnalité

Une plateforme de mise en relation pour les stages/emplois dans le domaine vétérinaire.

### Deux sections principales:

1. **Demandes** (côté client)
   - Les clients postent leurs recherches de stage/emploi
   - Informations visibles publiquement: Bio uniquement (ex: "Je recherche un stage de 3 mois...")
   - Informations complètes visibles par les PROS uniquement: Nom, Prénom, Email, Téléphone, Bio détaillée, CV
   - **1 annonce par compte maximum**
   - Validation admin requise

2. **Offres** (côté pro)
   - Les vétérinaires postent leurs offres d'emploi/stage
   - Visibles par tous (clients et pros)
   - Espace de communication avec les candidats
   - Validation admin requise

---

## Phase 1: Backend

### 1.1 Modèle Prisma (schema.prisma)

```prisma
enum CareerStatus {
  PENDING
  APPROVED
  REJECTED
  ARCHIVED
}

enum CareerType {
  REQUEST    // Demande (client cherche stage/emploi)
  OFFER      // Offre (pro propose emploi)
}

model CareerPost {
  id        String       @id @default(cuid())
  createdAt DateTime     @default(now())
  updatedAt DateTime     @updatedAt
  status    CareerStatus @default(PENDING)
  type      CareerType

  // Infos publiques (visibles par tous)
  title       String      // Titre de l'annonce
  publicBio   String      // Bio courte visible publiquement
  city        String?     // Ville
  domain      String?     // Domaine (vétérinaire, ASV, etc.)
  duration    String?     // Durée (3 mois, CDI, CDD, etc.)

  // Infos privées (visibles par pros uniquement pour les REQUEST)
  fullName    String?     // Nom complet
  email       String?     // Email de contact
  phone       String?     // Téléphone
  detailedBio String?     // Bio détaillée
  cvUrl       String?     // URL du CV uploadé

  // Pour les offres (OFFER)
  salary      String?     // Salaire/rémunération
  requirements String?    // Prérequis

  // Relations
  createdById String
  createdBy   User        @relation(fields: [createdById], references: [id])

  // Modération
  moderationNote String?
  approvedAt     DateTime?
  rejectedAt     DateTime?
  archivedAt     DateTime?

  // Conversations
  conversations CareerConversation[]

  @@unique([createdById, type]) // 1 annonce REQUEST par user, 1 OFFER par pro
  @@index([status, type, createdAt])
  @@index([city])
}

model CareerConversation {
  id        String   @id @default(cuid())
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  postId    String
  post      CareerPost @relation(fields: [postId], references: [id])

  // Le candidat (pour OFFER) ou le pro intéressé (pour REQUEST)
  participantId String
  participant   User   @relation(fields: [participantId], references: [id])

  messages CareerMessage[]

  @@unique([postId, participantId])
}

model CareerMessage {
  id        String   @id @default(cuid())
  createdAt DateTime @default(now())

  conversationId String
  conversation   CareerConversation @relation(fields: [conversationId], references: [id])

  senderId String
  sender   User   @relation(fields: [senderId], references: [id])

  content String

  @@index([conversationId, createdAt])
}
```

### 1.2 DTOs (backend/src/career/dto/)

- `create-career-post.dto.ts`
- `update-career-post.dto.ts`
- `send-career-message.dto.ts`

### 1.3 Controller (backend/src/career/career.controller.ts)

```typescript
// Routes clients/pros
GET    /career/feed                    // Liste des annonces approuvées
GET    /career/posts/:id               // Détail d'une annonce
POST   /career/posts                   // Créer une annonce
PATCH  /career/posts/:id               // Modifier son annonce
DELETE /career/posts/:id               // Supprimer son annonce
GET    /career/my/post                 // Mon annonce (1 seule)

// Conversations
GET    /career/my/conversations        // Mes conversations
GET    /career/conversations/:id       // Messages d'une conversation
POST   /career/posts/:id/contact       // Démarrer une conversation
POST   /career/conversations/:id/messages // Envoyer un message
```

### 1.4 Admin Controller (backend/src/career/career.admin.controller.ts)

```typescript
GET    /admin/career/posts             // Liste par status
PATCH  /admin/career/posts/:id/approve // Approuver
PATCH  /admin/career/posts/:id/reject  // Rejeter
PATCH  /admin/career/posts/approve-all // Approuver tout
```

### 1.5 Service (backend/src/career/career.service.ts)

- Logique métier
- Vérification: 1 annonce par type par user
- Filtrage des infos privées selon le rôle (client vs pro)

---

## Phase 2: API Flutter (lib/core/api.dart)

Ajouter les méthodes:
```dart
// Career Feed
Future<List<Map<String, dynamic>>> careerFeed({String? type, String? city});
Future<Map<String, dynamic>> careerGetPost(String id);

// My Post
Future<Map<String, dynamic>?> careerMyPost();
Future<Map<String, dynamic>> careerCreatePost(Map<String, dynamic> data);
Future<Map<String, dynamic>> careerUpdatePost(String id, Map<String, dynamic> data);
Future<void> careerDeletePost(String id);

// Conversations
Future<List<Map<String, dynamic>>> careerMyConversations();
Future<Map<String, dynamic>> careerGetConversation(String id);
Future<Map<String, dynamic>> careerContactPost(String postId);
Future<Map<String, dynamic>> careerSendMessage(String conversationId, String content);
```

---

## Phase 3: Flutter UI - Client (lib/features/career/)

### 3.1 Fichiers à créer

```
lib/features/career/
├── career_screen.dart           // Écran principal avec tabs Demandes/Offres
├── career_detail_screen.dart    // Détail d'une annonce
├── career_create_screen.dart    // Créer/modifier son annonce
├── career_conversation_screen.dart // Chat
└── widgets/
    ├── career_card.dart         // Card pour liste
    └── career_filter.dart       // Filtres (ville, domaine)
```

### 3.2 Écran principal (career_screen.dart)

```
┌─────────────────────────────────────┐
│  ← Carrière                         │
├─────────────────────────────────────┤
│  [Demandes]  [Offres]               │  ← Tabs
├─────────────────────────────────────┤
│  🔍 Filtrer par ville...            │  ← Recherche
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │ 👤 "Je recherche un stage   │    │
│  │    de 3 mois à Paris..."    │    │
│  │    📍 Paris • Vétérinaire   │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 👤 "Étudiante en 4ème       │    │
│  │    année cherche stage..."  │    │
│  │    📍 Lyon • ASV            │    │
│  └─────────────────────────────┘    │
├─────────────────────────────────────┤
│  [+ Mon annonce]                    │  ← FAB pour créer/voir son annonce
└─────────────────────────────────────┘
```

### 3.3 Modification home_screen.dart

Changer:
- `l10n.boost` → "Carrière"
- `l10n.yourCareer` → "Votre prochaine opportunité"
- Route: `/internships` → `/career`

---

## Phase 4: Flutter UI - Pro (lib/features/pro/)

### 4.1 Ajouter bouton dans pro_home_screen.dart

Dans `_ActionGrid`, ajouter une 5ème action:
```dart
_ActionTile(
  icon: Icons.work_outline,
  label: 'Recrutement',
  subtitle: 'Trouver un stagiaire',
  onTap: () => context.push('/pro/career'),
)
```

### 4.2 Écran pro (pro_career_screen.dart)

```
┌─────────────────────────────────────┐
│  ← Recrutement                      │
├─────────────────────────────────────┤
│  [Candidats]  [Mon offre]           │  ← Tabs
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │ 👤 Marie Dupont              │    │  ← Nom visible pour pro
│  │ 📧 marie@email.com          │    │  ← Email visible pour pro
│  │ 📱 06 12 34 56 78           │    │  ← Tél visible pour pro
│  │ "Je recherche un stage..."  │    │
│  │ 📍 Paris • Vétérinaire      │    │
│  │ [📄 Voir CV] [💬 Contacter] │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

---

## Phase 5: Traductions (locale_provider.dart)

```dart
// Career - FR
'careerTitle': 'Carrière',
'careerSubtitle': 'Votre prochaine opportunité',
'careerRequests': 'Demandes',
'careerOffers': 'Offres',
'careerMyPost': 'Mon annonce',
'careerCreatePost': 'Créer mon annonce',
'careerEditPost': 'Modifier mon annonce',
'careerPublicBio': 'Présentez-vous (visible par tous)',
'careerDetailedBio': 'Bio détaillée (visible par les pros)',
'careerCity': 'Ville',
'careerDomain': 'Domaine',
'careerDuration': 'Durée',
'careerCV': 'CV',
'careerUploadCV': 'Télécharger mon CV',
'careerContact': 'Contacter',
'careerViewCV': 'Voir le CV',
'careerPendingApproval': 'En attente de validation',
'careerOnePostOnly': 'Vous ne pouvez avoir qu\'une seule annonce',
'careerNoResults': 'Aucune annonce trouvée',
// Pro
'careerRecruitment': 'Recrutement',
'careerFindWorker': 'Trouver un stagiaire/employé',
'careerCandidates': 'Candidats',
'careerMyOffer': 'Mon offre',
'careerCreateOffer': 'Publier une offre',
```

---

## Phase 6: Admin Site (site/src/admin/)

### 6.1 Créer AdminCareer.tsx

Similaire à AdminAdoptions.tsx:
- Tabs: PENDING, APPROVED, REJECTED, ARCHIVED
- Cards avec infos de l'annonce
- Boutons: Approuver, Rejeter, Archiver
- Affichage du CV si présent

### 6.2 Ajouter dans la navigation admin

Dans `AdminDashboard.tsx`, ajouter l'onglet "Carrière"

---

## Phase 7: Routes (lib/router.dart)

```dart
GoRoute(
  path: '/career',
  builder: (context, state) => const CareerScreen(),
),
GoRoute(
  path: '/career/:id',
  builder: (context, state) => CareerDetailScreen(id: state.pathParameters['id']!),
),
GoRoute(
  path: '/career/create',
  builder: (context, state) => const CareerCreateScreen(),
),
GoRoute(
  path: '/career/conversation/:id',
  builder: (context, state) => CareerConversationScreen(id: state.pathParameters['id']!),
),
GoRoute(
  path: '/pro/career',
  builder: (context, state) => const ProCareerScreen(),
),
```

---

## Ordre d'implémentation recommandé

1. ✅ Backend: Prisma schema + migration
2. ✅ Backend: DTOs + Controller + Service
3. ✅ Backend: Admin Controller
4. ✅ Flutter: API methods
5. ✅ Flutter: Traductions
6. ✅ Flutter: career_screen.dart (client)
7. ✅ Flutter: career_create_screen.dart
8. ✅ Flutter: career_detail_screen.dart
9. ✅ Flutter: Modifier home_screen.dart
10. ✅ Flutter: pro_career_screen.dart
11. ✅ Flutter: Modifier pro_home_screen.dart
12. ✅ Admin Site: AdminCareer.tsx
13. ✅ Routes + Tests

---

## Questions de clarification

1. **Upload CV**: Utiliser le même système d'upload que les images adopt? (S3/Cloudinary)
2. **Domaines disponibles**: Liste fixe ou libre? (Vétérinaire, ASV, Secrétaire, Toiletteur, etc.)
3. **Durée**: Liste fixe (Stage 1-3 mois, CDD, CDI) ou champ libre?
4. **Notifications**: Notifier les pros quand une nouvelle demande est approuvée dans leur ville?
