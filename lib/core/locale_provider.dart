import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// THÈME (CLAIR / SOMBRE)
// ═══════════════════════════════════════════════════════════════

enum AppThemeMode {
  light('light', 'Clair', Icons.light_mode),
  dark('dark', 'Sombre', Icons.dark_mode);

  final String code;
  final String name;
  final IconData icon;

  const AppThemeMode(this.code, this.name, this.icon);

  static AppThemeMode fromCode(String code) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.code == code,
      orElse: () => AppThemeMode.light,
    );
  }
}

// Provider pour le thème
final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<AppThemeMode> {
  static const String _key = 'app_theme';

  @override
  AppThemeMode build() {
    _loadSavedTheme();
    return AppThemeMode.light;
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      state = AppThemeMode.fromCode(code);
    }
  }

  Future<void> setTheme(AppThemeMode theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.code);
  }

  void toggleTheme() {
    setTheme(state == AppThemeMode.light ? AppThemeMode.dark : AppThemeMode.light);
  }

  bool get isDark => state == AppThemeMode.dark;
}

// ═══════════════════════════════════════════════════════════════
// LANGUES SUPPORTÉES
// ═══════════════════════════════════════════════════════════════

// Langues supportées
enum AppLanguage {
  french('fr', 'Français', '🇫🇷'),
  english('en', 'English', '🇬🇧'),
  arabic('ar', 'العربية', '🇩🇿');

  final String code;
  final String name;
  final String flag;

  const AppLanguage(this.code, this.name, this.flag);

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.french,
    );
  }
}

// Provider pour la locale
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  static const String _key = 'app_locale';

  @override
  Locale build() {
    _loadSavedLocale();
    return const Locale('fr');
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(AppLanguage language) async {
    state = language.locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }

  AppLanguage get currentLanguage {
    return AppLanguage.fromCode(state.languageCode);
  }
}

