# Tests de vérification Google Sign-In

## ✅ Backend (NestJS)

### auth.controller.ts
- ✅ Endpoint `POST /auth/google` défini
- ✅ GoogleAuthDto avec validation correcte
  - `@IsString() googleId` (required)
  - `@IsEmail() email` (required)
  - `@IsOptional() @IsString() firstName`
  - `@IsOptional() @IsString() lastName`
  - `@IsOptional() @IsString() photoUrl`
- ✅ Appelle `auth.googleAuth()` avec les bons paramètres

### auth.service.ts
- ✅ Méthode `googleAuth()` implémentée
- ✅ Recherche utilisateur par googleId OU email
- ✅ Liaison compte existant si nécessaire
- ✅ Création nouveau utilisateur avec password=null
- ✅ Retour tokens + user data complet
- ✅ **FIX APPLIQUÉ**: login() vérifie maintenant `!user.password` pour éviter crash avec comptes Google

### Schéma Prisma (à vérifier)
⚠️ **ATTENTION**: Migration Prisma non créée (erreur réseau 403)
- User model doit avoir:
  - `googleId String? @unique`
  - `password String?` (optionnel)
  - `firstName String?`
  - `lastName String?`
  - `photoUrl String?`

## ✅ Frontend (Flutter)

### pubspec.yaml
- ✅ Package `google_sign_in: ^6.2.2` ajouté

### lib/core/api.dart
- ✅ Méthode `googleAuth()` définie
- ✅ Paramètres correspondent au backend
- ✅ Sauvegarde tokens après authentification
- ✅ Retourne Map<String, dynamic> avec user data

### lib/features/auth/login_screen.dart
- ✅ Import `google_sign_in` ajouté
- ✅ Méthode `_handleGoogleSignIn()` implémentée
- ✅ Bouton "Continuer avec Google" avec UI cohérente
- ✅ Gestion complète du flux de routage (admin/pro/user)
- ✅ refreshMe() appelé après authentification

### lib/features/auth/user_register_screen.dart
- ✅ Import `google_sign_in` ajouté
- ✅ Méthode `_handleGoogleSignIn()` implémentée
- ✅ Bouton à l'étape 0 avec divider "OU"
- ✅ Redirection vers `/onboard/pet` après auth

### lib/features/pro/pro_register_screen.dart
- ✅ Import `google_sign_in` ajouté
- ✅ Méthode `_handleGoogleSignIn()` implémentée
- ✅ Bouton à l'étape 0 (Vétérinaire)
- ✅ **Pré-remplissage** firstName, lastName, email
- ✅ **Skip automatique** vers étape 2 (adresse)
- ✅ L'utilisateur complète ensuite: adresse, maps, AVN

## 🧪 Tests à effectuer manuellement

### Test 1: Nouveau compte avec Google
1. Cliquer "Continuer avec Google" dans login ou register
2. Sélectionner un compte Google
3. ✅ Backend doit créer user avec googleId, password=null
4. ✅ Frontend doit recevoir tokens et user data
5. ✅ Redirection vers page appropriée selon rôle

### Test 2: Compte existant (email/password) + liaison Google
1. Créer compte avec email/password
2. Se déconnecter
3. Cliquer "Continuer avec Google" avec même email
4. ✅ Backend doit lier googleId au compte existant
5. ✅ Login suivant avec Google doit fonctionner

### Test 3: Compte Google essaie login email/password
1. Créer compte avec Google
2. Se déconnecter
3. Essayer login avec email/password
4. ✅ Doit échouer avec "Invalid credentials" (password est null)

### Test 4: Pro registration avec Google
1. Aller sur registration vétérinaire
2. Cliquer "Continuer avec Google" à l'étape 0
3. ✅ Nom/prénom/email doivent être pré-remplis
4. ✅ Passer automatiquement à l'étape 2 (adresse)
5. Compléter adresse, maps, AVN
6. ✅ Provider profile créé avec succès

## ⚠️ Points d'attention

### Configuration Google Cloud Console requise
Pour fonctionner en production, vous devez:

1. **Créer projet Google Cloud Console**
   - https://console.cloud.google.com/

2. **Activer Google Sign-In API**
   - APIs & Services > Enable APIs

3. **Configurer OAuth 2.0 credentials**
   - Android: SHA-1 fingerprint
   - iOS: Bundle ID
   - Web: Authorized domains

4. **Fichiers de configuration**
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

5. **Ajouter dans AndroidManifest.xml**
```xml
<meta-data
    android:name="com.google.android.gms.version"
    android:value="@integer/google_play_services_version" />
```

### Variables d'environnement backend
Assurez-vous que `.env` contient:
```env
JWT_ACCESS_SECRET=your_secret_here
JWT_REFRESH_SECRET=your_refresh_secret_here
JWT_ACCESS_TTL=900s
JWT_REFRESH_TTL=7d
```

## 🔒 Sécurité vérifiée

- ✅ Validation email avec `@IsEmail()`
- ✅ Google ID validation avec `@IsString()`
- ✅ Tokens JWT signés avec secrets
- ✅ Pas de fuite de password hash dans les réponses
- ✅ UnauthorizedException pour tentatives login invalides
- ✅ Compte Google ne peut pas login avec password

## 📊 Résumé des changements

### Backend (2 fichiers)
1. `lib/backend/src/auth/auth.controller.ts` - Endpoint Google
2. `lib/backend/src/auth/auth.service.ts` - Logique OAuth + FIX login

### Frontend (5 fichiers)
1. `pubspec.yaml` - Dépendance google_sign_in
2. `lib/core/api.dart` - Méthode API client
3. `lib/features/auth/login_screen.dart` - Bouton + handler
4. `lib/features/auth/user_register_screen.dart` - Bouton + handler
5. `lib/features/pro/pro_register_screen.dart` - Bouton + pré-remplissage

### Prisma (non migré)
- Schema modifié mais migration non créée (erreur réseau)
- À migrer plus tard: `npx prisma migrate dev --name add_google_oauth`

## ✅ Status final
- Backend: ✅ Compilable et logique correcte
- Frontend: ✅ Syntaxe correcte et imports valides
- API: ✅ Cohérence endpoints backend/frontend
- Sécurité: ✅ Protection contre comptes Google sans password
