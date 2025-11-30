import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import '../features/home/home_screen.dart' show resetHomeSessionFlags;

class SessionState {
  final Map<String, dynamic>? user; // { id, email, role, ... }
  final bool loading;
  final String? error;
  final bool isCompletingProRegistration; // Flag pour bloquer les redirections pendant l'inscription PRO
  final bool bootstrapped; // ✅ True quand le bootstrap initial est termine
  final String? providerType; // ✅ 'vet', 'daycare', 'petshop' pour les PRO

  const SessionState({
    this.user,
    this.loading = false,
    this.error,
    this.isCompletingProRegistration = false,
    this.bootstrapped = false,
    this.providerType,
  });

  SessionState copyWith({
    Map<String, dynamic>? user,
    bool? loading,
    String? error,
    bool? isCompletingProRegistration,
    bool? bootstrapped,
    String? providerType,
  }) =>
      SessionState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: error,
        isCompletingProRegistration: isCompletingProRegistration ?? this.isCompletingProRegistration,
        bootstrapped: bootstrapped ?? this.bootstrapped,
        providerType: providerType ?? this.providerType,
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
        final role = (me['role'] ?? '').toString().toUpperCase();

        // ✅ Si PRO, recuperer le type de provider
        String? provType;
        if (role == 'PRO') {
          try {
            final prov = await api.myProvider();
            if (prov != null) {
              provType = _detectProviderType(prov);
            }
          } catch (_) {
            // Ignorer si erreur - on redirigera vers /pro/home par defaut
          }
        }

        state = state.copyWith(user: me, bootstrapped: true, providerType: provType);
        return; // ✅ Bootstrap reussi avec user
      } catch (_) {
        // token invalide — rester déconnecté
      }
    }
    // ✅ Bootstrap termine (sans user connecte)
    state = state.copyWith(bootstrapped: true);
  }

  /// Detecte le type de provider (vet, daycare, petshop)
  String _detectProviderType(Map<String, dynamic> prov) {
    // ✅ Verifier specialties.kind (utilisé par login_screen)
    final specialties = prov['specialties'];
    if (specialties is Map) {
      final kind = (specialties['kind'] ?? '').toString().toLowerCase();
      if (kind == 'daycare' || kind == 'garderie') return 'daycare';
      if (kind == 'petshop' || kind == 'shop') return 'petshop';
      if (kind.isNotEmpty) return kind;
    }

    // Verifier les champs specifiques
    if (prov['isDaycare'] == true) return 'daycare';
    if (prov['isPetshop'] == true) return 'petshop';

    // Verifier le champ type
    final t = (prov['type'] ?? prov['providerType'] ?? '').toString().toLowerCase();
    if (t.contains('daycare') || t.contains('garderie')) return 'daycare';
    if (t.contains('petshop') || t.contains('shop')) return 'petshop';

    // Par defaut: vet
    return 'vet';
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final api = ref.read(apiProvider);
      await api.login(email: email, password: password);
      final me = await api.me();
      final role = (me['role'] ?? '').toString().toUpperCase();

      // ✅ Si PRO, recuperer le type de provider
      String? provType;
      if (role == 'PRO') {
        try {
          final prov = await api.myProvider();
          if (prov != null) {
            provType = _detectProviderType(prov);
          }
        } catch (_) {
          // Ignorer si erreur - on redirigera vers /pro/home par defaut
        }
      }

      state = state.copyWith(user: me, loading: false, bootstrapped: true, providerType: provType);
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

/// Helper pour determiner la route home selon le role et le type de provider
String getHomeRouteForSession(SessionState session) {
  final user = session.user;
  if (user == null) return '/gate';

  final role = (user['role'] ?? 'USER').toString().toUpperCase();

  if (role == 'ADMIN') return '/admin/hub';

  if (role == 'PRO') {
    final provType = session.providerType ?? 'vet';
    return switch (provType) {
      'daycare' => '/daycare/home',
      'petshop' => '/petshop/home',
      _ => '/pro/home',
    };
  }

  return '/home';
}
