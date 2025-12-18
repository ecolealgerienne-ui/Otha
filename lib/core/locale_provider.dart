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
      // Status descriptions
      'pendingDescription': 'En attente de confirmation par la garderie',
      'confirmedDescription': 'Votre réservation est confirmée',
      'inProgressDescription': 'Votre animal est actuellement en garderie',
      'completedDescription': 'Garde terminée avec succès',
      'cancelledDescription': 'Cette réservation a été annulée',
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
      // Status descriptions
      'pendingDescription': 'Awaiting confirmation from the daycare',
      'confirmedDescription': 'Your booking is confirmed',
      'inProgressDescription': 'Your pet is currently at the daycare',
      'completedDescription': 'Care completed successfully',
      'cancelledDescription': 'This booking has been cancelled',
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
      // Status descriptions
      'pendingDescription': 'في انتظار تأكيد الحضانة',
      'confirmedDescription': 'تم تأكيد حجزك',
      'inProgressDescription': 'حيوانك حالياً في الحضانة',
      'completedDescription': 'تمت الرعاية بنجاح',
      'cancelledDescription': 'تم إلغاء هذا الحجز',
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
  String get understood => _get('understood');
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
  // Status descriptions
  String get pendingDescription => _get('pendingDescription');
  String get confirmedDescription => _get('confirmedDescription');
  String get inProgressDescription => _get('inProgressDescription');
  String get completedDescription => _get('completedDescription');
  String get cancelledDescription => _get('cancelledDescription');
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
