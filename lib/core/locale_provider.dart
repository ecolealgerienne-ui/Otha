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
