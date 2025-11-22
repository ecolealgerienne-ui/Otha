import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';

class SessionState {
  final Map<String, dynamic>? user; // { id, email, role, ... }
  final bool loading;
  final String? error;
  final bool isCompletingProRegistration; // Flag pour bloquer les redirections pendant l'inscription PRO

  const SessionState({
    this.user,
    this.loading = false,
    this.error,
    this.isCompletingProRegistration = false,
  });

  SessionState copyWith({
    Map<String, dynamic>? user,
    bool? loading,
    String? error,
    bool? isCompletingProRegistration,
  }) =>
      SessionState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: error,
        isCompletingProRegistration: isCompletingProRegistration ?? this.isCompletingProRegistration,
      );
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(bootstrap);
    return const SessionState();
  }

  Future<void> bootstrap() async {
    final api = ref.read(apiProvider);
    final token = await api.getStoredToken();
    if (token != null && token.isNotEmpty) {
      await api.setToken(token);
      try {
        final me = await api.me();
        state = state.copyWith(user: me);
      } catch (_) {
        // token invalide — rester déconnecté
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await ref.read(apiProvider).login(email: email, password: password);
      final me = await ref.read(apiProvider).me();
      state = state.copyWith(user: me, loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  /// Inscription puis login immédiat (pour que les écrans suivants aient un token)
  Future<bool> register(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await ref.read(apiProvider).register(email: email, password: password);
      await ref.read(apiProvider).login(email: email, password: password);
      final me = await ref.read(apiProvider).me();
      state = state.copyWith(user: me, loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  /// Inscription SANS login automatique (pour les wizards pro)
  Future<bool> registerOnly(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await ref.read(apiProvider).register(email: email, password: password);
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> refreshMe() async {
    try {
      final me = await ref.read(apiProvider).me();
      state = state.copyWith(user: me);
    } catch (_) {}
  }

  Future<void> logout() async {
    await ref.read(apiProvider).setToken(null);
    state = const SessionState();
  }

  /// Active/désactive le flag isCompletingProRegistration
  /// Ce flag empêche le router de rediriger pendant la création du profil PRO
  void setCompletingProRegistration(bool value) {
    state = state.copyWith(isCompletingProRegistration: value);
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
