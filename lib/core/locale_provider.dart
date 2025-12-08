import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
