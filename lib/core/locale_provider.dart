import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Langues supportées
enum AppLanguage {
  french('fr', 'Français', '🇫🇷'),
  english('en', 'English', '🇬🇧');

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
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  static const String _key = 'app_locale';

  LocaleNotifier() : super(const Locale('fr')) {
    _loadSavedLocale();
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
