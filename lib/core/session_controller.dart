import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import '../features/home/home_screen.dart' show resetHomeSessionFlags;

class SessionState {
  final Map<String, dynamic>? user; // { id, email, role, ... }
  final bool loading;
  final String? error;
  final bool isCompletingProRegistration; // Flag pour bloquer les redirections pendant l'inscription PRO
  final bool bootstrapped; // ✅ True quand le bootstrap initial est termine

  const SessionState({
    this.user,
    this.loading = false,
    this.error,
    this.isCompletingProRegistration = false,
    this.bootstrapped = false,
  });

  SessionState copyWith({
    Map<String, dynamic>? user,
    bool? loading,
    String? error,
    bool? isCompletingProRegistration,
    bool? bootstrapped,
  }) =>
      SessionState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: error,
        isCompletingProRegistration: isCompletingProRegistration ?? this.isCompletingProRegistration,
        bootstrapped: bootstrapped ?? this.bootstrapped,
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
        state = state.copyWith(user: me, bootstrapped: true);
        return; // ✅ Bootstrap reussi avec user
      } catch (_) {
        // token invalide — rester déconnecté
      }
    }
    // ✅ Bootstrap termine (sans user connecte)
    state = state.copyWith(bootstrapped: true);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await ref.read(apiProvider).login(email: email, password: password);
      final me = await ref.read(apiProvider).me();
      state = state.copyWith(user: me, loading: false, bootstrapped: true);
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
      state = state.copyWith(user: me, loading: false, bootstrapped: true);
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
    // ✅ Garder bootstrapped = true pour eviter le loading infini
    state = const SessionState(bootstrapped: true);
    // Reset les flags de session du home screen
    resetHomeSessionFlags();
  }

  /// Active/désactive le flag isCompletingProRegistration
  /// Ce flag empêche le router de rediriger pendant la création du profil PRO
  void setCompletingProRegistration(bool value) {
    state = state.copyWith(isCompletingProRegistration: value);
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