// ═══════════════════════════════════════════════════════════════
// SYSTÈME DE TRADUCTION MANUEL
// ═══════════════════════════════════════════════════════════════

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('fr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
  ];

  // Traductions
  static final Map<String, Map<String, String>> _translations = {
    'fr': {
      'appName': 'Vegece',
      'youAre': 'Vous êtes',
      'individual': 'Particulier',
      'professional': 'Professionnel',
      'termsOfUse': 'Conditions d\'utilisation',
      'language': 'Langue',
      'login': 'Se connecter',
      'emailOrPhone': 'Email / numéro de téléphone',
      'password': 'Mot de passe',
      'forgotPassword': 'Mot de passe oublié ?',
      'confirm': 'Confirmer',
      'or': 'OU',
      'continueWithGoogle': 'Continuer avec Google',
      'noAccount': 'Pas de compte ?',
      'signUp': 'S\'inscrire',
      'createAccount': 'Créer un compte',
      'firstName': 'Prénom',
      'lastName': 'Nom',
      'email': 'Adresse email',
      'phone': 'Téléphone',
      'confirmPassword': 'Confirmer le mot de passe',
      'next': 'Suivant',
      'previous': 'Précédent',
      'skip': 'Ignorer',
      'finish': 'Terminer',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'close': 'Fermer',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'errorInvalidEmail': 'Entrez un email (ou numéro) valide',
      'errorPasswordRequired': 'Mot de passe requis',
      'errorIncorrectCredentials': 'Email ou mot de passe incorrect.',
      'errorFixFields': 'Veuillez corriger les champs en rouge.',
      'errorFirstNameRequired': 'Prénom requis',
      'errorFirstNameMin': 'Prénom: minimum 3 caractères',
      'errorFirstNameMax': 'Prénom: maximum 15 caractères',
      'errorLastNameRequired': 'Nom requis',
      'errorLastNameMin': 'Nom: minimum 3 caractères',
      'errorLastNameMax': 'Nom: maximum 15 caractères',
      'errorEmailInvalid': 'Email invalide',
      'errorPasswordWeak': 'Mot de passe trop faible',
      'errorPasswordMismatch': 'Les mots de passe ne correspondent pas',
      'errorConfirmRequired': 'Confirmation requise',
      'errorPhoneRequired': 'Téléphone requis',
      'errorPhoneFormat': 'Le numéro doit commencer par 05, 06 ou 07',
      'errorPhoneLength': 'Le numéro doit contenir 10 chiffres',
      'errorEmailTaken': 'Email déjà utilisé',
      'errorPhoneTaken': 'Téléphone déjà utilisé',
      'passwordHelper': 'Min. 8 caractères, avec MAJUSCULE et minuscule',
      'emailVerificationNote': 'Nous vérifions l\'email et créons le compte à cette étape.',
      'profilePhotoOptional': 'Photo de profil (optionnel)',
      'choosePhoto': 'Choisir une photo',
      'removePhoto': 'Retirer',
      'skipPhotoNote': 'Vous pouvez ignorer cette étape et ajouter une photo plus tard.',
      'proAccountDetected': 'Compte pro détecté',
      'proAccountMessage': 'Ce compte est configuré pour l\'espace professionnel.\nVoulez-vous passer à la connexion Pro ?',
      'goToPro': 'Aller vers Pro',
      'clientAccountDetected': 'Compte client détecté',
      'clientAccountMessage': 'Ce compte n\'a pas encore de profil professionnel.\nSouhaitez-vous vous connecter côté Particulier, ou créer votre compte Pro ?',
      'goToIndividual': 'Aller vers Particulier',
      'createProAccount': 'Créer un compte Pro',
      'home': 'Accueil',
      'myPets': 'Mes animaux',
      'bookings': 'Rendez-vous',
      'profile': 'Profil',
      'settings': 'Paramètres',
      'logout': 'Déconnexion',
      'animalWellbeing': 'Le bien-être animal',
      'takeCareOfCompanion': 'Prenez soin de\nvotre compagnon',
      'welcomeToVegece': 'Bienvenue\nsur Vegece',
      'petsDeserveBest': 'Vos animaux méritent le meilleur !',
      'yourCareMakesDifference': 'Parce que vos soins font toute la différence',
      'signInWithGoogle': 'Se connecter avec Google',
      'errorGoogleSignIn': 'Erreur lors de la connexion Google',
      'errorProfileRetrieval': 'Erreur lors de la récupération du profil',
      'veterinarian': 'Vétérinaire',
      'daycare': 'Garderie',
      'petshop': 'Animalerie',
      'vetDescription': 'Clinique vétérinaire et soins pour animaux',
      'daycareDescription': 'Garde et pension pour vos compagnons',
      'petshopDescription': 'Boutique d\'accessoires et alimentation',
      'chooseCategory': 'Choisissez votre catégorie',
      'proAccountNote': 'Votre demande sera examinée sous 24-48h',
      'address': 'Adresse',
      'googleMapsUrl': 'Lien Google Maps',
      'shopName': 'Nom de l\'établissement',
      'avnCard': 'Carte AVN (Autorisation Vétérinaire)',
      'front': 'Recto',
      'back': 'Verso',
      'daycarePhotos': 'Photos de l\'établissement',
      'addPhoto': 'Ajouter une photo',
      'submit': 'Soumettre',
      'errorAddressRequired': 'Adresse requise',
      'errorMapsUrlRequired': 'Lien Google Maps invalide',
      'errorAvnRequired': 'Les deux faces de la carte AVN sont requises',
      'errorShopNameRequired': 'Nom de l\'établissement requis',
      'errorPhotoRequired': 'Au moins une photo requise',
      'errorConnection': 'Erreur de connexion',
      'services': 'Services',
      'veterinarians': 'Vétérinaires',
      'shop': 'Boutique',
      'daycares': 'Garderies',
      'howIsYourCompanion': 'Comment va votre compagnon ?',
      'myAnimals': 'Mes animaux',
      'healthRecordQr': 'Carnet de santé & QR code vétérinaire',
      'nearbyProfessionals': 'Professionnels à proximité',
      'adoptChangeLife': 'Adoptez, changez une vie',
      'boostCareer': 'Boostez votre carrière',
      'vethub': 'Vethub',
      'personalInfo': 'Informations personnelles',
      'deliveryAddress': 'Adresse de livraison',
      'deliveryAddressHint': 'Cette adresse sera utilisée par défaut lors de vos commandes',
      'quickAccess': 'Accès rapides',
      'myAppointments': 'Mes rendez-vous',
      'manageMyPets': 'Gérer mes animaux de compagnie',
      'viewAllAppointments': 'Voir tous mes rendez-vous',
      'support': 'Support',
      'needHelp': 'Besoin d\'aide ?',
      'comingSoon': 'Bientôt disponible',
      'myProfile': 'Mon Profil',
      'notProvided': 'Non renseigné',
      'phoneUpdated': 'Téléphone mis à jour',
      'photoUpdated': 'Photo mise à jour',
      'addressUpdated': 'Adresse mise à jour',
      'phoneRequired': 'Numéro de téléphone requis',
      'emailCannotBeChanged': 'L\'email ne peut pas être modifié',
      'confirmLogoutMessage': 'Voulez-vous vraiment vous déconnecter ?',
      'unableToLogout': 'Impossible de se déconnecter',
      'appearance': 'Apparence',
      'theme': 'Thème',
      'lightMode': 'Mode clair',
      'darkMode': 'Mode sombre',
      'addressHint': 'Numéro, rue, quartier, wilaya...',
      'findVetNearby': 'Trouvez un vétérinaire proche',
      'searchVet': 'Rechercher un vétérinaire...',
      'noVetFound': 'Aucun vétérinaire trouvé',
      'tryOtherTerms': 'Essayez avec d\'autres termes',
      'noVetAvailable': 'Aucun vétérinaire disponible pour le moment',
      'clearSearch': 'Effacer la recherche',
      'viewProfile': 'Voir profil',
      'kmAway': 'km',
      'openNow': 'Ouvert',
      'closedNow': 'Fermé',
      'opensAt': 'Ouvre à',
      'closesAt': 'Ferme à',
      // Home screen - Adoption & Carrière
      'adopt': 'Adoptez',
      'changeALife': 'Changez une vie',
      'boost': 'Boostez',
      'yourCareer': 'Votre carrière',
      // Adopt screens
      'adoptDiscussions': 'Discussions',
      'adoptAdopter': 'Adopter',
      'adoptCreate': 'Créer',
      'adoptHeader': 'Adopt',
      'adoptSearching': 'Recherche d\'animaux...',
      'adoptNoAds': 'Aucune annonce disponible',
      'adoptErrorLoading': 'Erreur chargement',
      'adoptNoAdsTitle': 'Aucune annonce',
      'adoptNoAdsDesc': 'Il n\'y a pas d\'animaux à adopter\npour le moment. Revenez plus tard !',
      'adoptRefresh': 'Actualiser',
      'adoptDog': 'Chien',
      'adoptCat': 'Chat',
      'adoptRabbit': 'Lapin',
      'adoptBird': 'Oiseau',
      'adoptOther': 'Autre',
      'adoptMale': 'Mâle',
      'adoptFemale': 'Femelle',
      'adoptUnknown': 'Inconnu',
      'adoptMonths': 'mois',
      'adoptYear': 'an',
      'adoptYears': 'ans',
      'adoptNope': 'NOPE',
      'adoptLike': 'LIKE',
      'adoptAdopted': 'ADOPTÉ',
      'adoptRequestSent': '❤️ Demande envoyée',
      'adoptPassed': 'Passé',
      'adoptOwnPost': '❌ Cette annonce vous appartient',
      'adoptQuotaReached': '⏳ Quota atteint : 5 likes maximum par jour',
      'adoptQuotaReachedToday': '⏳ Quota atteint pour aujourd\'hui',
      'adoptInvalidRequest': '⚠️ Requête invalide. Veuillez réessayer',
      'adoptTooManyRequests': '⏳ Trop de requêtes. Patientez un moment',
      'adoptServerUnavailable': '🔧 Serveur temporairement indisponible',
      'adoptMessages': 'Messages',
      'adoptNew': 'nouvelle',
      'adoptNews': 'nouvelles',
      'adoptNewRequests': 'Nouvelles demandes',
      'adoptConversations': 'Conversations',
      'adoptRequestAccepted': 'Demande acceptée',
      'adoptRequestRejected': 'Demande refusée',
      'adoptConversationDeleted': 'Conversation supprimée',
      'adoptError': 'Erreur',
      'adoptNewBadge': 'NEW',
      'adoptDelete': 'Supprimer',
      'adoptNoMessages': 'Aucun message',
      'adoptNoMessagesDesc': 'Vos demandes et conversations\napparaîtront ici',
      'adoptLoadingError': 'Erreur de chargement',
      'adoptRetry': 'Réessayer',
      'adoptJustNow': 'À l\'instant',
      'adoptMinutes': 'min',
      'adoptHours': 'h',
      'adoptDays': 'j',
      'adoptReadyToFinalize': 'Prêt à finaliser ?',
      'adoptProposeAdoptionTo': 'Proposez l\'adoption à',
      'adoptPropose': 'Proposer',
      'adoptWaitingForAdopter': 'En attente de confirmation de l\'adoptant...',
      'adoptAdoptionProposalWaiting': 'Une proposition d\'adoption vous attend !',
      'adoptAdoptionConfirmed': 'Adoption confirmée !',
      'adoptNoMessagesInChat': 'Aucun message',
      'adoptStartConversation': 'Commencez la conversation !',
      'adoptYourMessage': 'Votre message...',
      'adoptProposeAdoptionTitle': 'Proposer l\'adoption',
      'adoptProposeAdoptionQuestion': 'Voulez-vous proposer l\'adoption de',
      'adoptTo': 'à',
      'adoptPersonWillReceiveNotif': 'Cette personne recevra une notification pour confirmer.',
      'adoptCancel': 'Annuler',
      'adoptProposalSentTo': 'Proposition envoyée à',
      'adoptDeleteConversationTitle': 'Supprimer la conversation',
      'adoptDeleteConversationDesc': 'Cette conversation sera masquée de votre liste.',
      'adoptDecline': 'Refuser',
      'adoptAccept': 'Accepter',
      'adoptConfirmationSuccess': '🎉 Adoption confirmée !',
      'adoptDeclinedMessage': 'Adoption refusée. L\'annonce reste disponible.',
      'adoptCreateProfile': 'Créer le profil',
      'adoptMyAds': 'Mes annonces',
      'adoptCreateButton': 'Créer',
      'adoptTotal': 'Total',
      'adoptActive': 'Actives',
      'adoptPending': 'En attente',
      'adoptAdoptedPlural': 'Adoptées',
      'adoptModificationImpossible': 'Modification impossible',
      'adoptAlreadyAdopted': 'Cette annonce a déjà été adoptée et ne peut plus être modifiée.',
      'adoptOk': 'OK',
      'adoptDeleteAdTitle': 'Supprimer l\'annonce',
      'adoptDeleteAdDesc': 'Cette action est irréversible.',
      'adoptAdDeleted': 'Annonce supprimée',
      'adoptNoAdsInList': 'Aucune annonce',
      'adoptCreateFirstAd': 'Créez votre première annonce\npour trouver un foyer à un animal',
      'adoptCreateAd': 'Créer une annonce',
      'adoptEditAd': 'Modifier l\'annonce',
      'adoptNewAd': 'Nouvelle annonce',
      'adoptPhotos': 'Photos',
      'adoptInformations': 'Informations',
      'adoptRequired': 'Requis',
      'adoptAdTitle': 'Titre de l\'annonce',
      'adoptAdTitleHint': 'Ex: Chiot adorable cherche famille',
      'adoptAnimalName': 'Nom de l\'animal',
      'adoptAnimalNameHint': 'Ex: Max',
      'adoptSpecies': 'Espèce',
      'adoptSex': 'Sexe',
      'adoptAge': 'Âge',
      'adoptAgeHint': 'Ex: 3 mois',
      'adoptCity': 'Ville',
      'adoptCityHint': 'Ex: Alger',
      'adoptDescription': 'Description',
      'adoptDescriptionHint': 'Décrivez l\'animal, son caractère...',
      'adoptSaveChanges': 'Enregistrer les modifications',
      'adoptPublishAd': 'Publier l\'annonce',
      'adoptAddPhoto': 'Ajoutez au moins une photo',
      'adoptAdModified': 'Annonce modifiée - en validation',
      'adoptAdCreated': 'Annonce créée - en validation',
      'adoptAddPhotoButton': 'Ajouter',
      'adoptStatusAdopted': 'Adopté',
      'adoptStatusActive': 'Active',
      'adoptStatusRejected': 'Refusée',
      'adoptStatusPending': 'En attente',
      'adoptModify': 'Modifier',
      'adoptCongratulations': '🎉 Félicitations !',
      'adoptChangedALife': 'Vous avez changé une vie en adoptant',
      'adoptCreateProfileDesc': 'Créez le profil de',
      'adoptCreateProfileDesc2': 'pour suivre sa santé, ses vaccins et son bien-être dans l\'application.',
      'adoptLater': 'Plus tard',
      'adoptConfirmationDialogTitle': 'Confirmation d\'adoption',
      'adoptReallyWelcome': 'Voulez-vous vraiment accueillir',
      'adoptInYourLife': 'dans votre vie ?',
      'adoptCommitmentMessage': 'En acceptant, vous vous engagez à prendre soin de cet animal et à lui offrir un foyer aimant.',
      'adoptMissingConversationId': 'ID de conversation manquant',
      // Vet details
      'chooseService': 'Choisir un service',
      'forWhichAnimal': 'Pour quel animal ?',
      'chooseSlot': 'Choisir un créneau',
      'noServiceAvailable': 'Aucun service disponible.',
      'addAnimalFirst': 'Vous devez d\'abord ajouter un animal dans votre profil.',
      'noSlotAvailable': 'Aucun créneau disponible sur 14 jours.',
      'noSlotThisDay': 'Aucun créneau ce jour.',
      'total': 'Total',
      'confirmBooking': 'Confirmer',
      'oneStepAtTime': 'Une étape à la fois',
      'trustRestrictionMessage': 'En tant que nouveau client, vous devez d\'abord honorer votre rendez-vous en cours avant d\'en réserver un autre.\n\nCela nous aide à garantir un service de qualité pour tous.',
      'understood': 'J\'ai compris',
      // Booking thanks
      'thankYou': 'Merci !',
      'bookingConfirmedTitle': 'Rendez-vous confirmé',
      'bookingPendingMessage': 'Votre demande a bien été envoyée.\nNous vous notifierons dès que le vétérinaire confirme.',
      'bookingRef': 'Réf.',
      'backToHome': 'Retour à l\'accueil',
      'viewMyBookings': 'Voir mes rendez-vous',
      'viewBookingDetails': 'Voir le rendez-vous',
      'pendingConfirmation': 'En attente de confirmation',
      'explore': 'Explorer',
      // Booking details
      'bookingDetailsTitle': 'Détails du rendez-vous',
      'dateLabel': 'Date',
      'timeLabel': 'Heure',
      'locationLabel': 'Chez',
      'serviceLabel': 'Service choisi',
      'amountLabel': 'Montant à régler',
      'confirmedBooking': 'Rendez-vous confirmé',
      'pendingStatusMessage': 'Le professionnel doit confirmer votre demande',
      'confirmedStatusMessage': 'Votre rendez-vous est validé',
      'cancelBookingTitle': 'Annuler le rendez-vous ?',
      'cancelBookingMessage': 'Cette action est irréversible. Confirmez-vous l\'annulation ?',
      'no': 'Non',
      'yesCancel': 'Oui, annuler',
      'bookingCancelled': 'Rendez-vous annulé',
      'modificationImpossible': 'Modification impossible (pro/service manquants)',
      'oldBookingCancelled': 'Ancien rendez-vous annulé',
      'modify': 'Modifier',
      'directions': 'Itinéraire',
      // Pets management
      'swipeToNavigate': 'Swipez pour naviguer',
      'noPets': 'Aucun animal',
      'addFirstPet': 'Ajoutez votre premier compagnon pour accéder à son carnet de santé',
      'addPet': 'Ajouter un animal',
      'dog': 'Chien',
      'cat': 'Chat',
      'bird': 'Oiseau',
      'rodent': 'Rongeur',
      'reptile': 'Reptile',
      'animal': 'Animal',
      'months': 'mois',
      'year': 'an',
      'years': 'ans',
      'vaccinesDue': 'vaccin(s) à faire',
      'activeTreatments': 'traitement(s) en cours',
      'allergies': 'allergie(s)',
      'healthRecord': 'Carnet',
      'qrCode': 'QR Code',
      // QR Code screen
      'medicalQrCode': 'QR Code Médical',
      'active': 'Actif',
      'expiresIn': 'Expire dans',
      'instructions': 'Instructions',
      'qrInstruction1': 'Montrez ce QR code à votre vétérinaire',
      'qrInstruction2': 'Il pourra consulter l\'historique médical',
      'qrInstruction3': 'Et ajouter les nouveaux actes médicaux',
      'generateNewCode': 'Générer un nouveau code',
      'appointmentConfirmed': 'Rendez-vous confirmé !',
      'visitRegisteredSuccess': 'Votre visite a été enregistrée avec succès',
      'retry': 'Réessayer',
      // Health stats screen
      'healthStats': 'Statistiques de santé',
      'addData': 'Ajouter',
      'addWeight': 'Ajouter poids',
      'addTempHeart': 'Ajouter temp./rythme',
      'currentWeight': 'Poids actuel',
      'temperature': 'Température',
      'average': 'Moyenne',
      'weightEvolution': 'Évolution du poids',
      'temperatureHistory': 'Historique température',
      'heartRate': 'Rythme cardiaque',
      'noHealthData': 'Aucune donnée de santé',
      'healthDataWillAppear': 'Les données de santé apparaîtront ici',
      'medicalHistory': 'Historique médical',
      'kg': 'kg',
      'bpm': 'bpm',
      // Prescriptions screen
      'prescriptions': 'Ordonnances',
      'currentTreatments': 'Traitements en cours',
      'treatmentHistory': 'Historique',
      'ongoing': 'En cours',
      'frequency': 'Fréquence',
      'startDate': 'Début',
      'endDate': 'Fin',
      'noPrescriptions': 'Aucune ordonnance',
      'prescriptionsWillAppear': 'Les ordonnances apparaîtront ici',
      'medication': 'Médicament',
      'notes': 'Notes',
      'dosage': 'Dosage',
      'treatmentDetails': 'Détails du traitement',
      // Vaccinations screen
      'vaccinations': 'Vaccinations',
      'overdueReminders': 'Rappels en retard',
      'upcoming': 'Prochainement',
      'planned': 'Planifiés',
      'completed': 'Effectués',
      'overdue': 'En retard',
      'nextReminder': 'Prochain rappel',
      'batch': 'Lot',
      'veterinarian': 'Vétérinaire',
      'date': 'Date',
      'reminder': 'Rappel',
      'noVaccine': 'Aucun vaccin',
      'addPetVaccines': 'Ajoutez les vaccins de votre animal',
      'deleteVaccine': 'Supprimer le vaccin',
      'confirmDeleteVaccine': 'Êtes-vous sûr de vouloir supprimer',
      'vaccineDeleted': 'Vaccin supprimé',
      'today': 'Aujourd\'hui',
      'delayDays': 'Retard',
      'inDays': 'Dans',
      'day': 'jour',
      'days': 'jours',
      // Diseases screen
      'diseaseFollowUp': 'Suivi de maladie',
      'ongoingStatus': 'En cours',
      'chronicStatus': 'Chronique',
      'monitoringStatus': 'Sous surveillance',
      'curedStatus': 'Guéries',
      'mildSeverity': 'Légère',
      'moderateSeverity': 'Modérée',
      'severeSeverity': 'Sévère',
      'diagnosis': 'Diagnostic',
      'cured': 'Guéri',
      'updates': 'mise(s) à jour',
      'noDisease': 'Aucune maladie',
      'diseaseFollowUpWillAppear': 'Le suivi des maladies apparaîtra ici',
      // Medical history screen
      'healthOf': 'Santé de',
      'medicalHistoryTitle': 'Historique médical',
      'vaccination': 'Vaccination',
      'surgery': 'Chirurgie',
      'checkup': 'Contrôle',
      'treatment': 'Traitement',
      'other': 'Autre',
      'noHistory': 'Aucun historique',
      'addFirstRecord': 'Ajoutez le premier record médical',
      'addRecord': 'Ajouter un record',
      'deleteRecord': 'Supprimer',
      'confirmDeleteRecord': 'Voulez-vous supprimer ce record ?',
      // Health hub screen
      'petHealth': 'Santé',
      'healthStatus': 'État de santé',
      'latestMeasurements': 'Dernières mesures enregistrées',
      'weight': 'Poids',
      'temp': 'Temp.',
      'heart': 'Cœur',
      'quickAccess': 'Accès rapide',
      'consultationsDiagnosis': 'Consultations, diagnostics, traitements',
      'weightTempHeart': 'Poids, température, fréquence cardiaque',
      'prescribedMedications': 'Médicaments et traitements prescrits',
      'vaccineCalendar': 'Calendrier et rappels de vaccins',
      'photosEvolutionNotes': 'Photos, évolution, notes',
      'noHealthDataYet': 'Aucune donnée de santé',
      'dataWillAppearAfterVisits': 'Les données apparaîtront après les visites vétérinaires',
      'appointmentConfirmedSuccess': 'Rendez-vous confirmé avec succès',
      'owner': 'Propriétaire',
      // Disease detail screen
      'photos': 'Photos',
      'information': 'Informations',
      'symptoms': 'Symptômes',
      'evolution': 'Évolution',
      'healingDate': 'Date de guérison',
      'unknownDate': 'Date inconnue',
      'addUpdate': 'Ajouter une mise à jour',
      'notesRequired': 'Notes *',
      'observedEvolution': 'Évolution observée...',
      'severity': 'Sévérité',
      'treatmentUpdate': 'Mise à jour traitement',
      'dosageChangeMed': 'Changement de dosage, nouveau médicament...',
      'notesAreRequired': 'Les notes sont obligatoires',
      'updateAdded': 'Mise à jour ajoutée',
      'deleteDisease': 'Supprimer la maladie',
      'confirmDeleteDisease': 'Êtes-vous sûr de vouloir supprimer',
      'actionIrreversible': 'Cette action est irréversible.',
      'diseaseDeleted': 'Maladie supprimée',
      'unableToLoadImage': 'Impossible de charger l\'image',
      'update': 'Mise à jour',
      'edit': 'Modifier',
      'goBack': 'Retour',
      'addPhoto': 'Ajouter photo',
      'uploading': 'Upload...',
      'noImages': 'Aucune image',
      'imageAdded': 'Image ajoutée',
      'imageUploadError': 'Erreur upload image',
      // Daycare
      'daycaresTitle': 'Garderies',
      'searchDaycare': 'Rechercher une garderie...',
      'noDaycareFound': 'Aucune garderie trouvée',
      'noDaycareAvailable': 'Aucune garderie disponible',
      'open247': 'Ouvert 24h/24 - 7j/7',
      'openFromTo': 'Ouvert de {start} à {end}',
      'maxCapacity': 'Capacité maximale',
      'animalsCount': '{count} animaux',
      'hourlyRate': 'Tarif horaire',
      'dailyRate': 'Tarif journalier',
      'perHour': '/heure',
      'perDay': '/jour',
      'fromPrice': 'À partir de',
      'bookNow': 'Réserver maintenant',
      'schedules': 'Horaires',
      'availableDays': 'Jours de disponibilité',
      'pricing': 'Tarifs',
      'acceptedAnimals': 'Types d\'animaux acceptés',
      'aboutDaycare': 'À propos',
      'noImageAvailable': 'Aucune image',
      'myDaycareBookings': 'Mes réservations garderie',
      'allBookings': 'Toutes',
      'pendingBookings': 'En attente',
      'confirmedBookings': 'Confirmées',
      'inProgressBookings': 'En cours',
      'completedBookings': 'Terminées',
      'cancelledBookings': 'Annulées',
      'noBookingInCategory': 'Aucune réservation dans cette catégorie',
      'noBookings': 'Aucune réservation',
      'bookDaycare': 'Réserver une garderie',
      'newBooking': 'Nouvelle réservation',
      'arrival': 'Arrivée',
      'departure': 'Départ',
      'droppedAt': 'Déposé à',
      'pickedUpAt': 'Récupéré à',
      'priceLabel': 'Prix',
      'commissionLabel': 'Commission',
      'totalLabel': 'Total',
      'animalLabel': 'Animal',
      'notSpecified': 'Non spécifié',
      'notesLabel': 'Notes',
      'mon': 'Lun',
      'tue': 'Mar',
      'wed': 'Mer',
      'thu': 'Jeu',
      'fri': 'Ven',
      'sat': 'Sam',
      'sun': 'Dim',
      'daycareBookingDetails': 'Détails de la réservation',
      'dropOffTime': 'Heure de dépôt',
      'pickupTime': 'Heure de récupération',
      'lateFeePending': 'Frais de retard en attente',
      'lateFeeWaived': 'Frais de retard annulés',
      'lateFeeAmount': 'Frais de retard',
      'confirmDropOff': 'Confirmer le dépôt',
      'confirmPickup': 'Confirmer la récupération',
      // Daycare booking form
      'bookingType': 'Type de réservation',
      'selectAnimal': 'Sélectionnez votre animal',
      'selectDate': 'Sélectionnez la date',
      'selectDates': 'Sélectionnez les dates',
      'selectTime': 'Sélectionnez les heures',
      'notesOptional': 'Notes (optionnel)',
      'notesHint': 'Informations importantes sur votre animal...',
      'invalidDuration': 'Durée invalide',
      'noPetsRegistered': 'Aucun animal enregistré',
      'registerPetFirst': 'Vous devez d\'abord enregistrer vos animaux avant de réserver.',
      'addAnimal': 'Ajouter un animal',
      'pleaseSelectAnimal': 'Veuillez sélectionner un animal',
      'pleaseSelectDate': 'Veuillez sélectionner la date',
      'pleaseSelectEndDate': 'Veuillez sélectionner la date de fin',
      'yourAnimal': 'Votre animal',
      'oneStepAtATime': 'Une étape à la fois',
      'viewDaycareDetails': 'Voir les détails',
      // Booking confirmation
      'bookingSent': 'Réservation envoyée !',
      'bookingSentDescription': 'Votre demande a été envoyée avec succès.',
      'commissionIncluded': '(commission incluse)',
      'daycareWillContact': 'La garderie vous contactera pour confirmer votre réservation.',
      'seeMyBooking': 'Voir ma réservation',
      'backToHome': 'Retour à l\'accueil',
      'at': 'à',
      // Booking details
      'datesLabel': 'Dates',
      'plannedArrival': 'Arrivée prévue',
      'plannedDeparture': 'Départ prévu',
      'cancelBooking': 'Annuler la réservation',
      'cancelBookingConfirm': 'Annuler la réservation ?',
      'cancelBookingMessage': 'Cette action est irréversible. Voulez-vous vraiment annuler ?',
      'yesCancel': 'Oui, annuler',
      'bookingCancelledSuccess': 'Réservation annulée avec succès',
      'pendingDaycare': 'Garderie en attente',
      'confirmedDaycare': 'Garderie confirmée',
      'yourPet': 'Votre animal',
      'call': 'Appeler',
      // Status descriptions
      'pendingDescription': 'En attente de confirmation par la garderie',
      'confirmedDescription': 'Votre réservation est confirmée',
      'inProgressDescription': 'Votre animal est actuellement en garderie',
      'completedDescription': 'Garde terminée avec succès',
      'cancelledDescription': 'Cette réservation a été annulée',
      // Home screen daycare banner
      'petAtDaycare': 'est à la garderie',
      'sinceHours': 'depuis',
      'readyToPickup': 'Prêt à récupérer',
      'youAreXmFromDaycare': 'Vous êtes à %s de la garderie',
      'distanceKm': 'Distance: %s km',
      'confirmAnimalPickup': 'Confirmer le retrait de l\'animal',
      'enableLocationForAutoConfirm': 'Activez la localisation pour une confirmation automatique',
      // Late fee warnings
      'lateByHours': 'En retard de %sh',
      'lateByMinutes': 'En retard de %s min',
      'lateFeesWillApply': 'Des frais de retard seront appliqués',
      'lateFeeDisclaimer': 'En cas de retard au-delà de l\'heure de départ prévue, des frais supplémentaires seront facturés selon la durée du dépassement.',
      // Confirmation screens (drop-off / pickup)
      'confirmDropOffTitle': 'Confirmer le dépôt',
      'confirmPickupTitle': 'Confirmer le retrait',
      'dropOffConfirmedTitle': 'Dépôt confirmé !',
      'pickupConfirmedTitle': 'Retrait confirmé !',
      'animalDroppedSuccess': 'Votre animal a été déposé avec succès à la garderie.',
      'animalPickedUpSuccess': 'Votre animal a été récupéré avec succès.',
      'returnToHome': 'Retourner à l\'accueil',
      'dropOffConfirmedSnack': 'Dépôt confirmé ! La garderie va valider.',
      'pickupConfirmedSnack': 'Retrait confirmé ! La garderie va valider.',
      'verificationCode': 'Code de vérification',
      'showCodeToDaycare': 'Montrez ce code à la garderie',
      'codeExpired': 'Code expiré',
      'expiresInTime': 'Expire dans %s',
      'codeCopied': 'Code copié !',
      'chooseConfirmMethod': 'Choisissez une méthode de confirmation :',
      'scanAnimalQr': 'Scanner le QR code de l\'animal',
      'getVerificationCode': 'Obtenir un code de vérification',
      'noAnimalAssociated': 'Aucun animal associé à cette réservation',
      'daycareWillValidateDropOff': 'La garderie recevra une notification et devra valider le dépôt de votre animal.',
      'daycareWillValidatePickup': 'La garderie validera le retrait et les éventuels frais de retard.',
      'dropPetAt': 'Déposer %s',
      'pickupPetAt': 'Récupérer %s',
      'nearDaycare': 'Vous êtes à proximité de %s',
      'plannedFor': 'Prévu: %s',
      'calculatingFees': 'Calcul des frais...',
      'lateFeeTitle': 'Frais de retard',
      'lateDelay': 'Retard: %s',
      'ratePerHour': '%s DA/h',
      'totalLateFee': 'Total frais:',
      'daycareCanAcceptOrRefuse': 'La garderie pourra accepter ou refuser ces frais.',
      'noLateFee': 'Pas de frais de retard',
      'confirming': 'Confirmation...',
      'yourAnimalName': 'Votre animal',
      // ===== PRO DAYCARE =====
      'welcome': 'Bienvenue',
      'myDaycare': 'Ma Garderie',
      'thisMonth': 'Ce mois',
      'revenue': 'Revenus',
      'commissionLabel': 'Commission',
      'actionsRequired': 'Actions requises',
      'pendingBookingsX': 'réservation(s) en attente',
      'validationsToDoX': 'validation(s) à faire',
      'lateFeesX': 'frais de retard',
      'nearbyClientsX': 'client(s) à proximité',
      'tapToValidate': 'Appuyez pour valider',
      'today': 'Aujourd\'hui',
      'managePage': 'Gérer la page',
      'myBookings': 'Mes réservations',
      'calendar': 'Calendrier',
      'inCare': 'En garde',
      'recentBookings': 'Réservations récentes',
      'viewAll': 'Voir toutes',
      'lateFees': 'Frais de retard',
      'lateFeeAccepted': 'Frais de retard acceptés',
      'lateFeeRejected': 'Frais de retard annulés',
      'hoursLate': 'h de retard',
      'validateDropOff': 'Valider le dépôt',
      'validatePickup': 'Valider le retrait',
      'scanQrCode': 'Scanner QR code',
      'scanQrSubtitle': 'Scannez le QR code de l\'animal',
      'verifyOtp': 'Vérifier code OTP',
      'verifyOtpSubtitle': 'Entrez le code à 6 chiffres du client',
      'confirmManually': 'Confirmer manuellement',
      'confirmManuallySubtitle': 'Validation sans vérification',
      'dropOffCode': 'Code dépôt',
      'pickupCode': 'Code retrait',
      'enterCode': 'Entrez le code',
      'verify': 'Vérifier',
      'dropOffConfirmed': 'Dépôt confirmé !',
      'pickupConfirmed': 'Retrait confirmé !',
      'allBookings': 'Toutes',
      'noBookings': 'Aucune réservation',
      'noAnimalsInCare': 'Aucun animal en garde',
      'client': 'Client',
      'animal': 'Animal',
      'arrival': 'Arrivée',
      'departure': 'Départ',
      'reject': 'Refuser',
      'accept': 'Accepter',
      'markCompleted': 'Marquer terminée',
      'dropOffToValidate': 'Dépôt à valider',
      'pickupToValidate': 'Retrait à valider',
      'disputed': 'Litige',
      'validations': 'Validations garderie',
      'noValidationsPending': 'Aucune validation en attente',
      'allValidationsDone': 'Toutes les arrivées/départs sont validés',
      'dropOff': 'Dépôt',
      'pickup': 'Retrait',
      'validated': 'Validé',
      'refused': 'Refusé',
      'confirmationMethod': 'Méthode de confirmation',
      'gpsProximity': 'Proximité GPS',
      'manualValidation': 'Manuel',
      'inProgress': 'En cours',
      'newBookingsWillAppear': 'Les nouvelles réservations apparaîtront ici',
      'loadingBookings': 'Chargement des réservations...',
      'confirmed': 'Confirmées',
      'profile': 'Profil',
      'providerInfo': 'Informations professionnelles',
      'address': 'Adresse',
      'bio': 'Description',
      'pageSettings': 'Paramètres de la page',
      'capacity': 'Capacité',
      'animalTypes': 'Types d\'animaux acceptés',
      'pricing': 'Tarification',
      'hourlyRate': 'Tarif horaire',
      'dailyRate': 'Tarif journalier',
      'availability': 'Disponibilité',
      'available247': 'Disponible 24h/24',
      'customHours': 'Horaires personnalisés',
      'daysOfWeek': 'Jours de la semaine',
      // Additional Daycare Pro translations
      'confirmedAt': 'Confirmé le',
      'qrCodeConfirmation': 'Confirmation par QR code',
      'clientConfirmsDropOff': 'Le client confirme avoir déposé {petName}',
      'clientConfirmsPickup': 'Le client confirme avoir récupéré {petName}',
      'visibleToClients': 'Visible par les clients',
      'notVisible': 'Non visible',
      'daycareSettings': 'Paramètres de la garderie',
      'editPhoto': 'Modifier la photo',
      'photoUrl': 'URL de la photo',
      'approved': 'Approuvé',
      'pendingApproval': 'En attente d\'approbation',
      'providerId': 'ID du prestataire',
      'bookingsSummary': 'Résumé des réservations',
      'daycareInfo': 'Informations de la garderie',
      'googleMapsLink': 'Lien Google Maps',
      'publicVisibility': 'Visibilité publique',
      'preview': 'Aperçu',
      'description': 'Description',
      'clientNote': 'Note du client',
      'bookingRejected': 'Réservation refusée',
      'bookingUpdated': 'Réservation mise à jour',
      // ===== SUPPORT =====
      'supportTitle': 'Support',
      'supportNoTickets': 'Aucun ticket',
      'supportNoTicketsDesc': 'Vous n\'avez pas encore contacté le support',
      'supportNewTicket': 'Nouveau ticket',
      'supportTeamResponds24h': 'Notre équipe vous répondra sous 24h',
      'supportRequestType': 'Type de demande',
      'supportSubject': 'Sujet',
      'supportSubjectHint': 'Résumez votre demande en une phrase',
      'supportDescribeProblem': 'Décrivez votre problème',
      'supportDescribeHint': 'Donnez-nous le maximum de détails pour que nous puissions vous aider au mieux...',
      'supportSendTicket': 'Envoyer le ticket',
      'supportNotificationInfo': 'Vous recevrez une notification dès que notre équipe aura répondu.',
      'supportEnterSubject': 'Veuillez entrer un sujet',
      'supportEnterDescription': 'Veuillez décrire votre problème',
      'supportCategoryGeneral': 'Question générale',
      'supportCategoryAppeal': 'Contestation',
      'supportCategoryBug': 'Signaler un bug',
      'supportCategoryFeature': 'Suggestion',
      'supportCategoryBilling': 'Facturation',
      'supportCategoryOther': 'Autre',
      'supportStatusOpen': 'Nouveau',
      'supportStatusInProgress': 'En cours',
      'supportStatusWaitingUser': 'Réponse reçue',
      'supportStatusResolved': 'Résolu',
      'supportStatusClosed': 'Fermé',
      'supportYourMessage': 'Votre message...',
      'supportTicketResolved': 'Ce ticket a été résolu',
      'supportTicketClosed': 'Ce ticket est fermé',
      'supportNoMessages': 'Aucun message',
      'supportContestDecision': 'Contester cette décision',
      'supportContactSupport': 'Contacter le support',
      // ===== SUSPENSION / BAN / RESTRICTION =====
      'accountBanned': 'Compte banni',
      'accountSuspended': 'Compte suspendu',
      'accountRestricted': 'Compte restreint',
      'stillRemaining': 'Encore',
      'reason': 'Raison',
      'understood': 'J\'ai compris',
      'contestDecision': 'Contester cette décision',
      'bannedMessage': 'Votre compte a été banni suite à une violation de nos conditions d\'utilisation.',
      'suspendedMessage': 'Vous ne pouvez pas accéder aux services pendant cette période.',
      'restrictedMessage': 'Vous ne pouvez pas réserver de nouveaux rendez-vous pendant cette période.',
    },
    'en': {
      'appName': 'Vegece',
      'youAre': 'You are',
      'individual': 'Individual',
      'professional': 'Professional',
      'termsOfUse': 'Terms of use',
      'language': 'Language',
      'login': 'Login',
      'emailOrPhone': 'Email / phone number',
      'password': 'Password',
      'forgotPassword': 'Forgot password?',
      'confirm': 'Confirm',
      'or': 'OR',
      'continueWithGoogle': 'Continue with Google',
      'noAccount': 'No account?',
      'signUp': 'Sign up',
      'createAccount': 'Create an account',
      'firstName': 'First name',
      'lastName': 'Last name',
      'email': 'Email address',
      'phone': 'Phone',
      'confirmPassword': 'Confirm password',
      'next': 'Next',
      'previous': 'Previous',
      'skip': 'Skip',
      'finish': 'Finish',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'errorInvalidEmail': 'Enter a valid email (or phone number)',
      'errorPasswordRequired': 'Password required',
      'errorIncorrectCredentials': 'Incorrect email or password.',
      'errorFixFields': 'Please fix the fields in red.',
      'errorFirstNameRequired': 'First name required',
      'errorFirstNameMin': 'First name: minimum 3 characters',
      'errorFirstNameMax': 'First name: maximum 15 characters',
      'errorLastNameRequired': 'Last name required',
      'errorLastNameMin': 'Last name: minimum 3 characters',
      'errorLastNameMax': 'Last name: maximum 15 characters',
      'errorEmailInvalid': 'Invalid email',
      'errorPasswordWeak': 'Password too weak',
      'errorPasswordMismatch': 'Passwords do not match',
      'errorConfirmRequired': 'Confirmation required',
      'errorPhoneRequired': 'Phone required',
      'errorPhoneFormat': 'Number must start with 05, 06 or 07',
      'errorPhoneLength': 'Number must contain 10 digits',
      'errorEmailTaken': 'Email already in use',
      'errorPhoneTaken': 'Phone already in use',
      'passwordHelper': 'Min. 8 characters, with UPPERCASE and lowercase',
      'emailVerificationNote': 'We verify the email and create the account at this step.',
      'profilePhotoOptional': 'Profile photo (optional)',
      'choosePhoto': 'Choose a photo',
      'removePhoto': 'Remove',
      'skipPhotoNote': 'You can skip this step and add a photo later.',
      'proAccountDetected': 'Pro account detected',
      'proAccountMessage': 'This account is configured for the professional space.\nDo you want to switch to Pro login?',
      'goToPro': 'Go to Pro',
      'clientAccountDetected': 'Client account detected',
      'clientAccountMessage': 'This account does not have a professional profile yet.\nWould you like to log in as Individual, or create your Pro account?',
      'goToIndividual': 'Go to Individual',
      'createProAccount': 'Create a Pro account',
      'home': 'Home',
      'myPets': 'My pets',
      'bookings': 'Appointments',
      'profile': 'Profile',
      'settings': 'Settings',
      'logout': 'Logout',
      'animalWellbeing': 'Animal wellbeing',
      'takeCareOfCompanion': 'Take care of\nyour companion',
      'welcomeToVegece': 'Welcome\nto Vegece',
      'petsDeserveBest': 'Your pets deserve the best!',
      'yourCareMakesDifference': 'Because your care makes all the difference',
      'signInWithGoogle': 'Sign in with Google',
      'errorGoogleSignIn': 'Error during Google sign-in',
      'errorProfileRetrieval': 'Error retrieving profile',
      'veterinarian': 'Veterinarian',
      'daycare': 'Daycare',
      'petshop': 'Pet Shop',
      'vetDescription': 'Veterinary clinic and animal care',
      'daycareDescription': 'Boarding and daycare for your companions',
      'petshopDescription': 'Accessories and food shop',
      'chooseCategory': 'Choose your category',
      'proAccountNote': 'Your request will be reviewed within 24-48h',
      'address': 'Address',
      'googleMapsUrl': 'Google Maps link',
      'shopName': 'Business name',
      'avnCard': 'AVN Card (Veterinary Authorization)',
      'front': 'Front',
      'back': 'Back',
      'daycarePhotos': 'Business photos',
      'addPhoto': 'Add a photo',
      'submit': 'Submit',
      'errorAddressRequired': 'Address required',
      'errorMapsUrlRequired': 'Invalid Google Maps link',
      'errorAvnRequired': 'Both sides of the AVN card are required',
      'errorShopNameRequired': 'Business name required',
      'errorPhotoRequired': 'At least one photo required',
      'errorConnection': 'Connection error',
      'services': 'Services',
      'veterinarians': 'Veterinarians',
      'shop': 'Shop',
      'daycares': 'Daycares',
      'howIsYourCompanion': 'How is your companion?',
      'myAnimals': 'My pets',
      'healthRecordQr': 'Health record & veterinary QR code',
      'nearbyProfessionals': 'Nearby professionals',
      'adoptChangeLife': 'Adopt, change a life',
      'boostCareer': 'Boost your career',
      'vethub': 'Vethub',
      'personalInfo': 'Personal information',
      'deliveryAddress': 'Delivery address',
      'deliveryAddressHint': 'This address will be used by default for your orders',
      'quickAccess': 'Quick access',
      'myAppointments': 'My appointments',
      'manageMyPets': 'Manage my pets',
      'viewAllAppointments': 'View all my appointments',
      'support': 'Support',
      'needHelp': 'Need help?',
      'comingSoon': 'Coming soon',
      'myProfile': 'My Profile',
      'notProvided': 'Not provided',
      'phoneUpdated': 'Phone updated',
      'photoUpdated': 'Photo updated',
      'addressUpdated': 'Address updated',
      'phoneRequired': 'Phone number required',
      'emailCannotBeChanged': 'Email cannot be changed',
      'confirmLogoutMessage': 'Are you sure you want to log out?',
      'unableToLogout': 'Unable to log out',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'lightMode': 'Light mode',
      'darkMode': 'Dark mode',
      'addressHint': 'Number, street, neighborhood, city...',
      'findVetNearby': 'Find a vet nearby',
      'searchVet': 'Search for a vet...',
      'noVetFound': 'No vet found',
      'tryOtherTerms': 'Try other terms',
      'noVetAvailable': 'No vet available at the moment',
      'clearSearch': 'Clear search',
      'viewProfile': 'View profile',
      'kmAway': 'km',
      'openNow': 'Open',
      'closedNow': 'Closed',
      'opensAt': 'Opens at',
      'closesAt': 'Closes at',
      // Home screen - Adoption & Career
      'adopt': 'Adopt',
      'changeALife': 'Change a life',
      'boost': 'Boost',
      'yourCareer': 'Your career',
      // Adopt screens
      'adoptDiscussions': 'Discussions',
      'adoptAdopter': 'Adopt',
      'adoptCreate': 'Create',
      'adoptHeader': 'Adopt',
      'adoptSearching': 'Searching for pets...',
      'adoptNoAds': 'No ads available',
      'adoptErrorLoading': 'Loading error',
      'adoptNoAdsTitle': 'No ads',
      'adoptNoAdsDesc': 'There are no pets available\nfor adoption at the moment. Come back later!',
      'adoptRefresh': 'Refresh',
      'adoptDog': 'Dog',
      'adoptCat': 'Cat',
      'adoptRabbit': 'Rabbit',
      'adoptBird': 'Bird',
      'adoptOther': 'Other',
      'adoptMale': 'Male',
      'adoptFemale': 'Female',
      'adoptUnknown': 'Unknown',
      'adoptMonths': 'months',
      'adoptYear': 'year',
      'adoptYears': 'years',
      'adoptNope': 'NOPE',
      'adoptLike': 'LIKE',
      'adoptAdopted': 'ADOPTED',
      'adoptRequestSent': '❤️ Request sent',
      'adoptPassed': 'Passed',
      'adoptOwnPost': '❌ This is your ad',
      'adoptQuotaReached': '⏳ Quota reached: 5 likes maximum per day',
      'adoptQuotaReachedToday': '⏳ Quota reached for today',
      'adoptInvalidRequest': '⚠️ Invalid request. Please try again',
      'adoptTooManyRequests': '⏳ Too many requests. Wait a moment',
      'adoptServerUnavailable': '🔧 Server temporarily unavailable',
      'adoptMessages': 'Messages',
      'adoptNew': 'new',
      'adoptNews': 'new',
      'adoptNewRequests': 'New requests',
      'adoptConversations': 'Conversations',
      'adoptRequestAccepted': 'Request accepted',
      'adoptRequestRejected': 'Request rejected',
      'adoptConversationDeleted': 'Conversation deleted',
      'adoptError': 'Error',
      'adoptNewBadge': 'NEW',
      'adoptDelete': 'Delete',
      'adoptNoMessages': 'No messages',
      'adoptNoMessagesDesc': 'Your requests and conversations\nwill appear here',
      'adoptLoadingError': 'Loading error',
      'adoptRetry': 'Retry',
      'adoptJustNow': 'Just now',
      'adoptMinutes': 'min',
      'adoptHours': 'h',
      'adoptDays': 'd',
      'adoptReadyToFinalize': 'Ready to finalize?',
      'adoptProposeAdoptionTo': 'Propose adoption to',
      'adoptPropose': 'Propose',
      'adoptWaitingForAdopter': 'Waiting for adopter confirmation...',
      'adoptAdoptionProposalWaiting': 'An adoption proposal is waiting for you!',
      'adoptAdoptionConfirmed': 'Adoption confirmed!',
      'adoptNoMessagesInChat': 'No messages',
      'adoptStartConversation': 'Start the conversation!',
      'adoptYourMessage': 'Your message...',
      'adoptProposeAdoptionTitle': 'Propose adoption',
      'adoptProposeAdoptionQuestion': 'Do you want to propose the adoption of',
      'adoptTo': 'to',
      'adoptPersonWillReceiveNotif': 'This person will receive a notification to confirm.',
      'adoptCancel': 'Cancel',
      'adoptProposalSentTo': 'Proposal sent to',
      'adoptDeleteConversationTitle': 'Delete conversation',
      'adoptDeleteConversationDesc': 'This conversation will be hidden from your list.',
      'adoptDecline': 'Decline',
      'adoptAccept': 'Accept',
      'adoptConfirmationSuccess': '🎉 Adoption confirmed!',
      'adoptDeclinedMessage': 'Adoption declined. The ad remains available.',
      'adoptCreateProfile': 'Create profile',
      'adoptMyAds': 'My ads',
      'adoptCreateButton': 'Create',
      'adoptTotal': 'Total',
      'adoptActive': 'Active',
      'adoptPending': 'Pending',
      'adoptAdoptedPlural': 'Adopted',
      'adoptModificationImpossible': 'Modification impossible',
      'adoptAlreadyAdopted': 'This ad has already been adopted and cannot be modified.',
      'adoptOk': 'OK',
      'adoptDeleteAdTitle': 'Delete ad',
      'adoptDeleteAdDesc': 'This action is irreversible.',
      'adoptAdDeleted': 'Ad deleted',
      'adoptNoAdsInList': 'No ads',
      'adoptCreateFirstAd': 'Create your first ad\nto find a home for a pet',
      'adoptCreateAd': 'Create ad',
      'adoptEditAd': 'Edit ad',
      'adoptNewAd': 'New ad',
      'adoptPhotos': 'Photos',
      'adoptInformations': 'Information',
      'adoptRequired': 'Required',
      'adoptAdTitle': 'Ad title',
      'adoptAdTitleHint': 'E.g.: Adorable puppy looking for family',
      'adoptAnimalName': 'Animal name',
      'adoptAnimalNameHint': 'E.g.: Max',
      'adoptSpecies': 'Species',
      'adoptSex': 'Sex',
      'adoptAge': 'Age',
      'adoptAgeHint': 'E.g.: 3 months',
      'adoptCity': 'City',
      'adoptCityHint': 'E.g.: Algiers',
      'adoptDescription': 'Description',
      'adoptDescriptionHint': 'Describe the animal, its character...',
      'adoptSaveChanges': 'Save changes',
      'adoptPublishAd': 'Publish ad',
      'adoptAddPhoto': 'Add at least one photo',
      'adoptAdModified': 'Ad modified - pending validation',
      'adoptAdCreated': 'Ad created - pending validation',
      'adoptAddPhotoButton': 'Add',
      'adoptStatusAdopted': 'Adopted',
      'adoptStatusActive': 'Active',
      'adoptStatusRejected': 'Rejected',
      'adoptStatusPending': 'Pending',
      'adoptModify': 'Edit',
      'adoptCongratulations': '🎉 Congratulations!',
      'adoptChangedALife': 'You changed a life by adopting',
      'adoptCreateProfileDesc': 'Create the profile of',
      'adoptCreateProfileDesc2': 'to track their health, vaccines and well-being in the app.',
      'adoptLater': 'Later',
      'adoptConfirmationDialogTitle': 'Adoption confirmation',
      'adoptReallyWelcome': 'Do you really want to welcome',
      'adoptInYourLife': 'into your life?',
      'adoptCommitmentMessage': 'By accepting, you commit to taking care of this animal and providing it with a loving home.',
      'adoptMissingConversationId': 'Missing conversation ID',
      // Vet details
      'chooseService': 'Choose a service',
      'forWhichAnimal': 'For which pet?',
      'chooseSlot': 'Choose a slot',
      'noServiceAvailable': 'No service available.',
      'addAnimalFirst': 'You must first add a pet in your profile.',
      'noSlotAvailable': 'No slot available for 14 days.',
      'noSlotThisDay': 'No slot this day.',
      'total': 'Total',
      'confirmBooking': 'Confirm',
      'oneStepAtTime': 'One step at a time',
      'trustRestrictionMessage': 'As a new client, you must first honor your current appointment before booking another.\n\nThis helps us ensure quality service for everyone.',
      'understood': 'I understand',
      // Booking thanks
      'thankYou': 'Thank you!',
      'bookingConfirmedTitle': 'Appointment confirmed',
      'bookingPendingMessage': 'Your request has been sent.\nWe will notify you once the vet confirms.',
      'bookingRef': 'Ref.',
      'backToHome': 'Back to home',
      'viewMyBookings': 'View my appointments',
      'viewBookingDetails': 'View appointment',
      'pendingConfirmation': 'Pending confirmation',
      'explore': 'Explore',
      // Booking details
      'bookingDetailsTitle': 'Appointment details',
      'dateLabel': 'Date',
      'timeLabel': 'Time',
      'locationLabel': 'Location',
      'serviceLabel': 'Service selected',
      'amountLabel': 'Amount to pay',
      'confirmedBooking': 'Appointment confirmed',
      'pendingStatusMessage': 'The professional must confirm your request',
      'confirmedStatusMessage': 'Your appointment is validated',
      'cancelBookingTitle': 'Cancel appointment?',
      'cancelBookingMessage': 'This action is irreversible. Do you confirm the cancellation?',
      'no': 'No',
      'yesCancel': 'Yes, cancel',
      'bookingCancelled': 'Appointment cancelled',
      'modificationImpossible': 'Modification impossible (provider/service missing)',
      'oldBookingCancelled': 'Previous appointment cancelled',
      'modify': 'Modify',
      'directions': 'Directions',
      // Pets management
      'swipeToNavigate': 'Swipe to navigate',
      'noPets': 'No pets',
      'addFirstPet': 'Add your first companion to access their health record',
      'addPet': 'Add a pet',
      'dog': 'Dog',
      'cat': 'Cat',
      'bird': 'Bird',
      'rodent': 'Rodent',
      'reptile': 'Reptile',
      'animal': 'Animal',
      'months': 'months',
      'year': 'year',
      'years': 'years',
      'vaccinesDue': 'vaccine(s) due',
      'activeTreatments': 'active treatment(s)',
      'allergies': 'allergy(ies)',
      'healthRecord': 'Health',
      'qrCode': 'QR Code',
      // QR Code screen
      'medicalQrCode': 'Medical QR Code',
      'active': 'Active',
      'expiresIn': 'Expires in',
      'instructions': 'Instructions',
      'qrInstruction1': 'Show this QR code to your veterinarian',
      'qrInstruction2': 'They can view the medical history',
      'qrInstruction3': 'And add new medical records',
      'generateNewCode': 'Generate new code',
      'appointmentConfirmed': 'Appointment confirmed!',
      'visitRegisteredSuccess': 'Your visit has been successfully registered',
      'retry': 'Retry',
      // Health stats screen
      'healthStats': 'Health statistics',
      'addData': 'Add',
      'addWeight': 'Add weight',
      'addTempHeart': 'Add temp./heart rate',
      'currentWeight': 'Current weight',
      'temperature': 'Temperature',
      'average': 'Average',
      'weightEvolution': 'Weight evolution',
      'temperatureHistory': 'Temperature history',
      'heartRate': 'Heart rate',
      'noHealthData': 'No health data',
      'healthDataWillAppear': 'Health data will appear here',
      'medicalHistory': 'Medical history',
      'kg': 'kg',
      'bpm': 'bpm',
      // Prescriptions screen
      'prescriptions': 'Prescriptions',
      'currentTreatments': 'Current treatments',
      'treatmentHistory': 'History',
      'ongoing': 'Ongoing',
      'frequency': 'Frequency',
      'startDate': 'Start',
      'endDate': 'End',
      'noPrescriptions': 'No prescriptions',
      'prescriptionsWillAppear': 'Prescriptions will appear here',
      'medication': 'Medication',
      'notes': 'Notes',
      'dosage': 'Dosage',
      'treatmentDetails': 'Treatment details',
      // Vaccinations screen
      'vaccinations': 'Vaccinations',
      'overdueReminders': 'Overdue reminders',
      'upcoming': 'Upcoming',
      'planned': 'Planned',
      'completed': 'Completed',
      'overdue': 'Overdue',
      'nextReminder': 'Next reminder',
      'batch': 'Batch',
      'veterinarian': 'Veterinarian',
      'date': 'Date',
      'reminder': 'Reminder',
      'noVaccine': 'No vaccine',
      'addPetVaccines': 'Add your pet\'s vaccines',
      'deleteVaccine': 'Delete vaccine',
      'confirmDeleteVaccine': 'Are you sure you want to delete',
      'vaccineDeleted': 'Vaccine deleted',
      'today': 'Today',
      'delayDays': 'Overdue',
      'inDays': 'In',
      'day': 'day',
      'days': 'days',
      // Diseases screen
      'diseaseFollowUp': 'Disease follow-up',
      'ongoingStatus': 'Ongoing',
      'chronicStatus': 'Chronic',
      'monitoringStatus': 'Monitoring',
      'curedStatus': 'Cured',
      'mildSeverity': 'Mild',
      'moderateSeverity': 'Moderate',
      'severeSeverity': 'Severe',
      'diagnosis': 'Diagnosis',
      'cured': 'Cured',
      'updates': 'update(s)',
      'noDisease': 'No disease',
      'diseaseFollowUpWillAppear': 'Disease follow-up will appear here',
      // Medical history screen
      'healthOf': 'Health of',
      'medicalHistoryTitle': 'Medical history',
      'vaccination': 'Vaccination',
      'surgery': 'Surgery',
      'checkup': 'Checkup',
      'treatment': 'Treatment',
      'other': 'Other',
      'noHistory': 'No history',
      'addFirstRecord': 'Add the first medical record',
      'addRecord': 'Add a record',
      'deleteRecord': 'Delete',
      'confirmDeleteRecord': 'Do you want to delete this record?',
      // Health hub screen
      'petHealth': 'Health',
      'healthStatus': 'Health status',
      'latestMeasurements': 'Latest recorded measurements',
      'weight': 'Weight',
      'temp': 'Temp.',
      'heart': 'Heart',
      'quickAccess': 'Quick access',
      'consultationsDiagnosis': 'Consultations, diagnoses, treatments',
      'weightTempHeart': 'Weight, temperature, heart rate',
      'prescribedMedications': 'Prescribed medications and treatments',
      'vaccineCalendar': 'Vaccine calendar and reminders',
      'photosEvolutionNotes': 'Photos, evolution, notes',
      'noHealthDataYet': 'No health data yet',
      'dataWillAppearAfterVisits': 'Data will appear after veterinary visits',
      'appointmentConfirmedSuccess': 'Appointment confirmed successfully',
      'owner': 'Owner',
      // Disease detail screen
      'photos': 'Photos',
      'information': 'Information',
      'symptoms': 'Symptoms',
      'evolution': 'Evolution',
      'healingDate': 'Healing date',
      'unknownDate': 'Unknown date',
      'addUpdate': 'Add an update',
      'notesRequired': 'Notes *',
      'observedEvolution': 'Observed evolution...',
      'severity': 'Severity',
      'treatmentUpdate': 'Treatment update',
      'dosageChangeMed': 'Dosage change, new medication...',
      'notesAreRequired': 'Notes are required',
      'updateAdded': 'Update added',
      'deleteDisease': 'Delete disease',
      'confirmDeleteDisease': 'Are you sure you want to delete',
      'actionIrreversible': 'This action is irreversible.',
      'diseaseDeleted': 'Disease deleted',
      'unableToLoadImage': 'Unable to load image',
      'update': 'Update',
      'edit': 'Edit',
      'goBack': 'Go back',
      'addPhoto': 'Add photo',
      'uploading': 'Uploading...',
      'noImages': 'No images',
      'imageAdded': 'Image added',
      'imageUploadError': 'Image upload error',
      // Daycare
      'daycaresTitle': 'Daycares',
      'searchDaycare': 'Search for a daycare...',
      'noDaycareFound': 'No daycare found',
      'noDaycareAvailable': 'No daycare available',
      'open247': 'Open 24/7',
      'openFromTo': 'Open from {start} to {end}',
      'maxCapacity': 'Maximum capacity',
      'animalsCount': '{count} animals',
      'hourlyRate': 'Hourly rate',
      'dailyRate': 'Daily rate',
      'perHour': '/hour',
      'perDay': '/day',
      'fromPrice': 'Starting from',
      'bookNow': 'Book now',
      'schedules': 'Hours',
      'availableDays': 'Available days',
      'pricing': 'Pricing',
      'acceptedAnimals': 'Accepted animal types',
      'aboutDaycare': 'About',
      'noImageAvailable': 'No image',
      'myDaycareBookings': 'My daycare bookings',
      'allBookings': 'All',
      'pendingBookings': 'Pending',
      'confirmedBookings': 'Confirmed',
      'inProgressBookings': 'In progress',
      'completedBookings': 'Completed',
      'cancelledBookings': 'Cancelled',
      'noBookingInCategory': 'No booking in this category',
      'noBookings': 'No bookings',
      'bookDaycare': 'Book a daycare',
      'newBooking': 'New booking',
      'arrival': 'Arrival',
      'departure': 'Departure',
      'droppedAt': 'Dropped at',
      'pickedUpAt': 'Picked up at',
      'priceLabel': 'Price',
      'commissionLabel': 'Commission',
      'totalLabel': 'Total',
      'animalLabel': 'Animal',
      'notSpecified': 'Not specified',
      'notesLabel': 'Notes',
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
      'daycareBookingDetails': 'Booking details',
      'dropOffTime': 'Drop-off time',
      'pickupTime': 'Pickup time',
      'lateFeePending': 'Late fee pending',
      'lateFeeWaived': 'Late fee waived',
      'lateFeeAmount': 'Late fee',
      'confirmDropOff': 'Confirm drop-off',
      'confirmPickup': 'Confirm pickup',
      // Daycare booking form
      'bookingType': 'Booking type',
      'selectAnimal': 'Select your pet',
      'selectDate': 'Select date',
      'selectDates': 'Select dates',
      'selectTime': 'Select times',
      'notesOptional': 'Notes (optional)',
      'notesHint': 'Important information about your pet...',
      'invalidDuration': 'Invalid duration',
      'noPetsRegistered': 'No pets registered',
      'registerPetFirst': 'You must register your pets before booking.',
      'addAnimal': 'Add a pet',
      'pleaseSelectAnimal': 'Please select a pet',
      'pleaseSelectDate': 'Please select a date',
      'pleaseSelectEndDate': 'Please select an end date',
      'yourAnimal': 'Your pet',
      'oneStepAtATime': 'One step at a time',
      'viewDaycareDetails': 'View details',
      // Booking confirmation
      'bookingSent': 'Booking sent!',
      'bookingSentDescription': 'Your request has been sent successfully.',
      'commissionIncluded': '(commission included)',
      'daycareWillContact': 'The daycare will contact you to confirm your booking.',
      'seeMyBooking': 'See my booking',
      'backToHome': 'Back to home',
      'at': 'at',
      // Booking details
      'datesLabel': 'Dates',
      'plannedArrival': 'Planned arrival',
      'plannedDeparture': 'Planned departure',
      'cancelBooking': 'Cancel booking',
      'cancelBookingConfirm': 'Cancel booking?',
      'cancelBookingMessage': 'This action is irreversible. Do you really want to cancel?',
      'yesCancel': 'Yes, cancel',
      'bookingCancelledSuccess': 'Booking cancelled successfully',
      'pendingDaycare': 'Daycare pending',
      'confirmedDaycare': 'Daycare confirmed',
      'yourPet': 'Your pet',
      'call': 'Call',
      // Status descriptions
      'pendingDescription': 'Awaiting confirmation from the daycare',
      'confirmedDescription': 'Your booking is confirmed',
      'inProgressDescription': 'Your pet is currently at the daycare',
      'completedDescription': 'Care completed successfully',
      'cancelledDescription': 'This booking has been cancelled',
      // Home screen daycare banner
      'petAtDaycare': 'is at daycare',
      'sinceHours': 'since',
      'readyToPickup': 'Ready to pick up',
      'youAreXmFromDaycare': 'You are %s from the daycare',
      'distanceKm': 'Distance: %s km',
      'confirmAnimalPickup': 'Confirm animal pickup',
      'enableLocationForAutoConfirm': 'Enable location for automatic confirmation',
      // Late fee warnings
      'lateByHours': '%sh late',
      'lateByMinutes': '%s min late',
      'lateFeesWillApply': 'Late fees will apply',
      'lateFeeDisclaimer': 'If you pick up your pet after the scheduled departure time, additional fees will be charged based on the duration of the delay.',
      // Confirmation screens (drop-off / pickup)
      'confirmDropOffTitle': 'Confirm drop-off',
      'confirmPickupTitle': 'Confirm pickup',
      'dropOffConfirmedTitle': 'Drop-off confirmed!',
      'pickupConfirmedTitle': 'Pickup confirmed!',
      'animalDroppedSuccess': 'Your pet has been successfully dropped off at the daycare.',
      'animalPickedUpSuccess': 'Your pet has been successfully picked up.',
      'returnToHome': 'Return to home',
      'dropOffConfirmedSnack': 'Drop-off confirmed! The daycare will validate.',
      'pickupConfirmedSnack': 'Pickup confirmed! The daycare will validate.',
      'verificationCode': 'Verification code',
      'showCodeToDaycare': 'Show this code to the daycare',
      'codeExpired': 'Code expired',
      'expiresInTime': 'Expires in %s',
      'codeCopied': 'Code copied!',
      'chooseConfirmMethod': 'Choose a confirmation method:',
      'scanAnimalQr': 'Scan the pet\'s QR code',
      'getVerificationCode': 'Get a verification code',
      'noAnimalAssociated': 'No animal associated with this booking',
      'daycareWillValidateDropOff': 'The daycare will receive a notification and must validate your pet\'s drop-off.',
      'daycareWillValidatePickup': 'The daycare will validate the pickup and any late fees.',
      'dropPetAt': 'Drop off %s',
      'pickupPetAt': 'Pick up %s',
      'nearDaycare': 'You are near %s',
      'plannedFor': 'Planned: %s',
      'calculatingFees': 'Calculating fees...',
      'lateFeeTitle': 'Late fees',
      'lateDelay': 'Delay: %s',
      'ratePerHour': '%s DA/h',
      'totalLateFee': 'Total fees:',
      'daycareCanAcceptOrRefuse': 'The daycare can accept or refuse these fees.',
      'noLateFee': 'No late fees',
      'confirming': 'Confirming...',
      'yourAnimalName': 'Your pet',
      // ===== PRO DAYCARE =====
      'welcome': 'Welcome',
      'myDaycare': 'My Daycare',
      'thisMonth': 'This month',
      'revenue': 'Revenue',
      'commissionLabel': 'Commission',
      'actionsRequired': 'Actions required',
      'pendingBookingsX': 'pending booking(s)',
      'validationsToDoX': 'validation(s) to do',
      'lateFeesX': 'late fee(s)',
      'nearbyClientsX': 'nearby client(s)',
      'tapToValidate': 'Tap to validate',
      'today': 'Today',
      'managePage': 'Manage page',
      'myBookings': 'My bookings',
      'calendar': 'Calendar',
      'inCare': 'In care',
      'recentBookings': 'Recent bookings',
      'viewAll': 'View all',
      'lateFees': 'Late fees',
      'lateFeeAccepted': 'Late fees accepted',
      'lateFeeRejected': 'Late fees cancelled',
      'hoursLate': 'h late',
      'validateDropOff': 'Validate drop-off',
      'validatePickup': 'Validate pickup',
      'scanQrCode': 'Scan QR code',
      'scanQrSubtitle': 'Scan the pet\'s QR code',
      'verifyOtp': 'Verify OTP code',
      'verifyOtpSubtitle': 'Enter client\'s 6-digit code',
      'confirmManually': 'Confirm manually',
      'confirmManuallySubtitle': 'Validation without verification',
      'dropOffCode': 'Drop-off code',
      'pickupCode': 'Pickup code',
      'enterCode': 'Enter the code',
      'verify': 'Verify',
      'dropOffConfirmed': 'Drop-off confirmed!',
      'pickupConfirmed': 'Pickup confirmed!',
      'allBookings': 'All',
      'noBookings': 'No bookings',
      'noAnimalsInCare': 'No animals in care',
      'client': 'Client',
      'animal': 'Animal',
      'arrival': 'Arrival',
      'departure': 'Departure',
      'reject': 'Reject',
      'accept': 'Accept',
      'markCompleted': 'Mark completed',
      'dropOffToValidate': 'Drop-off to validate',
      'pickupToValidate': 'Pickup to validate',
      'disputed': 'Disputed',
      'validations': 'Daycare validations',
      'noValidationsPending': 'No validations pending',
      'allValidationsDone': 'All arrivals/departures validated',
      'dropOff': 'Drop-off',
      'pickup': 'Pickup',
      'validated': 'Validated',
      'refused': 'Refused',
      'confirmationMethod': 'Confirmation method',
      'gpsProximity': 'GPS proximity',
      'manualValidation': 'Manual',
      'inProgress': 'In progress',
      'newBookingsWillAppear': 'New bookings will appear here',
      'loadingBookings': 'Loading bookings...',
      'confirmed': 'Confirmed',
      'profile': 'Profile',
      'providerInfo': 'Professional information',
      'address': 'Address',
      'bio': 'Description',
      'pageSettings': 'Page settings',
      'capacity': 'Capacity',
      'animalTypes': 'Accepted animal types',
      'pricing': 'Pricing',
      'hourlyRate': 'Hourly rate',
      'dailyRate': 'Daily rate',
      'availability': 'Availability',
      'available247': 'Available 24/7',
      'customHours': 'Custom hours',
      'daysOfWeek': 'Days of the week',
      // Additional Daycare Pro translations
      'confirmedAt': 'Confirmed at',
      'qrCodeConfirmation': 'QR code confirmation',
      'clientConfirmsDropOff': 'Client confirms dropping off {petName}',
      'clientConfirmsPickup': 'Client confirms picking up {petName}',
      'visibleToClients': 'Visible to clients',
      'notVisible': 'Not visible',
      'daycareSettings': 'Daycare settings',
      'editPhoto': 'Edit photo',
      'photoUrl': 'Photo URL',
      'approved': 'Approved',
      'pendingApproval': 'Pending approval',
      'providerId': 'Provider ID',
      'bookingsSummary': 'Bookings summary',
      'daycareInfo': 'Daycare info',
      'googleMapsLink': 'Google Maps link',
      'publicVisibility': 'Public visibility',
      'preview': 'Preview',
      'description': 'Description',
      'clientNote': 'Client note',
      'bookingRejected': 'Booking rejected',
      'bookingUpdated': 'Booking updated',
      // ===== SUPPORT =====
      'supportTitle': 'Support',
      'supportNoTickets': 'No tickets',
      'supportNoTicketsDesc': 'You haven\'t contacted support yet',
      'supportNewTicket': 'New ticket',
      'supportTeamResponds24h': 'Our team will respond within 24h',
      'supportRequestType': 'Request type',
      'supportSubject': 'Subject',
      'supportSubjectHint': 'Summarize your request in one sentence',
      'supportDescribeProblem': 'Describe your problem',
      'supportDescribeHint': 'Give us as much detail as possible so we can help you better...',
      'supportSendTicket': 'Send ticket',
      'supportNotificationInfo': 'You will receive a notification as soon as our team responds.',
      'supportEnterSubject': 'Please enter a subject',
      'supportEnterDescription': 'Please describe your problem',
      'supportCategoryGeneral': 'General question',
      'supportCategoryAppeal': 'Appeal',
      'supportCategoryBug': 'Report a bug',
      'supportCategoryFeature': 'Suggestion',
      'supportCategoryBilling': 'Billing',
      'supportCategoryOther': 'Other',
      'supportStatusOpen': 'New',
      'supportStatusInProgress': 'In progress',
      'supportStatusWaitingUser': 'Response received',
      'supportStatusResolved': 'Resolved',
      'supportStatusClosed': 'Closed',
      'supportYourMessage': 'Your message...',
      'supportTicketResolved': 'This ticket has been resolved',
      'supportTicketClosed': 'This ticket is closed',
      'supportNoMessages': 'No messages',
      'supportContestDecision': 'Contest this decision',
      'supportContactSupport': 'Contact support',
      // ===== SUSPENSION / BAN / RESTRICTION =====
      'accountBanned': 'Account banned',
      'accountSuspended': 'Account suspended',
      'accountRestricted': 'Account restricted',
      'stillRemaining': 'Remaining',
      'reason': 'Reason',
      'understood': 'I understand',
      'contestDecision': 'Contest this decision',
      'bannedMessage': 'Your account has been banned for violating our terms of use.',
      'suspendedMessage': 'You cannot access services during this period.',
      'restrictedMessage': 'You cannot book new appointments during this period.',
    },
    'ar': {
      'appName': 'فيجيس',
      'youAre': 'أنت',
      'individual': 'فرد',
      'professional': 'محترف',
      'termsOfUse': 'شروط الاستخدام',
      'language': 'اللغة',
      'login': 'تسجيل الدخول',
      'emailOrPhone': 'البريد الإلكتروني / رقم الهاتف',
      'password': 'كلمة المرور',
      'forgotPassword': 'نسيت كلمة المرور؟',
      'confirm': 'تأكيد',
      'or': 'أو',
      'continueWithGoogle': 'المتابعة مع جوجل',
      'noAccount': 'ليس لديك حساب؟',
      'signUp': 'إنشاء حساب',
      'createAccount': 'إنشاء حساب جديد',
      'firstName': 'الاسم الأول',
      'lastName': 'اسم العائلة',
      'email': 'البريد الإلكتروني',
      'phone': 'الهاتف',
      'confirmPassword': 'تأكيد كلمة المرور',
      'next': 'التالي',
      'previous': 'السابق',
      'skip': 'تخطي',
      'finish': 'إنهاء',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'close': 'إغلاق',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجاح',
      'errorInvalidEmail': 'أدخل بريد إلكتروني (أو رقم هاتف) صالح',
      'errorPasswordRequired': 'كلمة المرور مطلوبة',
      'errorIncorrectCredentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'errorFixFields': 'يرجى تصحيح الحقول المحددة باللون الأحمر.',
      'errorFirstNameRequired': 'الاسم الأول مطلوب',
      'errorFirstNameMin': 'الاسم الأول: 3 أحرف على الأقل',
      'errorFirstNameMax': 'الاسم الأول: 15 حرفًا كحد أقصى',
      'errorLastNameRequired': 'اسم العائلة مطلوب',
      'errorLastNameMin': 'اسم العائلة: 3 أحرف على الأقل',
      'errorLastNameMax': 'اسم العائلة: 15 حرفًا كحد أقصى',
      'errorEmailInvalid': 'بريد إلكتروني غير صالح',
      'errorPasswordWeak': 'كلمة المرور ضعيفة جدًا',
      'errorPasswordMismatch': 'كلمات المرور غير متطابقة',
      'errorConfirmRequired': 'التأكيد مطلوب',
      'errorPhoneRequired': 'رقم الهاتف مطلوب',
      'errorPhoneFormat': 'يجب أن يبدأ الرقم بـ 05 أو 06 أو 07',
      'errorPhoneLength': 'يجب أن يحتوي الرقم على 10 أرقام',
      'errorEmailTaken': 'البريد الإلكتروني مستخدم بالفعل',
      'errorPhoneTaken': 'رقم الهاتف مستخدم بالفعل',
      'passwordHelper': '8 أحرف على الأقل، مع حروف كبيرة وصغيرة',
      'emailVerificationNote': 'نتحقق من البريد الإلكتروني وننشئ الحساب في هذه الخطوة.',
      'profilePhotoOptional': 'صورة الملف الشخصي (اختياري)',
      'choosePhoto': 'اختيار صورة',
      'removePhoto': 'إزالة',
      'skipPhotoNote': 'يمكنك تخطي هذه الخطوة وإضافة صورة لاحقًا.',
      'proAccountDetected': 'تم اكتشاف حساب محترف',
      'proAccountMessage': 'هذا الحساب مُعد للمساحة المهنية.\nهل تريد التحويل إلى تسجيل الدخول كمحترف؟',
      'goToPro': 'الذهاب إلى المحترف',
      'clientAccountDetected': 'تم اكتشاف حساب عميل',
      'clientAccountMessage': 'هذا الحساب ليس لديه ملف تعريف مهني بعد.\nهل تريد تسجيل الدخول كفرد أو إنشاء حساب محترف؟',
      'goToIndividual': 'الذهاب إلى الفرد',
      'createProAccount': 'إنشاء حساب محترف',
      'home': 'الرئيسية',
      'myPets': 'حيواناتي',
      'bookings': 'المواعيد',
      'profile': 'الملف الشخصي',
      'settings': 'الإعدادات',
      'logout': 'تسجيل الخروج',
      'animalWellbeing': 'رفاهية الحيوان',
      'takeCareOfCompanion': 'اعتنِ\nبرفيقك',
      'welcomeToVegece': 'مرحباً\nفي فيجيس',
      'petsDeserveBest': 'حيواناتك تستحق الأفضل!',
      'yourCareMakesDifference': 'لأن رعايتك تصنع الفرق',
      'signInWithGoogle': 'تسجيل الدخول بجوجل',
      'errorGoogleSignIn': 'خطأ أثناء تسجيل الدخول بجوجل',
      'errorProfileRetrieval': 'خطأ في استرجاع الملف الشخصي',
      'veterinarian': 'طبيب بيطري',
      'daycare': 'حضانة',
      'petshop': 'متجر حيوانات',
      'vetDescription': 'عيادة بيطرية ورعاية الحيوانات',
      'daycareDescription': 'إقامة ورعاية نهارية لرفاقك',
      'petshopDescription': 'متجر إكسسوارات وطعام',
      'chooseCategory': 'اختر فئتك',
      'proAccountNote': 'سيتم مراجعة طلبك خلال 24-48 ساعة',
      'address': 'العنوان',
      'googleMapsUrl': 'رابط خرائط جوجل',
      'shopName': 'اسم المؤسسة',
      'avnCard': 'بطاقة AVN (ترخيص بيطري)',
      'front': 'الوجه الأمامي',
      'back': 'الوجه الخلفي',
      'daycarePhotos': 'صور المؤسسة',
      'addPhoto': 'إضافة صورة',
      'submit': 'إرسال',
      'errorAddressRequired': 'العنوان مطلوب',
      'errorMapsUrlRequired': 'رابط خرائط جوجل غير صالح',
      'errorAvnRequired': 'كلا وجهي بطاقة AVN مطلوبان',
      'errorShopNameRequired': 'اسم المؤسسة مطلوب',
      'errorPhotoRequired': 'صورة واحدة على الأقل مطلوبة',
      'errorConnection': 'خطأ في الاتصال',
      'services': 'الخدمات',
      'veterinarians': 'الأطباء البيطريون',
      'shop': 'المتجر',
      'daycares': 'الحضانات',
      'howIsYourCompanion': 'كيف حال رفيقك؟',
      'myAnimals': 'حيواناتي',
      'healthRecordQr': 'السجل الصحي ورمز QR البيطري',
      'nearbyProfessionals': 'المختصون القريبون',
      'adoptChangeLife': 'تبنَّ، غيّر حياة',
      'boostCareer': 'عزّز مسيرتك المهنية',
      'vethub': 'Vethub',
      'personalInfo': 'المعلومات الشخصية',
      'deliveryAddress': 'عنوان التوصيل',
      'deliveryAddressHint': 'سيتم استخدام هذا العنوان افتراضياً لطلباتك',
      'quickAccess': 'وصول سريع',
      'myAppointments': 'مواعيدي',
      'manageMyPets': 'إدارة حيواناتي',
      'viewAllAppointments': 'عرض جميع مواعيدي',
      'support': 'الدعم',
      'needHelp': 'هل تحتاج مساعدة؟',
      'comingSoon': 'قريباً',
      'myProfile': 'ملفي الشخصي',
      'notProvided': 'غير محدد',
      'phoneUpdated': 'تم تحديث الهاتف',
      'photoUpdated': 'تم تحديث الصورة',
      'addressUpdated': 'تم تحديث العنوان',
      'phoneRequired': 'رقم الهاتف مطلوب',
      'emailCannotBeChanged': 'لا يمكن تغيير البريد الإلكتروني',
      'confirmLogoutMessage': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      'unableToLogout': 'تعذر تسجيل الخروج',
      'appearance': 'المظهر',
      'theme': 'السمة',
      'lightMode': 'الوضع الفاتح',
      'darkMode': 'الوضع الداكن',
      'addressHint': 'الرقم، الشارع، الحي، المدينة...',
      'findVetNearby': 'ابحث عن طبيب بيطري قريب',
      'searchVet': 'ابحث عن طبيب بيطري...',
      'noVetFound': 'لم يتم العثور على طبيب بيطري',
      'tryOtherTerms': 'جرب مصطلحات أخرى',
      'noVetAvailable': 'لا يوجد طبيب بيطري متاح حالياً',
      'clearSearch': 'مسح البحث',
      'viewProfile': 'عرض الملف',
      'kmAway': 'كم',
      'openNow': 'مفتوح',
      'closedNow': 'مغلق',
      'opensAt': 'يفتح في',
      'closesAt': 'يغلق في',
      // Home screen - Adoption & Career
      'adopt': 'تبنَّ',
      'changeALife': 'غيّر حياة',
      'boost': 'عزّز',
      'yourCareer': 'مسيرتك المهنية',
      // Adopt screens
      'adoptDiscussions': 'المحادثات',
      'adoptAdopter': 'تبنّي',
      'adoptCreate': 'إنشاء',
      'adoptHeader': 'التبني',
      'adoptSearching': 'البحث عن حيوانات...',
      'adoptNoAds': 'لا توجد إعلانات متاحة',
      'adoptErrorLoading': 'خطأ في التحميل',
      'adoptNoAdsTitle': 'لا توجد إعلانات',
      'adoptNoAdsDesc': 'لا توجد حيوانات متاحة\nللتبني في الوقت الحالي. عد لاحقاً!',
      'adoptRefresh': 'تحديث',
      'adoptDog': 'كلب',
      'adoptCat': 'قطة',
      'adoptRabbit': 'أرنب',
      'adoptBird': 'طائر',
      'adoptOther': 'آخر',
      'adoptMale': 'ذكر',
      'adoptFemale': 'أنثى',
      'adoptUnknown': 'غير معروف',
      'adoptMonths': 'أشهر',
      'adoptYear': 'سنة',
      'adoptYears': 'سنوات',
      'adoptNope': 'لا',
      'adoptLike': 'نعم',
      'adoptAdopted': 'تم التبني',
      'adoptRequestSent': '❤️ تم إرسال الطلب',
      'adoptPassed': 'تم التمرير',
      'adoptOwnPost': '❌ هذا إعلانك',
      'adoptQuotaReached': '⏳ تم الوصول إلى الحد الأقصى: 5 إعجابات كحد أقصى في اليوم',
      'adoptQuotaReachedToday': '⏳ تم الوصول إلى الحد الأقصى اليوم',
      'adoptInvalidRequest': '⚠️ طلب غير صالح. حاول مجدداً',
      'adoptTooManyRequests': '⏳ طلبات كثيرة جداً. انتظر قليلاً',
      'adoptServerUnavailable': '🔧 الخادم غير متاح مؤقتاً',
      'adoptMessages': 'الرسائل',
      'adoptNew': 'جديدة',
      'adoptNews': 'جديدة',
      'adoptNewRequests': 'طلبات جديدة',
      'adoptConversations': 'المحادثات',
      'adoptRequestAccepted': 'تم قبول الطلب',
      'adoptRequestRejected': 'تم رفض الطلب',
      'adoptConversationDeleted': 'تم حذف المحادثة',
      'adoptError': 'خطأ',
      'adoptNewBadge': 'جديد',
      'adoptDelete': 'حذف',
      'adoptNoMessages': 'لا توجد رسائل',
      'adoptNoMessagesDesc': 'ستظهر طلباتك ومحادثاتك\nهنا',
      'adoptLoadingError': 'خطأ في التحميل',
      'adoptRetry': 'إعادة المحاولة',
      'adoptJustNow': 'الآن',
      'adoptMinutes': 'د',
      'adoptHours': 'س',
      'adoptDays': 'ي',
      'adoptReadyToFinalize': 'جاهز للانتهاء؟',
      'adoptProposeAdoptionTo': 'اقترح التبني ل',
      'adoptPropose': 'اقترح',
      'adoptWaitingForAdopter': 'في انتظار تأكيد المتبني...',
      'adoptAdoptionProposalWaiting': 'اقتراح تبني في انتظارك!',
      'adoptAdoptionConfirmed': 'تم تأكيد التبني!',
      'adoptNoMessagesInChat': 'لا توجد رسائل',
      'adoptStartConversation': 'ابدأ المحادثة!',
      'adoptYourMessage': 'رسالتك...',
      'adoptProposeAdoptionTitle': 'اقترح التبني',
      'adoptProposeAdoptionQuestion': 'هل تريد اقتراح تبني',
      'adoptTo': 'ل',
      'adoptPersonWillReceiveNotif': 'سيتلقى هذا الشخص إشعاراً للتأكيد.',
      'adoptCancel': 'إلغاء',
      'adoptProposalSentTo': 'تم إرسال الاقتراح إلى',
      'adoptDeleteConversationTitle': 'حذف المحادثة',
      'adoptDeleteConversationDesc': 'سيتم إخفاء هذه المحادثة من قائمتك.',
      'adoptDecline': 'رفض',
      'adoptAccept': 'قبول',
      'adoptConfirmationSuccess': '🎉 تم تأكيد التبني!',
      'adoptDeclinedMessage': 'تم رفض التبني. يظل الإعلان متاحاً.',
      'adoptCreateProfile': 'إنشاء الملف الشخصي',
      'adoptMyAds': 'إعلاناتي',
      'adoptCreateButton': 'إنشاء',
      'adoptTotal': 'الإجمالي',
      'adoptActive': 'نشطة',
      'adoptPending': 'قيد الانتظار',
      'adoptAdoptedPlural': 'تم تبنيها',
      'adoptModificationImpossible': 'التعديل غير ممكن',
      'adoptAlreadyAdopted': 'تم تبني هذا الإعلان ولا يمكن تعديله.',
      'adoptOk': 'موافق',
      'adoptDeleteAdTitle': 'حذف الإعلان',
      'adoptDeleteAdDesc': 'هذا الإجراء لا رجعة فيه.',
      'adoptAdDeleted': 'تم حذف الإعلان',
      'adoptNoAdsInList': 'لا توجد إعلانات',
      'adoptCreateFirstAd': 'أنشئ إعلانك الأول\nللعثور على منزل لحيوان',
      'adoptCreateAd': 'إنشاء إعلان',
      'adoptEditAd': 'تعديل الإعلان',
      'adoptNewAd': 'إعلان جديد',
      'adoptPhotos': 'الصور',
      'adoptInformations': 'المعلومات',
      'adoptRequired': 'مطلوب',
      'adoptAdTitle': 'عنوان الإعلان',
      'adoptAdTitleHint': 'مثال: جرو لطيف يبحث عن عائلة',
      'adoptAnimalName': 'اسم الحيوان',
      'adoptAnimalNameHint': 'مثال: ماكس',
      'adoptSpecies': 'النوع',
      'adoptSex': 'الجنس',
      'adoptAge': 'العمر',
      'adoptAgeHint': 'مثال: 3 أشهر',
      'adoptCity': 'المدينة',
      'adoptCityHint': 'مثال: الجزائر',
      'adoptDescription': 'الوصف',
      'adoptDescriptionHint': 'صف الحيوان وطباعه...',
      'adoptSaveChanges': 'حفظ التغييرات',
      'adoptPublishAd': 'نشر الإعلان',
      'adoptAddPhoto': 'أضف صورة واحدة على الأقل',
      'adoptAdModified': 'تم تعديل الإعلان - في انتظار المراجعة',
      'adoptAdCreated': 'تم إنشاء الإعلان - في انتظار المراجعة',
      'adoptAddPhotoButton': 'إضافة',
      'adoptStatusAdopted': 'تم التبني',
      'adoptStatusActive': 'نشط',
      'adoptStatusRejected': 'مرفوض',
      'adoptStatusPending': 'قيد الانتظار',
      'adoptModify': 'تعديل',
      'adoptCongratulations': '🎉 تهانينا!',
      'adoptChangedALife': 'لقد غيرت حياة بتبني',
      'adoptCreateProfileDesc': 'أنشئ ملف',
      'adoptCreateProfileDesc2': 'لتتبع صحته ولقاحاته ورفاهيته في التطبيق.',
      'adoptLater': 'لاحقاً',
      'adoptConfirmationDialogTitle': 'تأكيد التبني',
      'adoptReallyWelcome': 'هل تريد حقاً الترحيب ب',
      'adoptInYourLife': 'في حياتك؟',
      'adoptCommitmentMessage': 'بالقبول، فإنك تلتزم برعاية هذا الحيوان وتوفير منزل محب له.',
      'adoptMissingConversationId': 'معرف المحادثة مفقود',
      // Vet details
      'chooseService': 'اختر خدمة',
      'forWhichAnimal': 'لأي حيوان؟',
      'chooseSlot': 'اختر موعداً',
      'noServiceAvailable': 'لا توجد خدمات متاحة.',
      'addAnimalFirst': 'يجب عليك أولاً إضافة حيوان في ملفك الشخصي.',
      'noSlotAvailable': 'لا يوجد موعد متاح خلال 14 يوماً.',
      'noSlotThisDay': 'لا يوجد موعد في هذا اليوم.',
      'total': 'المجموع',
      'confirmBooking': 'تأكيد',
      'oneStepAtTime': 'خطوة واحدة في كل مرة',
      'trustRestrictionMessage': 'بصفتك عميلاً جديداً، يجب عليك أولاً حضور موعدك الحالي قبل حجز موعد آخر.\n\nهذا يساعدنا على ضمان خدمة عالية الجودة للجميع.',
      'understood': 'فهمت',
      // Booking thanks
      'thankYou': 'شكراً !',
      'bookingConfirmedTitle': 'تم تأكيد الموعد',
      'bookingPendingMessage': 'تم إرسال طلبك بنجاح.\nسنُعلمك فور تأكيد الطبيب البيطري.',
      'bookingRef': 'المرجع',
      'backToHome': 'العودة للرئيسية',
      'viewMyBookings': 'عرض مواعيدي',
      'viewBookingDetails': 'عرض الموعد',
      'pendingConfirmation': 'في انتظار التأكيد',
      'explore': 'استكشف',
      // Booking details
      'bookingDetailsTitle': 'تفاصيل الموعد',
      'dateLabel': 'التاريخ',
      'timeLabel': 'الوقت',
      'locationLabel': 'الموقع',
      'serviceLabel': 'الخدمة المختارة',
      'amountLabel': 'المبلغ المستحق',
      'confirmedBooking': 'موعد مؤكد',
      'pendingStatusMessage': 'يجب على المختص تأكيد طلبك',
      'confirmedStatusMessage': 'تم التحقق من موعدك',
      'cancelBookingTitle': 'إلغاء الموعد؟',
      'cancelBookingMessage': 'هذا الإجراء لا رجعة فيه. هل تؤكد الإلغاء؟',
      'no': 'لا',
      'yesCancel': 'نعم، إلغاء',
      'bookingCancelled': 'تم إلغاء الموعد',
      'modificationImpossible': 'التعديل مستحيل (مزود/خدمة مفقودة)',
      'oldBookingCancelled': 'تم إلغاء الموعد السابق',
      'modify': 'تعديل',
      'directions': 'الاتجاهات',
      // Pets management
      'swipeToNavigate': 'اسحب للتنقل',
      'noPets': 'لا توجد حيوانات',
      'addFirstPet': 'أضف رفيقك الأول للوصول إلى سجله الصحي',
      'addPet': 'إضافة حيوان',
      'dog': 'كلب',
      'cat': 'قطة',
      'bird': 'طائر',
      'rodent': 'قارض',
      'reptile': 'زاحف',
      'animal': 'حيوان',
      'months': 'أشهر',
      'year': 'سنة',
      'years': 'سنوات',
      'vaccinesDue': 'لقاح(ات) مستحقة',
      'activeTreatments': 'علاج(ات) جارية',
      'allergies': 'حساسية(ات)',
      'healthRecord': 'الصحة',
      'qrCode': 'رمز QR',
      // QR Code screen
      'medicalQrCode': 'رمز QR الطبي',
      'active': 'نشط',
      'expiresIn': 'ينتهي في',
      'instructions': 'التعليمات',
      'qrInstruction1': 'أظهر رمز QR هذا للطبيب البيطري',
      'qrInstruction2': 'سيتمكن من عرض السجل الطبي',
      'qrInstruction3': 'وإضافة السجلات الطبية الجديدة',
      'generateNewCode': 'إنشاء رمز جديد',
      'appointmentConfirmed': 'تم تأكيد الموعد!',
      'visitRegisteredSuccess': 'تم تسجيل زيارتك بنجاح',
      'retry': 'إعادة المحاولة',
      // Health stats screen
      'healthStats': 'إحصائيات الصحة',
      'addData': 'إضافة',
      'addWeight': 'إضافة الوزن',
      'addTempHeart': 'إضافة الحرارة/النبض',
      'currentWeight': 'الوزن الحالي',
      'temperature': 'الحرارة',
      'average': 'المتوسط',
      'weightEvolution': 'تطور الوزن',
      'temperatureHistory': 'سجل الحرارة',
      'heartRate': 'معدل ضربات القلب',
      'noHealthData': 'لا توجد بيانات صحية',
      'healthDataWillAppear': 'ستظهر البيانات الصحية هنا',
      'medicalHistory': 'السجل الطبي',
      'kg': 'كغ',
      'bpm': 'نبضة/د',
      // Prescriptions screen
      'prescriptions': 'الوصفات الطبية',
      'currentTreatments': 'العلاجات الحالية',
      'treatmentHistory': 'السجل',
      'ongoing': 'جاري',
      'frequency': 'التكرار',
      'startDate': 'البداية',
      'endDate': 'النهاية',
      'noPrescriptions': 'لا توجد وصفات طبية',
      'prescriptionsWillAppear': 'ستظهر الوصفات الطبية هنا',
      'medication': 'الدواء',
      'notes': 'ملاحظات',
      'dosage': 'الجرعة',
      'treatmentDetails': 'تفاصيل العلاج',
      // Vaccinations screen
      'vaccinations': 'التطعيمات',
      'overdueReminders': 'تذكيرات متأخرة',
      'upcoming': 'قادم',
      'planned': 'مخطط',
      'completed': 'مكتمل',
      'overdue': 'متأخر',
      'nextReminder': 'التذكير التالي',
      'batch': 'الدفعة',
      'veterinarian': 'طبيب بيطري',
      'date': 'التاريخ',
      'reminder': 'تذكير',
      'noVaccine': 'لا يوجد لقاح',
      'addPetVaccines': 'أضف لقاحات حيوانك الأليف',
      'deleteVaccine': 'حذف اللقاح',
      'confirmDeleteVaccine': 'هل أنت متأكد من حذف',
      'vaccineDeleted': 'تم حذف اللقاح',
      'today': 'اليوم',
      'delayDays': 'تأخير',
      'inDays': 'في',
      'day': 'يوم',
      'days': 'أيام',
      // Diseases screen
      'diseaseFollowUp': 'متابعة المرض',
      'ongoingStatus': 'جاري',
      'chronicStatus': 'مزمن',
      'monitoringStatus': 'تحت المراقبة',
      'curedStatus': 'شُفي',
      'mildSeverity': 'خفيفة',
      'moderateSeverity': 'متوسطة',
      'severeSeverity': 'شديدة',
      'diagnosis': 'التشخيص',
      'cured': 'شُفي',
      'updates': 'تحديث(ات)',
      'noDisease': 'لا يوجد مرض',
      'diseaseFollowUpWillAppear': 'ستظهر متابعة المرض هنا',
      // Medical history screen
      'healthOf': 'صحة',
      'medicalHistoryTitle': 'السجل الطبي',
      'vaccination': 'تطعيم',
      'surgery': 'جراحة',
      'checkup': 'فحص',
      'treatment': 'علاج',
      'other': 'آخر',
      'noHistory': 'لا يوجد سجل',
      'addFirstRecord': 'أضف أول سجل طبي',
      'addRecord': 'إضافة سجل',
      'deleteRecord': 'حذف',
      'confirmDeleteRecord': 'هل تريد حذف هذا السجل؟',
      // Health hub screen
      'petHealth': 'الصحة',
      'healthStatus': 'الحالة الصحية',
      'latestMeasurements': 'آخر القياسات المسجلة',
      'weight': 'الوزن',
      'temp': 'الحرارة',
      'heart': 'القلب',
      'quickAccess': 'وصول سريع',
      'consultationsDiagnosis': 'الاستشارات والتشخيصات والعلاجات',
      'weightTempHeart': 'الوزن والحرارة ومعدل ضربات القلب',
      'prescribedMedications': 'الأدوية والعلاجات الموصوفة',
      'vaccineCalendar': 'جدول اللقاحات والتذكيرات',
      'photosEvolutionNotes': 'الصور والتطور والملاحظات',
      'noHealthDataYet': 'لا توجد بيانات صحية بعد',
      'dataWillAppearAfterVisits': 'ستظهر البيانات بعد زيارات الطبيب البيطري',
      'appointmentConfirmedSuccess': 'تم تأكيد الموعد بنجاح',
      'owner': 'المالك',
      // Disease detail screen
      'photos': 'الصور',
      'information': 'المعلومات',
      'symptoms': 'الأعراض',
      'evolution': 'التطور',
      'healingDate': 'تاريخ الشفاء',
      'unknownDate': 'تاريخ غير معروف',
      'addUpdate': 'إضافة تحديث',
      'notesRequired': 'ملاحظات *',
      'observedEvolution': 'التطور الملاحظ...',
      'severity': 'الشدة',
      'treatmentUpdate': 'تحديث العلاج',
      'dosageChangeMed': 'تغيير الجرعة، دواء جديد...',
      'notesAreRequired': 'الملاحظات مطلوبة',
      'updateAdded': 'تمت إضافة التحديث',
      'deleteDisease': 'حذف المرض',
      'confirmDeleteDisease': 'هل أنت متأكد من حذف',
      'actionIrreversible': 'هذا الإجراء لا رجعة فيه.',
      'diseaseDeleted': 'تم حذف المرض',
      'unableToLoadImage': 'تعذر تحميل الصورة',
      'update': 'تحديث',
      'edit': 'تعديل',
      'goBack': 'رجوع',
      'addPhoto': 'إضافة صورة',
      'uploading': 'جاري الرفع...',
      'noImages': 'لا توجد صور',
      'imageAdded': 'تمت إضافة الصورة',
      'imageUploadError': 'خطأ في رفع الصورة',
      // Daycare
      'daycaresTitle': 'الحضانات',
      'searchDaycare': 'ابحث عن حضانة...',
      'noDaycareFound': 'لم يتم العثور على حضانة',
      'noDaycareAvailable': 'لا توجد حضانة متاحة',
      'open247': 'مفتوح 24/7',
      'openFromTo': 'مفتوح من {start} إلى {end}',
      'maxCapacity': 'السعة القصوى',
      'animalsCount': '{count} حيوانات',
      'hourlyRate': 'السعر بالساعة',
      'dailyRate': 'السعر اليومي',
      'perHour': '/ساعة',
      'perDay': '/يوم',
      'fromPrice': 'ابتداءً من',
      'bookNow': 'احجز الآن',
      'schedules': 'المواعيد',
      'availableDays': 'الأيام المتاحة',
      'pricing': 'الأسعار',
      'acceptedAnimals': 'أنواع الحيوانات المقبولة',
      'aboutDaycare': 'حول',
      'noImageAvailable': 'لا توجد صورة',
      'myDaycareBookings': 'حجوزاتي في الحضانة',
      'allBookings': 'الكل',
      'pendingBookings': 'قيد الانتظار',
      'confirmedBookings': 'مؤكدة',
      'inProgressBookings': 'جارية',
      'completedBookings': 'مكتملة',
      'cancelledBookings': 'ملغاة',
      'noBookingInCategory': 'لا توجد حجوزات في هذه الفئة',
      'noBookings': 'لا توجد حجوزات',
      'bookDaycare': 'احجز حضانة',
      'newBooking': 'حجز جديد',
      'arrival': 'الوصول',
      'departure': 'المغادرة',
      'droppedAt': 'تم التسليم في',
      'pickedUpAt': 'تم الاستلام في',
      'priceLabel': 'السعر',
      'commissionLabel': 'العمولة',
      'totalLabel': 'المجموع',
      'animalLabel': 'الحيوان',
      'notSpecified': 'غير محدد',
      'notesLabel': 'ملاحظات',
      'mon': 'إثن',
      'tue': 'ثلا',
      'wed': 'أرب',
      'thu': 'خمي',
      'fri': 'جمع',
      'sat': 'سبت',
      'sun': 'أحد',
      'daycareBookingDetails': 'تفاصيل الحجز',
      'dropOffTime': 'وقت التسليم',
      'pickupTime': 'وقت الاستلام',
      'lateFeePending': 'رسوم التأخير معلقة',
      'lateFeeWaived': 'تم التنازل عن رسوم التأخير',
      'lateFeeAmount': 'رسوم التأخير',
      'confirmDropOff': 'تأكيد التسليم',
      'confirmPickup': 'تأكيد الاستلام',
      // Daycare booking form
      'bookingType': 'نوع الحجز',
      'selectAnimal': 'اختر حيوانك',
      'selectDate': 'اختر التاريخ',
      'selectDates': 'اختر التواريخ',
      'selectTime': 'اختر الأوقات',
      'notesOptional': 'ملاحظات (اختياري)',
      'notesHint': 'معلومات مهمة عن حيوانك...',
      'invalidDuration': 'مدة غير صالحة',
      'noPetsRegistered': 'لا يوجد حيوانات مسجلة',
      'registerPetFirst': 'يجب عليك تسجيل حيواناتك قبل الحجز.',
      'addAnimal': 'إضافة حيوان',
      'pleaseSelectAnimal': 'يرجى اختيار حيوان',
      'pleaseSelectDate': 'يرجى اختيار تاريخ',
      'pleaseSelectEndDate': 'يرجى اختيار تاريخ الانتهاء',
      'yourAnimal': 'حيوانك',
      'oneStepAtATime': 'خطوة بخطوة',
      'viewDaycareDetails': 'عرض التفاصيل',
      // Booking confirmation
      'bookingSent': 'تم إرسال الحجز!',
      'bookingSentDescription': 'تم إرسال طلبك بنجاح.',
      'commissionIncluded': '(العمولة مشمولة)',
      'daycareWillContact': 'ستتصل بك الحضانة لتأكيد حجزك.',
      'seeMyBooking': 'عرض حجزي',
      'backToHome': 'العودة للرئيسية',
      'at': 'في',
      // Booking details
      'datesLabel': 'التواريخ',
      'plannedArrival': 'الوصول المخطط',
      'plannedDeparture': 'المغادرة المخططة',
      'cancelBooking': 'إلغاء الحجز',
      'cancelBookingConfirm': 'إلغاء الحجز؟',
      'cancelBookingMessage': 'هذا الإجراء لا رجعة فيه. هل تريد حقاً الإلغاء؟',
      'yesCancel': 'نعم، إلغاء',
      'bookingCancelledSuccess': 'تم إلغاء الحجز بنجاح',
      'pendingDaycare': 'حضانة قيد الانتظار',
      'confirmedDaycare': 'حضانة مؤكدة',
      'yourPet': 'حيوانك',
      'call': 'اتصال',
      // Status descriptions
      'pendingDescription': 'في انتظار تأكيد الحضانة',
      'confirmedDescription': 'تم تأكيد حجزك',
      'inProgressDescription': 'حيوانك حالياً في الحضانة',
      'completedDescription': 'تمت الرعاية بنجاح',
      'cancelledDescription': 'تم إلغاء هذا الحجز',
      // Home screen daycare banner
      'petAtDaycare': 'في الحضانة',
      'sinceHours': 'منذ',
      'readyToPickup': 'جاهز للاستلام',
      'youAreXmFromDaycare': 'أنت على بعد %s من الحضانة',
      'distanceKm': 'المسافة: %s كم',
      'confirmAnimalPickup': 'تأكيد استلام الحيوان',
      'enableLocationForAutoConfirm': 'فعّل الموقع للتأكيد التلقائي',
      // Late fee warnings
      'lateByHours': 'متأخر بـ %s ساعة',
      'lateByMinutes': 'متأخر بـ %s دقيقة',
      'lateFeesWillApply': 'سيتم تطبيق رسوم التأخير',
      'lateFeeDisclaimer': 'في حالة التأخر عن موعد المغادرة المحدد، سيتم فرض رسوم إضافية حسب مدة التأخير.',
      // Confirmation screens (drop-off / pickup)
      'confirmDropOffTitle': 'تأكيد الإيداع',
      'confirmPickupTitle': 'تأكيد الاستلام',
      'dropOffConfirmedTitle': 'تم تأكيد الإيداع!',
      'pickupConfirmedTitle': 'تم تأكيد الاستلام!',
      'animalDroppedSuccess': 'تم إيداع حيوانك بنجاح في الحضانة.',
      'animalPickedUpSuccess': 'تم استلام حيوانك بنجاح.',
      'returnToHome': 'العودة للرئيسية',
      'dropOffConfirmedSnack': 'تم تأكيد الإيداع! الحضانة ستتحقق.',
      'pickupConfirmedSnack': 'تم تأكيد الاستلام! الحضانة ستتحقق.',
      'verificationCode': 'رمز التحقق',
      'showCodeToDaycare': 'أظهر هذا الرمز للحضانة',
      'codeExpired': 'انتهت صلاحية الرمز',
      'expiresInTime': 'ينتهي في %s',
      'codeCopied': 'تم نسخ الرمز!',
      'chooseConfirmMethod': 'اختر طريقة التأكيد:',
      'scanAnimalQr': 'مسح رمز QR للحيوان',
      'getVerificationCode': 'الحصول على رمز تحقق',
      'noAnimalAssociated': 'لا يوجد حيوان مرتبط بهذا الحجز',
      'daycareWillValidateDropOff': 'ستتلقى الحضانة إشعاراً وستتحقق من إيداع حيوانك.',
      'daycareWillValidatePickup': 'ستتحقق الحضانة من الاستلام وأي رسوم تأخير.',
      'dropPetAt': 'إيداع %s',
      'pickupPetAt': 'استلام %s',
      'nearDaycare': 'أنت بالقرب من %s',
      'plannedFor': 'موعد: %s',
      'calculatingFees': 'جاري حساب الرسوم...',
      'lateFeeTitle': 'رسوم التأخير',
      'lateDelay': 'التأخير: %s',
      'ratePerHour': '%s دج/ساعة',
      'totalLateFee': 'إجمالي الرسوم:',
      'daycareCanAcceptOrRefuse': 'يمكن للحضانة قبول أو رفض هذه الرسوم.',
      'noLateFee': 'لا توجد رسوم تأخير',
      'confirming': 'جاري التأكيد...',
      'yourAnimalName': 'حيوانك',
      // ===== PRO DAYCARE =====
      'welcome': 'مرحباً',
      'myDaycare': 'حضانتي',
      'thisMonth': 'هذا الشهر',
      'revenue': 'الإيرادات',
      'commissionLabel': 'العمولة',
      'actionsRequired': 'إجراءات مطلوبة',
      'pendingBookingsX': 'حجز(حجوزات) قيد الانتظار',
      'validationsToDoX': 'تحقق(تحققات) للقيام بها',
      'lateFeesX': 'رسوم تأخير',
      'nearbyClientsX': 'عميل(عملاء) قريب',
      'tapToValidate': 'انقر للتحقق',
      'today': 'اليوم',
      'managePage': 'إدارة الصفحة',
      'myBookings': 'حجوزاتي',
      'calendar': 'التقويم',
      'inCare': 'في الرعاية',
      'recentBookings': 'الحجوزات الأخيرة',
      'viewAll': 'عرض الكل',
      'lateFees': 'رسوم التأخير',
      'lateFeeAccepted': 'تم قبول رسوم التأخير',
      'lateFeeRejected': 'تم إلغاء رسوم التأخير',
      'hoursLate': 'ساعة تأخير',
      'validateDropOff': 'التحقق من الإيداع',
      'validatePickup': 'التحقق من الاستلام',
      'scanQrCode': 'مسح رمز QR',
      'scanQrSubtitle': 'امسح رمز QR للحيوان',
      'verifyOtp': 'التحقق من رمز OTP',
      'verifyOtpSubtitle': 'أدخل الرمز المكون من 6 أرقام للعميل',
      'confirmManually': 'تأكيد يدوي',
      'confirmManuallySubtitle': 'التحقق بدون تأكيد',
      'dropOffCode': 'رمز الإيداع',
      'pickupCode': 'رمز الاستلام',
      'enterCode': 'أدخل الرمز',
      'verify': 'تحقق',
      'dropOffConfirmed': 'تم تأكيد الإيداع!',
      'pickupConfirmed': 'تم تأكيد الاستلام!',
      'allBookings': 'الكل',
      'noBookings': 'لا توجد حجوزات',
      'noAnimalsInCare': 'لا توجد حيوانات في الرعاية',
      'client': 'العميل',
      'animal': 'الحيوان',
      'arrival': 'الوصول',
      'departure': 'المغادرة',
      'reject': 'رفض',
      'accept': 'قبول',
      'markCompleted': 'وضع علامة مكتملة',
      'dropOffToValidate': 'إيداع للتحقق',
      'pickupToValidate': 'استلام للتحقق',
      'disputed': 'متنازع عليه',
      'validations': 'تحققات الحضانة',
      'noValidationsPending': 'لا توجد تحققات قيد الانتظار',
      'allValidationsDone': 'تم التحقق من جميع الوصول/المغادرة',
      'dropOff': 'إيداع',
      'pickup': 'استلام',
      'validated': 'تم التحقق',
      'refused': 'مرفوض',
      'confirmationMethod': 'طريقة التأكيد',
      'gpsProximity': 'قرب GPS',
      'manualValidation': 'يدوي',
      'inProgress': 'جارية',
      'newBookingsWillAppear': 'ستظهر الحجوزات الجديدة هنا',
      'loadingBookings': 'جاري تحميل الحجوزات...',
      'confirmed': 'مؤكدة',
      'profile': 'الملف الشخصي',
      'providerInfo': 'معلومات مهنية',
      'address': 'العنوان',
      'bio': 'الوصف',
      'pageSettings': 'إعدادات الصفحة',
      'capacity': 'السعة',
      'animalTypes': 'أنواع الحيوانات المقبولة',
      'pricing': 'التسعير',
      'hourlyRate': 'السعر بالساعة',
      'dailyRate': 'السعر اليومي',
      'availability': 'التوفر',
      'available247': 'متوفر 24/7',
      'customHours': 'ساعات مخصصة',
      'daysOfWeek': 'أيام الأسبوع',
      // Additional Daycare Pro translations
      'confirmedAt': 'تم التأكيد في',
      'qrCodeConfirmation': 'تأكيد عبر رمز QR',
      'clientConfirmsDropOff': 'يؤكد العميل إيداع {petName}',
      'clientConfirmsPickup': 'يؤكد العميل استلام {petName}',
      'visibleToClients': 'مرئي للعملاء',
      'notVisible': 'غير مرئي',
      'daycareSettings': 'إعدادات الحضانة',
      'editPhoto': 'تعديل الصورة',
      'photoUrl': 'رابط الصورة',
      'approved': 'موافق عليه',
      'pendingApproval': 'في انتظار الموافقة',
      'providerId': 'معرف المزود',
      'bookingsSummary': 'ملخص الحجوزات',
      'daycareInfo': 'معلومات الحضانة',
      'googleMapsLink': 'رابط خرائط جوجل',
      'publicVisibility': 'الظهور العام',
      'preview': 'معاينة',
      'description': 'الوصف',
      'clientNote': 'ملاحظة العميل',
      'bookingRejected': 'تم رفض الحجز',
      'bookingUpdated': 'تم تحديث الحجز',
      // ===== SUPPORT =====
      'supportTitle': 'الدعم',
      'supportNoTickets': 'لا توجد تذاكر',
      'supportNoTicketsDesc': 'لم تتواصل مع الدعم بعد',
      'supportNewTicket': 'تذكرة جديدة',
      'supportTeamResponds24h': 'سيرد فريقنا خلال 24 ساعة',
      'supportRequestType': 'نوع الطلب',
      'supportSubject': 'الموضوع',
      'supportSubjectHint': 'لخص طلبك في جملة واحدة',
      'supportDescribeProblem': 'صف مشكلتك',
      'supportDescribeHint': 'أعطنا أكبر قدر ممكن من التفاصيل حتى نتمكن من مساعدتك بشكل أفضل...',
      'supportSendTicket': 'إرسال التذكرة',
      'supportNotificationInfo': 'ستتلقى إشعارًا بمجرد رد فريقنا.',
      'supportEnterSubject': 'يرجى إدخال الموضوع',
      'supportEnterDescription': 'يرجى وصف مشكلتك',
      'supportCategoryGeneral': 'سؤال عام',
      'supportCategoryAppeal': 'اعتراض',
      'supportCategoryBug': 'الإبلاغ عن خطأ',
      'supportCategoryFeature': 'اقتراح',
      'supportCategoryBilling': 'الفواتير',
      'supportCategoryOther': 'أخرى',
      'supportStatusOpen': 'جديد',
      'supportStatusInProgress': 'قيد التنفيذ',
      'supportStatusWaitingUser': 'تم استلام الرد',
      'supportStatusResolved': 'تم الحل',
      'supportStatusClosed': 'مغلق',
      'supportYourMessage': 'رسالتك...',
      'supportTicketResolved': 'تم حل هذه التذكرة',
      'supportTicketClosed': 'هذه التذكرة مغلقة',
      'supportNoMessages': 'لا توجد رسائل',
      'supportContestDecision': 'الاعتراض على هذا القرار',
      'supportContactSupport': 'اتصل بالدعم',
      // ===== SUSPENSION / BAN / RESTRICTION =====
      'accountBanned': 'حساب محظور',
      'accountSuspended': 'حساب معلق',
      'accountRestricted': 'حساب مقيد',
      'stillRemaining': 'المتبقي',
      'reason': 'السبب',
      'understood': 'فهمت',
      'contestDecision': 'الاعتراض على هذا القرار',
      'bannedMessage': 'تم حظر حسابك بسبب انتهاك شروط الاستخدام.',
      'suspendedMessage': 'لا يمكنك الوصول إلى الخدمات خلال هذه الفترة.',
      'restrictedMessage': 'لا يمكنك حجز مواعيد جديدة خلال هذه الفترة.',
    },
  };

  String _get(String key) {
    return _translations[locale.languageCode]?[key] ??
        _translations['fr']?[key] ??
        key;
  }

  // Getters pour chaque traduction
  String get appName => _get('appName');
  String get youAre => _get('youAre');
  String get individual => _get('individual');
  String get professional => _get('professional');
  String get termsOfUse => _get('termsOfUse');
  String get language => _get('language');
  String get login => _get('login');
  String get emailOrPhone => _get('emailOrPhone');
  String get password => _get('password');
  String get forgotPassword => _get('forgotPassword');
  String get confirm => _get('confirm');
  String get or => _get('or');
  String get continueWithGoogle => _get('continueWithGoogle');
  String get noAccount => _get('noAccount');
  String get signUp => _get('signUp');
  String get createAccount => _get('createAccount');
  String get firstName => _get('firstName');
  String get lastName => _get('lastName');
  String get email => _get('email');
  String get phone => _get('phone');
  String get confirmPassword => _get('confirmPassword');
  String get next => _get('next');
  String get previous => _get('previous');
  String get skip => _get('skip');
  String get finish => _get('finish');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get delete => _get('delete');
  String get edit => _get('edit');
  String get close => _get('close');
  String get loading => _get('loading');
  String get error => _get('error');
  String get success => _get('success');
  String get errorInvalidEmail => _get('errorInvalidEmail');
  String get errorPasswordRequired => _get('errorPasswordRequired');
  String get errorIncorrectCredentials => _get('errorIncorrectCredentials');
  String get errorFixFields => _get('errorFixFields');
  String get errorFirstNameRequired => _get('errorFirstNameRequired');
  String get errorFirstNameMin => _get('errorFirstNameMin');
  String get errorFirstNameMax => _get('errorFirstNameMax');
  String get errorLastNameRequired => _get('errorLastNameRequired');
  String get errorLastNameMin => _get('errorLastNameMin');
  String get errorLastNameMax => _get('errorLastNameMax');
  String get errorEmailInvalid => _get('errorEmailInvalid');
  String get errorPasswordWeak => _get('errorPasswordWeak');
  String get errorPasswordMismatch => _get('errorPasswordMismatch');
  String get errorConfirmRequired => _get('errorConfirmRequired');
  String get errorPhoneRequired => _get('errorPhoneRequired');
  String get errorPhoneFormat => _get('errorPhoneFormat');
  String get errorPhoneLength => _get('errorPhoneLength');
  String get errorEmailTaken => _get('errorEmailTaken');
  String get errorPhoneTaken => _get('errorPhoneTaken');
  String get passwordHelper => _get('passwordHelper');
  String get emailVerificationNote => _get('emailVerificationNote');
  String get profilePhotoOptional => _get('profilePhotoOptional');
  String get choosePhoto => _get('choosePhoto');
  String get removePhoto => _get('removePhoto');
  String get skipPhotoNote => _get('skipPhotoNote');
  String get proAccountDetected => _get('proAccountDetected');
  String get proAccountMessage => _get('proAccountMessage');
  String get goToPro => _get('goToPro');
  String get clientAccountDetected => _get('clientAccountDetected');
  String get clientAccountMessage => _get('clientAccountMessage');
  String get goToIndividual => _get('goToIndividual');
  String get createProAccount => _get('createProAccount');
  String get home => _get('home');
  String get myPets => _get('myPets');
  String get bookings => _get('bookings');
  String get profile => _get('profile');
  String get settings => _get('settings');
  String get logout => _get('logout');
  String get animalWellbeing => _get('animalWellbeing');
  String get takeCareOfCompanion => _get('takeCareOfCompanion');
  String get welcomeToVegece => _get('welcomeToVegece');
  String get petsDeserveBest => _get('petsDeserveBest');
  String get yourCareMakesDifference => _get('yourCareMakesDifference');
  String get signInWithGoogle => _get('signInWithGoogle');
  String get errorGoogleSignIn => _get('errorGoogleSignIn');
  String get errorProfileRetrieval => _get('errorProfileRetrieval');
  String get veterinarian => _get('veterinarian');
  String get daycare => _get('daycare');
  String get petshop => _get('petshop');
  String get vetDescription => _get('vetDescription');
  String get daycareDescription => _get('daycareDescription');
  String get petshopDescription => _get('petshopDescription');
  String get chooseCategory => _get('chooseCategory');
  String get proAccountNote => _get('proAccountNote');
  String get address => _get('address');
  String get googleMapsUrl => _get('googleMapsUrl');
  String get shopName => _get('shopName');
  String get avnCard => _get('avnCard');
  String get front => _get('front');
  String get back => _get('back');
  String get daycarePhotos => _get('daycarePhotos');
  String get addPhoto => _get('addPhoto');
  String get submit => _get('submit');
  String get errorAddressRequired => _get('errorAddressRequired');
  String get errorMapsUrlRequired => _get('errorMapsUrlRequired');
  String get errorAvnRequired => _get('errorAvnRequired');
  String get errorShopNameRequired => _get('errorShopNameRequired');
  String get errorPhotoRequired => _get('errorPhotoRequired');
  String get errorConnection => _get('errorConnection');
  String get services => _get('services');
  String get veterinarians => _get('veterinarians');
  String get shop => _get('shop');
  String get daycares => _get('daycares');
  String get howIsYourCompanion => _get('howIsYourCompanion');
  String get myAnimals => _get('myAnimals');
  String get healthRecordQr => _get('healthRecordQr');
  String get nearbyProfessionals => _get('nearbyProfessionals');
  String get adoptChangeLife => _get('adoptChangeLife');
  String get boostCareer => _get('boostCareer');
  String get vethub => _get('vethub');
  String get personalInfo => _get('personalInfo');
  String get deliveryAddress => _get('deliveryAddress');
  String get deliveryAddressHint => _get('deliveryAddressHint');
  String get quickAccess => _get('quickAccess');
  String get myAppointments => _get('myAppointments');
  String get manageMyPets => _get('manageMyPets');
  String get viewAllAppointments => _get('viewAllAppointments');
  String get support => _get('support');
  // Support translations
  String get supportTitle => _get('supportTitle');
  String get supportNoTickets => _get('supportNoTickets');
  String get supportNoTicketsDesc => _get('supportNoTicketsDesc');
  String get supportNewTicket => _get('supportNewTicket');
  String get supportTeamResponds24h => _get('supportTeamResponds24h');
  String get supportRequestType => _get('supportRequestType');
  String get supportSubject => _get('supportSubject');
  String get supportSubjectHint => _get('supportSubjectHint');
  String get supportDescribeProblem => _get('supportDescribeProblem');
  String get supportDescribeHint => _get('supportDescribeHint');
  String get supportSendTicket => _get('supportSendTicket');
  String get supportNotificationInfo => _get('supportNotificationInfo');
  String get supportEnterSubject => _get('supportEnterSubject');
  String get supportEnterDescription => _get('supportEnterDescription');
  String get supportCategoryGeneral => _get('supportCategoryGeneral');
  String get supportCategoryAppeal => _get('supportCategoryAppeal');
  String get supportCategoryBug => _get('supportCategoryBug');
  String get supportCategoryFeature => _get('supportCategoryFeature');
  String get supportCategoryBilling => _get('supportCategoryBilling');
  String get supportCategoryOther => _get('supportCategoryOther');
  String get supportStatusOpen => _get('supportStatusOpen');
  String get supportStatusInProgress => _get('supportStatusInProgress');
  String get supportStatusWaitingUser => _get('supportStatusWaitingUser');
  String get supportStatusResolved => _get('supportStatusResolved');
  String get supportStatusClosed => _get('supportStatusClosed');
  String get supportYourMessage => _get('supportYourMessage');
  String get supportTicketResolved => _get('supportTicketResolved');
  String get supportTicketClosed => _get('supportTicketClosed');
  String get supportNoMessages => _get('supportNoMessages');
  String get supportContestDecision => _get('supportContestDecision');
  String get supportContactSupport => _get('supportContactSupport');
  // Suspension / Ban / Restriction
  String get accountBanned => _get('accountBanned');
  String get accountSuspended => _get('accountSuspended');
  String get accountRestricted => _get('accountRestricted');
  String get stillRemaining => _get('stillRemaining');
  String get reasonLabel => _get('reason');
  String get understood => _get('understood');
  String get contestDecision => _get('contestDecision');
  String get bannedMessage => _get('bannedMessage');
  String get suspendedMessage => _get('suspendedMessage');
  String get restrictedMessage => _get('restrictedMessage');
  String get needHelp => _get('needHelp');
  String get comingSoon => _get('comingSoon');
  String get myProfile => _get('myProfile');
  String get notProvided => _get('notProvided');
  String get phoneUpdated => _get('phoneUpdated');
  String get photoUpdated => _get('photoUpdated');
  String get addressUpdated => _get('addressUpdated');
  String get phoneRequired => _get('phoneRequired');
  String get emailCannotBeChanged => _get('emailCannotBeChanged');
  String get confirmLogoutMessage => _get('confirmLogoutMessage');
  String get unableToLogout => _get('unableToLogout');
  String get appearance => _get('appearance');
  String get theme => _get('theme');
  String get lightMode => _get('lightMode');
  String get darkMode => _get('darkMode');
  String get addressHint => _get('addressHint');
  String get findVetNearby => _get('findVetNearby');
  String get searchVet => _get('searchVet');
  String get noVetFound => _get('noVetFound');
  String get tryOtherTerms => _get('tryOtherTerms');
  String get noVetAvailable => _get('noVetAvailable');
  String get clearSearch => _get('clearSearch');
  String get viewProfile => _get('viewProfile');
  String get kmAway => _get('kmAway');
  String get openNow => _get('openNow');
  String get closedNow => _get('closedNow');
  String get opensAt => _get('opensAt');
  String get closesAt => _get('closesAt');
  // Home screen - Adoption & Career
  String get adopt => _get('adopt');
  String get changeALife => _get('changeALife');
  String get boost => _get('boost');
  String get yourCareer => _get('yourCareer');
  // Vet details
  String get chooseService => _get('chooseService');
  String get forWhichAnimal => _get('forWhichAnimal');
  String get chooseSlot => _get('chooseSlot');
  String get noServiceAvailable => _get('noServiceAvailable');
  String get addAnimalFirst => _get('addAnimalFirst');
  String get noSlotAvailable => _get('noSlotAvailable');
  String get noSlotThisDay => _get('noSlotThisDay');
  String get total => _get('total');
  String get confirmBooking => _get('confirmBooking');
  String get oneStepAtTime => _get('oneStepAtTime');
  String get trustRestrictionMessage => _get('trustRestrictionMessage');
  // Booking thanks
  String get thankYou => _get('thankYou');
  String get bookingConfirmedTitle => _get('bookingConfirmedTitle');
  String get bookingPendingMessage => _get('bookingPendingMessage');
  String get bookingRef => _get('bookingRef');
  String get backToHome => _get('backToHome');
  String get viewMyBookings => _get('viewMyBookings');
  String get viewBookingDetails => _get('viewBookingDetails');
  String get pendingConfirmation => _get('pendingConfirmation');
  String get explore => _get('explore');
  // Booking details
  String get bookingDetailsTitle => _get('bookingDetailsTitle');
  String get dateLabel => _get('dateLabel');
  String get timeLabel => _get('timeLabel');
  String get locationLabel => _get('locationLabel');
  String get serviceLabel => _get('serviceLabel');
  String get amountLabel => _get('amountLabel');
  String get confirmedBooking => _get('confirmedBooking');
  String get pendingStatusMessage => _get('pendingStatusMessage');
  String get confirmedStatusMessage => _get('confirmedStatusMessage');
  String get cancelBookingTitle => _get('cancelBookingTitle');
  String get cancelBookingMessage => _get('cancelBookingMessage');
  String get no => _get('no');
  String get yesCancel => _get('yesCancel');
  String get bookingCancelled => _get('bookingCancelled');
  String get modificationImpossible => _get('modificationImpossible');
  String get oldBookingCancelled => _get('oldBookingCancelled');
  String get modify => _get('modify');
  String get directions => _get('directions');
  // Pets management
  String get swipeToNavigate => _get('swipeToNavigate');
  String get noPets => _get('noPets');
  String get addFirstPet => _get('addFirstPet');
  String get addPet => _get('addPet');
  String get dog => _get('dog');
  String get cat => _get('cat');
  String get bird => _get('bird');
  String get rodent => _get('rodent');
  String get reptile => _get('reptile');
  String get animal => _get('animal');
  String get months => _get('months');
  String get year => _get('year');
  String get years => _get('years');
  String get vaccinesDue => _get('vaccinesDue');
  String get activeTreatments => _get('activeTreatments');
  String get allergies => _get('allergies');
  String get healthRecord => _get('healthRecord');
  String get qrCode => _get('qrCode');
  // QR Code screen
  String get medicalQrCode => _get('medicalQrCode');
  String get active => _get('active');
  String get expiresIn => _get('expiresIn');
  String get instructions => _get('instructions');
  String get qrInstruction1 => _get('qrInstruction1');
  String get qrInstruction2 => _get('qrInstruction2');
  String get qrInstruction3 => _get('qrInstruction3');
  String get generateNewCode => _get('generateNewCode');
  String get appointmentConfirmed => _get('appointmentConfirmed');
  String get visitRegisteredSuccess => _get('visitRegisteredSuccess');
  String get retry => _get('retry');
  // Health stats screen
  String get healthStats => _get('healthStats');
  String get addData => _get('addData');
  String get addWeight => _get('addWeight');
  String get addTempHeart => _get('addTempHeart');
  String get currentWeight => _get('currentWeight');
  String get temperature => _get('temperature');
  String get average => _get('average');
  String get weightEvolution => _get('weightEvolution');
  String get temperatureHistory => _get('temperatureHistory');
  String get heartRate => _get('heartRate');
  String get noHealthData => _get('noHealthData');
  String get healthDataWillAppear => _get('healthDataWillAppear');
  String get medicalHistory => _get('medicalHistory');
  String get kg => _get('kg');
  String get bpm => _get('bpm');
  // Prescriptions screen
  String get prescriptions => _get('prescriptions');
  String get currentTreatments => _get('currentTreatments');
  String get treatmentHistory => _get('treatmentHistory');
  String get ongoing => _get('ongoing');
  String get frequency => _get('frequency');
  String get startDate => _get('startDate');
  String get endDate => _get('endDate');
  String get noPrescriptions => _get('noPrescriptions');
  String get prescriptionsWillAppear => _get('prescriptionsWillAppear');
  String get medication => _get('medication');
  String get notes => _get('notes');
  String get dosage => _get('dosage');
  String get treatmentDetails => _get('treatmentDetails');
  // Vaccinations screen
  String get vaccinations => _get('vaccinations');
  String get overdueReminders => _get('overdueReminders');
  String get upcoming => _get('upcoming');
  String get planned => _get('planned');
  String get completed => _get('completed');
  String get overdue => _get('overdue');
  String get nextReminder => _get('nextReminder');
  String get batch => _get('batch');
  String get date => _get('date');
  String get reminder => _get('reminder');
  String get noVaccine => _get('noVaccine');
  String get addPetVaccines => _get('addPetVaccines');
  String get deleteVaccine => _get('deleteVaccine');
  String get confirmDeleteVaccine => _get('confirmDeleteVaccine');
  String get vaccineDeleted => _get('vaccineDeleted');
  String get today => _get('today');
  String get delayDays => _get('delayDays');
  String get inDays => _get('inDays');
  String get day => _get('day');
  String get days => _get('days');
  // Diseases screen
  String get diseaseFollowUp => _get('diseaseFollowUp');
  String get ongoingStatus => _get('ongoingStatus');
  String get chronicStatus => _get('chronicStatus');
  String get monitoringStatus => _get('monitoringStatus');
  String get curedStatus => _get('curedStatus');
  String get mildSeverity => _get('mildSeverity');
  String get moderateSeverity => _get('moderateSeverity');
  String get severeSeverity => _get('severeSeverity');
  String get diagnosis => _get('diagnosis');
  String get cured => _get('cured');
  String get updates => _get('updates');
  String get noDisease => _get('noDisease');
  String get diseaseFollowUpWillAppear => _get('diseaseFollowUpWillAppear');
  // Medical history screen
  String get healthOf => _get('healthOf');
  String get medicalHistoryTitle => _get('medicalHistoryTitle');
  String get vaccination => _get('vaccination');
  String get surgery => _get('surgery');
  String get checkup => _get('checkup');
  String get treatment => _get('treatment');
  String get other => _get('other');
  String get noHistory => _get('noHistory');
  String get addFirstRecord => _get('addFirstRecord');
  String get addRecord => _get('addRecord');
  String get deleteRecord => _get('deleteRecord');
  String get confirmDeleteRecord => _get('confirmDeleteRecord');
  // Health hub screen
  String get petHealth => _get('petHealth');
  String get healthStatus => _get('healthStatus');
  String get latestMeasurements => _get('latestMeasurements');
  String get weight => _get('weight');
  String get temp => _get('temp');
  String get heart => _get('heart');
  String get consultationsDiagnosis => _get('consultationsDiagnosis');
  String get weightTempHeart => _get('weightTempHeart');
  String get prescribedMedications => _get('prescribedMedications');
  String get vaccineCalendar => _get('vaccineCalendar');
  String get photosEvolutionNotes => _get('photosEvolutionNotes');
  String get noHealthDataYet => _get('noHealthDataYet');
  String get dataWillAppearAfterVisits => _get('dataWillAppearAfterVisits');
  String get appointmentConfirmedSuccess => _get('appointmentConfirmedSuccess');
  String get owner => _get('owner');
  // Disease detail screen
  String get photos => _get('photos');
  String get information => _get('information');
  String get symptoms => _get('symptoms');
  String get evolution => _get('evolution');
  String get healingDate => _get('healingDate');
  String get unknownDate => _get('unknownDate');
  String get addUpdate => _get('addUpdate');
  String get notesRequired => _get('notesRequired');
  String get observedEvolution => _get('observedEvolution');
  String get severity => _get('severity');
  String get treatmentUpdate => _get('treatmentUpdate');
  String get dosageChangeMed => _get('dosageChangeMed');
  String get notesAreRequired => _get('notesAreRequired');
  String get updateAdded => _get('updateAdded');
  String get deleteDisease => _get('deleteDisease');
  String get confirmDeleteDisease => _get('confirmDeleteDisease');
  String get actionIrreversible => _get('actionIrreversible');
  String get diseaseDeleted => _get('diseaseDeleted');
  String get unableToLoadImage => _get('unableToLoadImage');
  String get update => _get('update');
  String get goBack => _get('goBack');
  String get uploading => _get('uploading');
  String get noImages => _get('noImages');
  String get imageAdded => _get('imageAdded');
  String get imageUploadError => _get('imageUploadError');
  // Daycare getters
  String get daycaresTitle => _get('daycaresTitle');
  String get searchDaycare => _get('searchDaycare');
  String get noDaycareFound => _get('noDaycareFound');
  String get noDaycareAvailable => _get('noDaycareAvailable');
  String get open247 => _get('open247');
  String openFromTo(String start, String end) => _get('openFromTo').replaceAll('{start}', start).replaceAll('{end}', end);
  String get maxCapacity => _get('maxCapacity');
  String animalsCount(int count) => _get('animalsCount').replaceAll('{count}', count.toString());
  String get hourlyRate => _get('hourlyRate');
  String get dailyRate => _get('dailyRate');
  String get perHour => _get('perHour');
  String get perDay => _get('perDay');
  String get fromPrice => _get('fromPrice');
  String get bookNow => _get('bookNow');
  String get schedules => _get('schedules');
  String get availableDays => _get('availableDays');
  String get pricing => _get('pricing');
  String get acceptedAnimals => _get('acceptedAnimals');
  String get aboutDaycare => _get('aboutDaycare');
  String get noImageAvailable => _get('noImageAvailable');
  String get myDaycareBookings => _get('myDaycareBookings');
  String get allBookings => _get('allBookings');
  String get pendingBookings => _get('pendingBookings');
  String get confirmedBookings => _get('confirmedBookings');
  String get inProgressBookings => _get('inProgressBookings');
  String get completedBookings => _get('completedBookings');
  String get cancelledBookings => _get('cancelledBookings');
  String get noBookingInCategory => _get('noBookingInCategory');
  String get noBookings => _get('noBookings');
  String get bookDaycare => _get('bookDaycare');
  String get newBooking => _get('newBooking');
  String get arrival => _get('arrival');
  String get departure => _get('departure');
  String get droppedAt => _get('droppedAt');
  String get pickedUpAt => _get('pickedUpAt');
  String get priceLabel => _get('priceLabel');
  String get commissionLabel => _get('commissionLabel');
  String get totalLabel => _get('totalLabel');
  String get animalLabel => _get('animalLabel');
  String get notSpecified => _get('notSpecified');
  String get notesLabel => _get('notesLabel');
  String get mon => _get('mon');
  String get tue => _get('tue');
  String get wed => _get('wed');
  String get thu => _get('thu');
  String get fri => _get('fri');
  String get sat => _get('sat');
  String get sun => _get('sun');
  String get daycareBookingDetails => _get('daycareBookingDetails');
  String get dropOffTime => _get('dropOffTime');
  String get pickupTime => _get('pickupTime');
  String get lateFeePending => _get('lateFeePending');
  String get lateFeeWaived => _get('lateFeeWaived');
  String get lateFeeAmount => _get('lateFeeAmount');
  String get confirmDropOff => _get('confirmDropOff');
  String get confirmPickup => _get('confirmPickup');
  String get bookingType => _get('bookingType');
  String get selectAnimal => _get('selectAnimal');
  String get selectDate => _get('selectDate');
  String get selectDates => _get('selectDates');
  String get selectTime => _get('selectTime');
  String get notesOptional => _get('notesOptional');
  String get notesHint => _get('notesHint');
  String get invalidDuration => _get('invalidDuration');
  String get noPetsRegistered => _get('noPetsRegistered');
  String get registerPetFirst => _get('registerPetFirst');
  String get addAnimal => _get('addAnimal');
  String get pleaseSelectAnimal => _get('pleaseSelectAnimal');
  String get pleaseSelectDate => _get('pleaseSelectDate');
  String get pleaseSelectEndDate => _get('pleaseSelectEndDate');
  String get yourAnimal => _get('yourAnimal');
  String get oneStepAtATime => _get('oneStepAtATime');
  String get viewDaycareDetails => _get('viewDaycareDetails');
  // Booking confirmation (daycare)
  String get bookingSent => _get('bookingSent');
  String get bookingSentDescription => _get('bookingSentDescription');
  String get commissionIncluded => _get('commissionIncluded');
  String get daycareWillContact => _get('daycareWillContact');
  String get seeMyBooking => _get('seeMyBooking');
  String get at => _get('at');
  // Booking details (daycare)
  String get datesLabel => _get('datesLabel');
  String get plannedArrival => _get('plannedArrival');
  String get plannedDeparture => _get('plannedDeparture');
  String get cancelBooking => _get('cancelBooking');
  String get cancelBookingConfirm => _get('cancelBookingConfirm');
  String get bookingCancelledSuccess => _get('bookingCancelledSuccess');
  String get pendingDaycare => _get('pendingDaycare');
  String get confirmedDaycare => _get('confirmedDaycare');
  String get yourPet => _get('yourPet');
  String get call => _get('call');
  // Status descriptions
  String get pendingDescription => _get('pendingDescription');
  String get confirmedDescription => _get('confirmedDescription');
  String get inProgressDescription => _get('inProgressDescription');
  String get completedDescription => _get('completedDescription');
  String get cancelledDescription => _get('cancelledDescription');
  // Home screen daycare banner
  String get petAtDaycare => _get('petAtDaycare');
  String get sinceHours => _get('sinceHours');
  String get readyToPickup => _get('readyToPickup');
  String youAreXmFromDaycare(String distance) => _get('youAreXmFromDaycare').replaceAll('%s', distance);
  String distanceKm(String km) => _get('distanceKm').replaceAll('%s', km);
  String get confirmAnimalPickup => _get('confirmAnimalPickup');
  String get enableLocationForAutoConfirm => _get('enableLocationForAutoConfirm');
  // Late fee warnings
  String lateByHours(String hours) => _get('lateByHours').replaceAll('%s', hours);
  String lateByMinutes(String minutes) => _get('lateByMinutes').replaceAll('%s', minutes);
  String get lateFeesWillApply => _get('lateFeesWillApply');
  String get lateFeeDisclaimer => _get('lateFeeDisclaimer');
  // Confirmation screens (drop-off / pickup) getters
  String get confirmDropOffTitle => _get('confirmDropOffTitle');
  String get confirmPickupTitle => _get('confirmPickupTitle');
  String get dropOffConfirmedTitle => _get('dropOffConfirmedTitle');
  String get pickupConfirmedTitle => _get('pickupConfirmedTitle');
  String get animalDroppedSuccess => _get('animalDroppedSuccess');
  String get animalPickedUpSuccess => _get('animalPickedUpSuccess');
  String get returnToHome => _get('returnToHome');
  String get dropOffConfirmedSnack => _get('dropOffConfirmedSnack');
  String get pickupConfirmedSnack => _get('pickupConfirmedSnack');
  String get verificationCode => _get('verificationCode');
  String get showCodeToDaycare => _get('showCodeToDaycare');
  String get codeExpired => _get('codeExpired');
  String expiresInTime(String time) => _get('expiresInTime').replaceAll('%s', time);
  String get codeCopied => _get('codeCopied');
  String get chooseConfirmMethod => _get('chooseConfirmMethod');
  String get scanAnimalQr => _get('scanAnimalQr');
  String get getVerificationCode => _get('getVerificationCode');
  String get noAnimalAssociated => _get('noAnimalAssociated');
  String get daycareWillValidateDropOff => _get('daycareWillValidateDropOff');
  String get daycareWillValidatePickup => _get('daycareWillValidatePickup');
  String dropPetAt(String petName) => _get('dropPetAt').replaceAll('%s', petName);
  String pickupPetAt(String petName) => _get('pickupPetAt').replaceAll('%s', petName);
  String nearDaycare(String daycareName) => _get('nearDaycare').replaceAll('%s', daycareName);
  String plannedFor(String date) => _get('plannedFor').replaceAll('%s', date);
  String get calculatingFees => _get('calculatingFees');
  String get lateFeeTitle => _get('lateFeeTitle');
  String lateDelay(String delay) => _get('lateDelay').replaceAll('%s', delay);
  String ratePerHour(String rate) => _get('ratePerHour').replaceAll('%s', rate);
  String get totalLateFee => _get('totalLateFee');
  String get daycareCanAcceptOrRefuse => _get('daycareCanAcceptOrRefuse');
  String get noLateFee => _get('noLateFee');
  String get confirming => _get('confirming');
  String get yourAnimalName => _get('yourAnimalName');
  // ===== PRO DAYCARE GETTERS =====
  String get welcome => _get('welcome');
  String get myDaycare => _get('myDaycare');
  String get thisMonth => _get('thisMonth');
  String get revenue => _get('revenue');
  String get actionsRequired => _get('actionsRequired');
  String get pendingBookingsX => _get('pendingBookingsX');
  String get validationsToDoX => _get('validationsToDoX');
  String get lateFeesX => _get('lateFeesX');
  String get nearbyClientsX => _get('nearbyClientsX');
  String get tapToValidate => _get('tapToValidate');
  String get managePage => _get('managePage');
  String get myBookings => _get('myBookings');
  String get calendar => _get('calendar');
  String get inCare => _get('inCare');
  String get recentBookings => _get('recentBookings');
  String get viewAll => _get('viewAll');
  String get lateFees => _get('lateFees');
  String get lateFeeAccepted => _get('lateFeeAccepted');
  String get lateFeeRejected => _get('lateFeeRejected');
  String get hoursLate => _get('hoursLate');
  String get validateDropOff => _get('validateDropOff');
  String get validatePickup => _get('validatePickup');
  String get scanQrCode => _get('scanQrCode');
  String get scanQrSubtitle => _get('scanQrSubtitle');
  String get verifyOtp => _get('verifyOtp');
  String get verifyOtpSubtitle => _get('verifyOtpSubtitle');
  String get confirmManually => _get('confirmManually');
  String get confirmManuallySubtitle => _get('confirmManuallySubtitle');
  String get dropOffCode => _get('dropOffCode');
  String get pickupCode => _get('pickupCode');
  String get enterCode => _get('enterCode');
  String get verify => _get('verify');
  String get dropOffConfirmed => _get('dropOffConfirmed');
  String get pickupConfirmed => _get('pickupConfirmed');
  String get client => _get('client');
  String get reject => _get('reject');
  String get accept => _get('accept');
  String get markCompleted => _get('markCompleted');
  String get dropOffToValidate => _get('dropOffToValidate');
  String get pickupToValidate => _get('pickupToValidate');
  String get disputed => _get('disputed');
  String get validations => _get('validations');
  String get noValidationsPending => _get('noValidationsPending');
  String get allValidationsDone => _get('allValidationsDone');
  String get dropOff => _get('dropOff');
  String get pickup => _get('pickup');
  String get validated => _get('validated');
  String get refused => _get('refused');
  String get confirmationMethod => _get('confirmationMethod');
  String get gpsProximity => _get('gpsProximity');
  String get manualValidation => _get('manualValidation');
  String get inProgress => _get('inProgress');
  String get newBookingsWillAppear => _get('newBookingsWillAppear');
  String get loadingBookings => _get('loadingBookings');
  String get confirmed => _get('confirmed');
  String get providerInfo => _get('providerInfo');
  String get bio => _get('bio');
  String get pageSettings => _get('pageSettings');
  String get capacity => _get('capacity');
  String get animalTypes => _get('animalTypes');
  String get noAnimalsInCare => _get('noAnimalsInCare');
  String get availability => _get('availability');
  String get available247 => _get('available247');
  String get customHours => _get('customHours');
  String get daysOfWeek => _get('daysOfWeek');

  // Additional Daycare Pro translations
  String get confirmedAt => _get('confirmedAt');
  String get qrCodeConfirmation => _get('qrCodeConfirmation');
  String clientConfirmsDropOff(String petName) => _get('clientConfirmsDropOff').replaceAll('{petName}', petName);
  String clientConfirmsPickup(String petName) => _get('clientConfirmsPickup').replaceAll('{petName}', petName);
  String get visibleToClients => _get('visibleToClients');
  String get notVisible => _get('notVisible');
  String get daycareSettings => _get('daycareSettings');
  String get editPhoto => _get('editPhoto');
  String get photoUrl => _get('photoUrl');
  String get approved => _get('approved');
  String get pendingApproval => _get('pendingApproval');
  String get providerId => _get('providerId');
  String get bookingsSummary => _get('bookingsSummary');
  String get daycareInfo => _get('daycareInfo');
  String get googleMapsLink => _get('googleMapsLink');
  String get publicVisibility => _get('publicVisibility');
  String get preview => _get('preview');
  String get description => _get('description');
  String get clientNote => _get('clientNote');
  String get bookingRejected => _get('bookingRejected');
  String get bookingUpdated => _get('bookingUpdated');

  // Adopt module translations
  String get adoptDiscussions => _get('adoptDiscussions');
  String get adoptAdopter => _get('adoptAdopter');
  String get adoptCreate => _get('adoptCreate');
  String get adoptNoAds => _get('adoptNoAds');
  String get adoptErrorLoading => _get('adoptErrorLoading');
  String get adoptHeader => _get('adoptHeader');
  String get adoptSearching => _get('adoptSearching');
  String get adoptNoAdsTitle => _get('adoptNoAdsTitle');
  String get adoptNoAdsDesc => _get('adoptNoAdsDesc');
  String get adoptRefresh => _get('adoptRefresh');
  String get adoptRequestSent => _get('adoptRequestSent');
  String get adoptPassed => _get('adoptPassed');
  String get adoptOwnPost => _get('adoptOwnPost');
  String get adoptQuotaReached => _get('adoptQuotaReached');
  String get adoptQuotaReachedToday => _get('adoptQuotaReachedToday');
  String get adoptInvalidRequest => _get('adoptInvalidRequest');
  String get adoptTooManyRequests => _get('adoptTooManyRequests');
  String get adoptServerUnavailable => _get('adoptServerUnavailable');
  String get adoptError => _get('adoptError');
  String get adoptDog => _get('adoptDog');
  String get adoptCat => _get('adoptCat');
  String get adoptRabbit => _get('adoptRabbit');
  String get adoptBird => _get('adoptBird');
  String get adoptOther => _get('adoptOther');
  String get adoptMale => _get('adoptMale');
  String get adoptFemale => _get('adoptFemale');
  String get adoptMonths => _get('adoptMonths');
  String get adoptYears => _get('adoptYears');
  String get adoptYear => _get('adoptYear');
  String get adoptAdopted => _get('adoptAdopted');
  String get adoptRequestAccepted => _get('adoptRequestAccepted');
  String get adoptRequestRejected => _get('adoptRequestRejected');
  String get adoptConversationDeleted => _get('adoptConversationDeleted');
  String get adoptMessages => _get('adoptMessages');
  String get adoptNews => _get('adoptNews');
  String get adoptNew => _get('adoptNew');
  String get adoptNewRequests => _get('adoptNewRequests');
  String get adoptConversations => _get('adoptConversations');
  String get adoptNoMessages => _get('adoptNoMessages');
  String get adoptNoMessagesDesc => _get('adoptNoMessagesDesc');
  String get adoptLoadingError => _get('adoptLoadingError');
  String get adoptRetry => _get('adoptRetry');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['fr', 'en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
