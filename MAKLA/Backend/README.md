# 🍽️ MAKLA - Backend Architecture

> **Plateforme de découverte de restaurants via vidéos courtes style TikTok**
> Stack: NestJS + Prisma + PostgreSQL + OVH Object Storage

---

## 📋 Table des matières

1. [Vue d'ensemble](#-vue-densemble)
2. [Concepts clés](#-concepts-clés)
3. [Architecture](#-architecture)
4. [Schéma de base de données](#-schéma-de-base-de-données)
5. [Système de gamification](#-système-de-gamification)
6. [Système d'anonymat](#-système-danonymat)
7. [Gestion des vidéos](#-gestion-des-vidéos)
8. [API Endpoints](#-api-endpoints)
9. [Fonctions utilitaires](#-fonctions-utilitaires)
10. [Sécurité](#-sécurité)
11. [Déploiement](#-déploiement)

---

## 🎯 Vue d'ensemble

**MAKLA** est une plateforme de découverte de restaurants qui révolutionne l'expérience de commande en ligne en Algérie. Le système combine :

- 🎥 **Vidéos courtes** (max 30s) style TikTok pour présenter les restaurants
- 🏆 **Gamification** avec système de tiers pour récompenser les meilleurs restaurants
- 🔒 **Anonymat** pour protéger les adresses jusqu'à la commande
- 📦 **Multi-services** : Livraison, Click & Collect, Réservation

---

## 💡 Concepts clés

### 1. **Système de tiers (Gamification)**

Les restaurants débloquent des avantages en fonction du nombre de commandes complétées :

| Tier | Commandes requises | Slots vidéo | Boost visibilité | Badge |
|------|-------------------|-------------|------------------|-------|
| 🥉 **Bronze** | 0-49 | 1 vidéo | - | "Nouveau" |
| 🥈 **Silver** | 50-149 | 2 vidéos | +10% | "Populaire" |
| 🥇 **Gold** | 150-499 | 3 vidéos | +20% | "Top Resto" |
| 💎 **Diamond** | 500-999 | 5 vidéos | +30% | "Elite" |
| 👑 **Legend** | 1000+ | 10 vidéos | +50% | "Légende" |

**Objectifs :**
- ✅ Économiser le stockage (seuls les bons restos ont plusieurs vidéos)
- ✅ Inciter les restaurants à performer
- ✅ Éviter le spam de vidéos
- ✅ Fidéliser les restaurateurs

---

### 2. **Système d'anonymat**

Pour éviter que les clients contournent la plateforme en contactant directement le restaurant :

#### **Avant commande (informations publiques) :**
- ✅ Ville (ex: "Alger")
- ✅ Zone approximative (ex: "Hydra")
- ✅ Distance (ex: "2.3 km")
- ✅ Position GPS décalée de **±500m**
- ✅ Nom masqué ("Restaurant à Alger")
- ❌ **PAS** d'adresse complète
- ❌ **PAS** de téléphone
- ❌ **PAS** de position GPS exacte

#### **Après commande confirmée (informations privées révélées) :**
- ✅ Nom complet du restaurant
- ✅ Adresse complète
- ✅ Téléphone
- ✅ Position GPS exacte

**Avantages :**
- 🔒 Protège le business model (impossible de contourner l'app)
- 💰 Garantit les commissions
- 📊 Force l'utilisation de la plateforme

---

### 3. **Gestion des vidéos**

#### **Contraintes :**
- ⏱️ Durée max : **30 secondes**
- 📹 Format : MP4, 1080p recommandé
- 📦 Stockage : **OVH Object Storage**
- ✅ Validation admin avant publication

#### **Slots par tier :**
- Les restaurants peuvent upload plusieurs vidéos
- Seulement **X vidéos actives** selon leur tier
- Les vidéos archivées ne comptent pas dans les slots
- Permet de changer régulièrement la vitrine

---

## 🏗️ Architecture

```
MAKLA-Backend/
├── src/
│   ├── restaurants/          # Gestion des restaurants
│   │   ├── restaurants.controller.ts
│   │   ├── restaurants.service.ts
│   │   ├── restaurants.module.ts
│   │   └── dto/
│   │       ├── create-restaurant.dto.ts
│   │       └── update-restaurant.dto.ts
│   │
│   ├── videos/               # Gestion des vidéos
│   │   ├── videos.controller.ts
│   │   ├── videos.service.ts
│   │   ├── videos.module.ts
│   │   └── dto/
│   │       ├── upload-video.dto.ts
│   │       └── archive-video.dto.ts
│   │
│   ├── orders/               # Gestion des commandes
│   │   ├── orders.controller.ts
│   │   ├── orders.service.ts
│   │   ├── orders.module.ts
│   │   └── dto/
│   │       └── create-order.dto.ts
│   │
│   ├── feed/                 # Feed de vidéos (TikTok-like)
│   │   ├── feed.controller.ts
│   │   ├── feed.service.ts
│   │   └── feed.module.ts
│   │
│   ├── auth/                 # Authentication
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   └── strategies/
│   │       └── jwt.strategy.ts
│   │
│   ├── storage/              # OVH Object Storage
│   │   ├── storage.service.ts
│   │   └── storage.module.ts
│   │
│   ├── notifications/        # Notifications (Tier up, etc.)
│   │   ├── notifications.service.ts
│   │   └── notifications.module.ts
│   │
│   ├── utils/                # Fonctions utilitaires
│   │   ├── tier.utils.ts
│   │   ├── gps.utils.ts
│   │   └── video.utils.ts
│   │
│   └── common/
│       ├── guards/
│       ├── decorators/
│       └── filters/
│
├── prisma/
│   ├── schema.prisma         # Schéma Prisma
│   ├── migrations/           # Migrations
│   └── seed.ts               # Données de test
│
├── .env.example              # Variables d'environnement
├── package.json
└── README.md
```

---

## 🗃️ Schéma de base de données

### **ENUMS**

```prisma
enum UserRole {
  CLIENT          // Utilisateur final
  RESTAURANT      // Propriétaire de restaurant
  ADMIN           // Administrateur plateforme
}

enum RestaurantTier {
  BRONZE          // 0-49 commandes → 1 slot vidéo
  SILVER          // 50-149 commandes → 2 slots
  GOLD            // 150-499 commandes → 3 slots
  DIAMOND         // 500-999 commandes → 5 slots
  LEGEND          // 1000+ commandes → 10 slots
}

enum VideoStatus {
  PENDING         // En attente de validation admin
  APPROVED        // Approuvée, visible dans le feed
  REJECTED        // Rejetée par l'admin
  ARCHIVED        // Archivée par le restaurant
}

enum OrderStatus {
  PENDING         // En attente de confirmation resto
  CONFIRMED       // Confirmée par le resto
  PREPARING       // En préparation
  READY           // Prêt (pour click & collect)
  IN_DELIVERY     // En livraison
  COMPLETED       // Terminée
  CANCELLED       // Annulée
}

enum OrderType {
  DELIVERY        // Livraison
  TAKEAWAY        // Click & Collect
  RESERVATION     // Réservation de table
}
```

---

### **MODELS**

#### **User**
```prisma
model User {
  id                String             @id @default(cuid())
  email             String             @unique
  password          String             // Hashé avec bcrypt
  role              UserRole           @default(CLIENT)

  // Profil client
  firstName         String?
  lastName          String?
  phone             String?

  // Relations
  restaurantProfile RestaurantProfile? // Si role = RESTAURANT
  clientOrders      Order[]            @relation("ClientOrders")

  createdAt         DateTime           @default(now())
  updatedAt         DateTime           @updatedAt

  @@index([email, role])
}
```

---

#### **RestaurantProfile**
```prisma
model RestaurantProfile {
  id               String          @id @default(cuid())
  userId           String          @unique
  user             User            @relation(fields: [userId], references: [id])

  // ========== INFORMATIONS PUBLIQUES (visibles par TOUS) ==========
  isAnonymous      Boolean         @default(true)   // Masquer identité
  city             String                            // Ex: "Alger"
  approximateArea  String?                           // Ex: "Hydra"
  publicLat        Float                             // GPS décalé (+/- 500m)
  publicLng        Float                             // GPS décalé (+/- 500m)

  cuisineType      String[]                          // Ex: ["Algérienne", "Fast-food"]
  bio              String?                           // Description publique
  profilePicture   String?                           // Avatar (si pas anonyme)

  // ========== INFORMATIONS PRIVÉES (visibles après COMMANDE) ==========
  restaurantName   String                            // Vrai nom du resto
  fullAddress      String                            // Adresse complète
  exactLat         Float                             // GPS exact
  exactLng         Float                             // GPS exact
  phone            String                            // Téléphone

  // ========== GAMIFICATION & STATS ==========
  tier             RestaurantTier  @default(BRONZE) // Tier actuel
  totalOrders      Int             @default(0)       // Commandes complétées
  rating           Float           @default(0)       // Note moyenne
  reviewCount      Int             @default(0)       // Nombre d'avis

  // ========== MENU & PRICING ==========
  hasDelivery      Boolean         @default(false)
  hasTakeaway      Boolean         @default(false)
  hasReservation   Boolean         @default(false)
  deliveryFee      Float?
  minOrderAmount   Float?

  // ========== RELATIONS ==========
  videos           Video[]
  orders           Order[]
  menu             MenuItem[]

  createdAt        DateTime        @default(now())
  updatedAt        DateTime        @updatedAt

  @@index([city, tier])
  @@index([isAnonymous])
}
```

---

#### **Video**
```prisma
model Video {
  id               String         @id @default(cuid())
  restaurantId     String
  restaurant       RestaurantProfile @relation(fields: [restaurantId], references: [id], onDelete: Cascade)

  videoUrl         String         // URL OVH Object Storage
  thumbnailUrl     String?        // Miniature générée automatiquement
  duration         Int            // Durée en secondes (max 30)

  status           VideoStatus    @default(PENDING)
  isActive         Boolean        @default(true)    // Active ou archivée

  // Stats
  views            Int            @default(0)
  likes            Int            @default(0)
  shares           Int            @default(0)

  // Metadata
  uploadedAt       DateTime       @default(now())
  approvedAt       DateTime?      // Date d'approbation par admin
  approvedBy       String?        // Admin qui a approuvé
  rejectionReason  String?        // Raison du rejet

  createdAt        DateTime       @default(now())
  updatedAt        DateTime       @updatedAt

  @@index([restaurantId, status, isActive])
  @@index([status, approvedAt])
}
```

---

#### **Order**
```prisma
model Order {
  id               String         @id @default(cuid())

  // Client
  clientId         String
  client           User           @relation("ClientOrders", fields: [clientId], references: [id])

  // Restaurant
  restaurantId     String
  restaurant       RestaurantProfile @relation(fields: [restaurantId], references: [id])

  // Type & Status
  type             OrderType
  status           OrderStatus    @default(PENDING)

  // Items
  items            OrderItem[]
  totalPrice       Float
  deliveryFee      Float?

  // Livraison
  deliveryAddress  String?
  deliveryLat      Float?
  deliveryLng      Float?
  deliveryNote     String?

  // Réservation
  reservationDate  DateTime?
  reservationTime  String?        // Ex: "19:30"
  partySize        Int?           // Nombre de personnes

  // Timing
  createdAt        DateTime       @default(now())
  confirmedAt      DateTime?      // Restaurant confirme
  completedAt      DateTime?      // Commande terminée (compte pour stats)
  cancelledAt      DateTime?

  // Notes
  clientNote       String?
  restaurantNote   String?

  @@index([clientId, status])
  @@index([restaurantId, status])
  @@index([completedAt])
}
```

---

#### **MenuItem** (Menu du restaurant)
```prisma
model MenuItem {
  id               String         @id @default(cuid())
  restaurantId     String
  restaurant       RestaurantProfile @relation(fields: [restaurantId], references: [id], onDelete: Cascade)

  name             String
  description      String?
  price            Float
  imageUrl         String?

  category         String         // Ex: "Entrées", "Plats", "Desserts"
  isAvailable      Boolean        @default(true)

  // Options (ex: taille, extras)
  options          Json?          // { "tailles": ["S", "M", "L"], "extras": ["Frites", "Salade"] }

  createdAt        DateTime       @default(now())
  updatedAt        DateTime       @updatedAt

  @@index([restaurantId, category, isAvailable])
}
```

---

#### **OrderItem** (Items dans une commande)
```prisma
model OrderItem {
  id               String         @id @default(cuid())
  orderId          String
  order            Order          @relation(fields: [orderId], references: [id], onDelete: Cascade)

  menuItemId       String
  name             String         // Nom du plat (snapshot au moment de la commande)
  price            Float          // Prix au moment de la commande
  quantity         Int

  options          Json?          // Options sélectionnées (ex: "Taille M")

  createdAt        DateTime       @default(now())

  @@index([orderId])
}
```

---

## 🏆 Système de gamification

### **Calcul du tier**

Le tier est recalculé automatiquement après chaque commande complétée.

```typescript
// src/utils/tier.utils.ts

export function calculateTier(totalOrders: number): RestaurantTier {
  if (totalOrders >= 1000) return RestaurantTier.LEGEND;
  if (totalOrders >= 500) return RestaurantTier.DIAMOND;
  if (totalOrders >= 150) return RestaurantTier.GOLD;
  if (totalOrders >= 50) return RestaurantTier.SILVER;
  return RestaurantTier.BRONZE;
}

export function getMaxVideoSlots(tier: RestaurantTier): number {
  const slots = {
    BRONZE: 1,
    SILVER: 2,
    GOLD: 3,
    DIAMOND: 5,
    LEGEND: 10,
  };
  return slots[tier];
}

export function getVisibilityBoost(tier: RestaurantTier): number {
  const boosts = {
    BRONZE: 1.0,    // Aucun boost
    SILVER: 1.1,    // +10%
    GOLD: 1.2,      // +20%
    DIAMOND: 1.3,   // +30%
    LEGEND: 1.5,    // +50%
  };
  return boosts[tier];
}

export function getTierBadge(tier: RestaurantTier): string {
  const badges = {
    BRONZE: '🥉 Nouveau',
    SILVER: '🥈 Populaire',
    GOLD: '🥇 Top Resto',
    DIAMOND: '💎 Elite',
    LEGEND: '👑 Légende',
  };
  return badges[tier];
}

export function getNextTierInfo(totalOrders: number) {
  const thresholds = [
    { tier: 'SILVER', orders: 50 },
    { tier: 'GOLD', orders: 150 },
    { tier: 'DIAMOND', orders: 500 },
    { tier: 'LEGEND', orders: 1000 },
  ];

  for (const threshold of thresholds) {
    if (totalOrders < threshold.orders) {
      return {
        nextTier: threshold.tier,
        ordersNeeded: threshold.orders - totalOrders,
        progress: (totalOrders / threshold.orders) * 100,
      };
    }
  }

  return null; // Déjà LEGEND
}
```

---

### **Mise à jour automatique du tier**

```typescript
// src/orders/orders.service.ts

async completeOrder(orderId: string) {
  // 1. Marquer la commande comme complétée
  const order = await this.prisma.order.update({
    where: { id: orderId },
    data: {
      status: OrderStatus.COMPLETED,
      completedAt: new Date(),
    },
  });

  // 2. Incrémenter le compteur de commandes du resto
  const restaurant = await this.prisma.restaurantProfile.update({
    where: { id: order.restaurantId },
    data: {
      totalOrders: { increment: 1 },
    },
  });

  // 3. Recalculer le tier
  const newTier = calculateTier(restaurant.totalOrders);

  if (newTier !== restaurant.tier) {
    // 🎉 TIER UP ! Envoyer une notification
    await this.prisma.restaurantProfile.update({
      where: { id: restaurant.id },
      data: { tier: newTier },
    });

    await this.notificationService.sendTierUpNotification(
      restaurant.userId,
      newTier,
      getMaxVideoSlots(newTier),
    );
  }

  return order;
}
```

---

## 🔒 Système d'anonymat

### **Décalage GPS (±500m)**

```typescript
// src/utils/gps.utils.ts

/**
 * Décale une position GPS de manière aléatoire dans un rayon donné
 * @param lat Latitude exacte
 * @param lng Longitude exacte
 * @param radiusMeters Rayon de décalage (500m recommandé)
 * @returns Position GPS décalée
 */
export function obfuscateGPS(
  lat: number,
  lng: number,
  radiusMeters: number = 500,
): { lat: number; lng: number } {
  // 1 degré de latitude ≈ 111km
  // 1 degré de longitude ≈ 111km * cos(latitude)

  const radiusInDegrees = radiusMeters / 111000;

  // Angle aléatoire
  const angle = Math.random() * 2 * Math.PI;

  // Distance aléatoire (0 à radius)
  const distance = Math.random() * radiusInDegrees;

  // Calcul du décalage
  const deltaLat = distance * Math.cos(angle);
  const deltaLng = distance * Math.sin(angle) / Math.cos(lat * Math.PI / 180);

  return {
    lat: lat + deltaLat,
    lng: lng + deltaLng,
  };
}

/**
 * Calcule la distance entre 2 points GPS (formule de Haversine)
 */
export function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371; // Rayon de la Terre en km

  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) *
    Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance en km
}
```

---

### **Endpoints avec masquage**

#### **GET /restaurants/:id (AVANT commande)**

```typescript
// src/restaurants/restaurants.controller.ts

@Get(':id')
async getRestaurantPublic(
  @Param('id') id: string,
  @Query('userLat') userLat?: number,
  @Query('userLng') userLng?: number,
) {
  const restaurant = await this.restaurantsService.findOne(id);

  // Calcul de la distance
  let distance: number | null = null;
  if (userLat && userLng) {
    distance = calculateDistance(
      userLat,
      userLng,
      restaurant.publicLat,
      restaurant.publicLng,
    );
  }

  return {
    id: restaurant.id,

    // ========== Nom masqué ou non selon isAnonymous ==========
    name: restaurant.isAnonymous
      ? `Restaurant à ${restaurant.city}`
      : restaurant.restaurantName,

    // ========== Informations publiques ==========
    city: restaurant.city,
    approximateArea: restaurant.approximateArea,
    cuisineType: restaurant.cuisineType,
    bio: restaurant.bio,
    profilePicture: restaurant.isAnonymous ? null : restaurant.profilePicture,

    // ========== Position DÉCALÉE ==========
    location: {
      lat: restaurant.publicLat,    // +/- 500m
      lng: restaurant.publicLng,    // +/- 500m
      radius: 500,                  // Cercle de 500m
    },
    distance: distance ? parseFloat(distance.toFixed(1)) : null,

    // ========== Gamification ==========
    tier: restaurant.tier,
    badge: getTierBadge(restaurant.tier),
    rating: restaurant.rating,
    reviewCount: restaurant.reviewCount,

    // ========== Services ==========
    hasDelivery: restaurant.hasDelivery,
    hasTakeaway: restaurant.hasTakeaway,
    hasReservation: restaurant.hasReservation,

    // ❌ PAS de fullAddress
    // ❌ PAS de exactLat/exactLng
    // ❌ PAS de phone
    // ❌ PAS de restaurantName (si anonyme)
  };
}
```

---

#### **GET /orders/:id (APRÈS commande confirmée)**

```typescript
@Get(':id')
@UseGuards(JwtAuthGuard)
async getOrderDetails(
  @Param('id') orderId: string,
  @CurrentUser() user: User,
) {
  const order = await this.ordersService.findOne(orderId);

  // Vérifier que c'est bien le client de la commande
  if (order.clientId !== user.id) {
    throw new ForbiddenException('Vous ne pouvez pas voir cette commande');
  }

  return {
    ...order,
    restaurant: {
      // ⭐ RÉVÉLATION COMPLÈTE des informations
      name: order.restaurant.restaurantName,
      fullAddress: order.restaurant.fullAddress,
      phone: order.restaurant.phone,
      location: {
        lat: order.restaurant.exactLat,    // ✅ Position exacte
        lng: order.restaurant.exactLng,    // ✅ Position exacte
      },
    },
  };
}
```

---

## 🎥 Gestion des vidéos

### **Upload d'une vidéo**

```typescript
// src/videos/videos.service.ts

async uploadVideo(
  restaurantId: string,
  videoFile: Express.Multer.File,
): Promise<Video> {
  // 1. Récupérer le restaurant et ses vidéos actives
  const restaurant = await this.prisma.restaurantProfile.findUnique({
    where: { id: restaurantId },
    include: {
      videos: {
        where: {
          status: { in: ['PENDING', 'APPROVED'] },
          isActive: true,
        },
      },
    },
  });

  // 2. Vérifier le nombre de slots max
  const maxSlots = getMaxVideoSlots(restaurant.tier);
  const currentSlots = restaurant.videos.length;

  if (currentSlots >= maxSlots) {
    throw new BadRequestException(
      `Vous avez atteint la limite de ${maxSlots} vidéo(s) pour votre tier ${restaurant.tier}. ` +
      `Archivez une vidéo ou attendez de débloquer plus de slots !`
    );
  }

  // 3. Vérifier la durée de la vidéo
  const duration = await this.getVideoDuration(videoFile);
  if (duration > 30) {
    throw new BadRequestException('La vidéo ne doit pas dépasser 30 secondes');
  }

  // 4. Upload sur OVH Object Storage
  const videoUrl = await this.storageService.uploadFile(
    videoFile,
    `restaurants/${restaurantId}/videos`,
  );

  // 5. Générer une miniature
  const thumbnailUrl = await this.generateThumbnail(videoFile, restaurantId);

  // 6. Créer la vidéo en base
  const video = await this.prisma.video.create({
    data: {
      restaurantId,
      videoUrl,
      thumbnailUrl,
      duration,
      status: VideoStatus.PENDING,  // Validation admin requise
      isActive: true,
    },
  });

  return video;
}
```

---

### **Archiver une vidéo (libérer un slot)**

```typescript
async archiveVideo(restaurantId: string, videoId: string): Promise<void> {
  const video = await this.prisma.video.findFirst({
    where: { id: videoId, restaurantId },
  });

  if (!video) {
    throw new NotFoundException('Vidéo non trouvée');
  }

  await this.prisma.video.update({
    where: { id: videoId },
    data: {
      isActive: false,
      status: VideoStatus.ARCHIVED,
    },
  });
}
```

---

### **Feed de vidéos (TikTok-like)**

```typescript
// src/feed/feed.service.ts

async getFeed(
  page: number = 1,
  limit: number = 20,
  userLat?: number,
  userLng?: number,
  cuisineType?: string,
): Promise<Video[]> {
  const skip = (page - 1) * limit;

  // Récupérer les vidéos approuvées et actives
  const videos = await this.prisma.video.findMany({
    where: {
      status: VideoStatus.APPROVED,
      isActive: true,
      ...(cuisineType && {
        restaurant: {
          cuisineType: { has: cuisineType },
        },
      }),
    },
    include: {
      restaurant: true,
    },
    skip,
    take: limit,
    orderBy: {
      // Algorithme de tri : mélange de popularité et de tier
      // Peut être amélioré avec un algorithme de recommendation
      views: 'desc',
    },
  });

  // Appliquer le boost de visibilité selon le tier
  const weightedVideos = videos.map(video => ({
    ...video,
    weight: video.views * getVisibilityBoost(video.restaurant.tier),
  }));

  // Trier par weight
  weightedVideos.sort((a, b) => b.weight - a.weight);

  // Calculer la distance si position fournie
  if (userLat && userLng) {
    return weightedVideos.map(video => ({
      ...video,
      distance: calculateDistance(
        userLat,
        userLng,
        video.restaurant.publicLat,
        video.restaurant.publicLng,
      ),
    }));
  }

  return weightedVideos;
}
```

---

## 📡 API Endpoints

### **Authentication**

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/auth/register` | Inscription (client ou restaurant) | - |
| POST | `/auth/login` | Connexion | - |
| POST | `/auth/refresh` | Rafraîchir le token | - |
| GET | `/auth/me` | Profil utilisateur | JWT |

---

### **Restaurants**

| Method | Endpoint | Description | Auth | Données révélées |
|--------|----------|-------------|------|------------------|
| GET | `/restaurants` | Liste des restaurants | - | Publiques uniquement |
| GET | `/restaurants/:id` | Détails d'un restaurant | - | Publiques uniquement |
| POST | `/restaurants` | Créer un profil restaurant | JWT (Restaurant) | - |
| PATCH | `/restaurants/:id` | Modifier le profil | JWT (Restaurant) | - |
| GET | `/restaurants/:id/stats` | Stats du restaurant | JWT (Restaurant) | Complètes |

---

### **Vidéos**

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/videos/upload` | Upload une vidéo | JWT (Restaurant) |
| GET | `/videos/:id` | Détails d'une vidéo | - |
| PATCH | `/videos/:id/archive` | Archiver une vidéo | JWT (Restaurant) |
| DELETE | `/videos/:id` | Supprimer une vidéo | JWT (Restaurant) |
| POST | `/videos/:id/like` | Liker une vidéo | JWT |
| POST | `/videos/:id/view` | Incrémenter les vues | - |

---

### **Feed**

| Method | Endpoint | Description | Auth | Query params |
|--------|----------|-------------|------|--------------|
| GET | `/feed` | Feed de vidéos | - | `page`, `limit`, `lat`, `lng`, `cuisineType` |
| GET | `/feed/nearby` | Vidéos à proximité | - | `lat`, `lng`, `radius` |
| GET | `/feed/trending` | Vidéos tendances | - | - |

---

### **Orders**

| Method | Endpoint | Description | Auth | Données révélées |
|--------|----------|-------------|------|------------------|
| POST | `/orders` | Créer une commande | JWT | - |
| GET | `/orders/:id` | Détails commande | JWT | **Privées révélées** |
| PATCH | `/orders/:id/confirm` | Confirmer (restaurant) | JWT (Restaurant) | - |
| PATCH | `/orders/:id/complete` | Marquer complétée | JWT (Restaurant) | - |
| PATCH | `/orders/:id/cancel` | Annuler | JWT | - |
| GET | `/orders/me` | Mes commandes (client) | JWT | - |
| GET | `/orders/restaurant/:id` | Commandes du resto | JWT (Restaurant) | - |

---

### **Admin**

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/admin/videos/pending` | Vidéos en attente | JWT (Admin) |
| PATCH | `/admin/videos/:id/approve` | Approuver une vidéo | JWT (Admin) |
| PATCH | `/admin/videos/:id/reject` | Rejeter une vidéo | JWT (Admin) |
| GET | `/admin/restaurants` | Liste restaurants | JWT (Admin) |
| GET | `/admin/stats` | Stats globales | JWT (Admin) |

---

## 🛡️ Sécurité

### **1. Authentication JWT**

```typescript
// src/auth/strategies/jwt.strategy.ts

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  async validate(payload: any) {
    return {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
    };
  }
}
```

---

### **2. Guards**

```typescript
// src/common/guards/roles.guard.ts

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.includes(user.role);
  }
}

// Usage:
// @Roles(UserRole.RESTAURANT)
// @UseGuards(JwtAuthGuard, RolesGuard)
```

---

### **3. Rate Limiting**

```typescript
// src/main.ts

import rateLimit from 'express-rate-limit';

app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Max 100 requêtes par IP
  }),
);
```

---

### **4. Validation (class-validator)**

```typescript
// src/videos/dto/upload-video.dto.ts

import { IsNotEmpty, IsOptional, MaxLength } from 'class-validator';

export class UploadVideoDto {
  @IsNotEmpty()
  restaurantId: string;

  @IsOptional()
  @MaxLength(200)
  description?: string;
}
```

---

## 🚀 Déploiement

### **Variables d'environnement (.env)**

```bash
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/makla"

# JWT
JWT_SECRET="your-super-secret-key"
JWT_EXPIRES_IN="7d"

# OVH Object Storage
OVH_ENDPOINT="https://s3.rbx.io.cloud.ovh.net"
OVH_REGION="rbx"
OVH_ACCESS_KEY="your-access-key"
OVH_SECRET_KEY="your-secret-key"
OVH_BUCKET_NAME="makla-videos"

# Frontend URL (CORS)
FRONTEND_URL="https://makla.dz"

# Notifications (optionnel)
FIREBASE_PROJECT_ID="makla-app"
FIREBASE_PRIVATE_KEY="..."
```

---

### **Scripts npm**

```json
{
  "scripts": {
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:prod": "node dist/main",
    "build": "nest build",
    "prisma:migrate": "prisma migrate dev",
    "prisma:generate": "prisma generate",
    "prisma:seed": "ts-node prisma/seed.ts"
  }
}
```

---

### **Docker**

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build
RUN npx prisma generate

EXPOSE 3000

CMD ["npm", "run", "start:prod"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: makla
      POSTGRES_USER: makla
      POSTGRES_PASSWORD: makla123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build: .
    ports:
      - "3000:3000"
    depends_on:
      - postgres
    environment:
      DATABASE_URL: postgresql://makla:makla123@postgres:5432/makla
      JWT_SECRET: super-secret-key
    volumes:
      - ./src:/app/src

volumes:
  postgres_data:
```

---

## 📊 Estimation des coûts (OVH)

### **Stockage vidéos**

| Scénario | Restos | Vidéos totales | Stockage | Coût/mois |
|----------|--------|----------------|----------|-----------|
| Sans gamification | 1000 | 10,000 | 250 GB | 2.50€ |
| Avec gamification | 1000 | 1,508 | 37.7 GB | **0.38€** |

**Économie : 85% 🎉**

---

## 🎯 Roadmap

### **Phase 1 : MVP** ✅
- [x] Schéma Prisma complet
- [x] Système de tiers
- [x] Système d'anonymat
- [x] Upload vidéos
- [x] Feed basique

### **Phase 2 : Gamification** 🚧
- [ ] Dashboard restaurateur avec progression
- [ ] Notifications tier up
- [ ] Badges visibles sur les profils
- [ ] Boost de visibilité dans le feed

### **Phase 3 : Social** 📅
- [ ] Likes & partages
- [ ] Commentaires
- [ ] Stories éphémères
- [ ] Live streaming (restaurants)

### **Phase 4 : Intelligence** 🔮
- [ ] Algorithme de recommendation (ML)
- [ ] Filtres intelligents (préférences utilisateur)
- [ ] Détection automatique de contenu inapproprié
- [ ] Génération automatique de miniatures

---

## 📚 Ressources

- [Documentation NestJS](https://docs.nestjs.com/)
- [Documentation Prisma](https://www.prisma.io/docs)
- [OVH Object Storage](https://www.ovhcloud.com/fr/public-cloud/object-storage/)
- [PostgreSQL](https://www.postgresql.org/docs/)

---

## 👥 Contribution

Pour toute question ou suggestion, contactez l'équipe backend.

---

**Dernière mise à jour :** 2026-02-10
**Version :** 1.0.0
**Auteur :** Équipe MAKLA
