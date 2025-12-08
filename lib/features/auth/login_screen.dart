// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/session_controller.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../adopt/adoption_pet_creation_dialog.dart';

class AuthLoginScreen extends ConsumerStatefulWidget {
  final String asRole; // 'user' | 'pro'
  const AuthLoginScreen({super.key, required this.asRole});

  @override
  ConsumerState<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends ConsumerState<AuthLoginScreen> {
  final _id = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  String? _errId;
  String? _errPass;
  String? _authError;

  static const bool _DEV_AUTO_REGISTER_ON_401 = false;

  @override
  void initState() {
    super.initState();
    // Prefill de test
    if (widget.asRole == 'pro') {
      _id.text = 'pro1@vethome.local';
    } else {
      _id.text = 'user1@vethome.local';
    }
    _pass.text = 'pass1234';
  }

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    return re.hasMatch(s.trim());
  }

  bool _isValidPhoneLike(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.length >= 8 && digits.length <= 16;
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _errId = null;
      _errPass = null;

      final id = _id.text.trim();
      if (id.isEmpty || (!_isValidEmail(id) && !_isValidPhoneLike(id))) {
        _errId = l10n.errorInvalidEmail;
      }
      if (_pass.text.isEmpty) {
        _errPass = l10n.errorPasswordRequired;
      }
    });
    return _errId == null && _errPass == null;
  }

  Future<bool> _tryLogin(String email, String pass) async {
    return await ref.read(sessionProvider.notifier).login(email, pass);
  }

  Map<String, dynamic>? _unwrapProvider(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map && raw.containsKey('data')) {
      final d = raw['data'];
      if (d == null) return null;
      if (d is Map && d.isEmpty) return null;
      return (d is Map) ? Map<String, dynamic>.from(d) : null;
    }
    if (raw is Map && raw.isEmpty) return null;
    return (raw is Map) ? Map<String, dynamic>.from(raw) : null;
  }

  bool _isRejected(Map<String, dynamic>? prov) {
    if (prov == null) return false;
    final v = prov['rejectedAt'];
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    return true;
  }

  String _providerKind(Map<String, dynamic>? prov) {
    if (prov == null) return '';
    final s = prov['specialties'];
    if (s is Map) {
      final k = s['kind'];
      if (k is String) return k.toLowerCase();
    }
    return '';
  }

  Future<Map<String, dynamic>?> _safeMyProvider() async {
    final api = ref.read(apiProvider);
    await api.ensureAuth();
    try {
      final raw = await api.myProvider();
      return _unwrapProvider(raw);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _showDetectedProDialogAndRedirect() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.proAccountDetected),
        content: Text(l10n.proAccountMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sessionProvider.notifier).logout();
              if (!mounted) return;
              context.go('/auth/login?as=pro');
            },
            child: Text(l10n.goToPro),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetectedClientDialogAndRedirect() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clientAccountDetected),
        content: Text(l10n.clientAccountMessage),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sessionProvider.notifier).logout();
              if (!mounted) return;
              context.go('/auth/login?as=user');
            },
            child: Text(l10n.goToIndividual),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              // ➜ Utilise les routes nommées pour register
              context.pushNamed('registerPro');
            },
            child: Text(l10n.createProAccount),
          ),
        ],
      ),
    );
  }

  Future<void> _incorrectAndLogout() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() => _authError = l10n.errorIncorrectCredentials);
    await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorFixFields)),
      );
      return;
    }

    setState(() {
      _authError = null;
      _loading = true;
    });

    final typed = _id.text.trim();
    final pass = _pass.text;

    var ok = await _tryLogin(typed, pass);

    if (!ok) {
      final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
      final was401 = err.contains('401') || err.contains('unauthorized') || err.contains('invalid');

      if (was401 && _isValidEmail(typed)) {
        final lower = typed.toLowerCase();
        if (lower != typed) {
          ok = await _tryLogin(lower, pass);
        }
      }

      if (!ok && was401 && _DEV_AUTO_REGISTER_ON_401) {
        final regOk = await ref.read(sessionProvider.notifier).register(typed, pass);
        if (regOk) ok = await _tryLogin(typed, pass);
      }
    }

    if (!mounted) return;

    if (ok) {
      await ref.read(sessionProvider.notifier).refreshMe();
    }

    setState(() => _loading = false);

    if (!ok) {
      setState(() => _authError = l10n.errorIncorrectCredentials);
      return;
    }

    // ---------- ROUTAGE ----------
    final me = ref.read(sessionProvider).user;
    final role = ((me?['role'] as String?) ?? 'USER').toUpperCase();

    if (role == 'ADMIN') {
      context.go('/admin/dashboard');
      return;
    }

    if (widget.asRole == 'pro') {
      Map<String, dynamic>? prov;
      try {
        prov = await _safeMyProvider();
      } on DioException catch (e) {
        final msg = (e.response?.data is Map)
            ? (e.response?.data['message']?.toString() ?? e.message ?? l10n.error)
            : (e.message ?? l10n.error);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }

      if (prov == null) {
        await _showDetectedClientDialogAndRedirect();
        return;
      }

      if (_isRejected(prov)) {
        if (!mounted) return;
        context.go('/pro/application/rejected');
        return;
      }

      final status = (prov['status'] ?? prov['state'] ?? '').toString().toUpperCase();
      final isApproved = (prov['isApproved'] == true) ||
          (prov['approved'] == true) ||
          (status == 'APPROVED');

      if (isApproved) {
        final kind = _providerKind(prov);
        final String target = switch (kind) {
          'daycare' => '/daycare/home',
          'petshop' => '/petshop/home',
          _ => '/pro/home',
        };
        if (!mounted) return;
        context.go(target);
      } else {
        if (!mounted) return;
        context.go('/pro/application/submitted');
      }
      return;
    }

    // Flux particulier
    if (widget.asRole == 'user') {
      try {
        final prov = await _safeMyProvider();
        if (prov != null) {
          if (_isRejected(prov)) {
            await _incorrectAndLogout();
            return;
          }
          await _showDetectedProDialogAndRedirect();
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      context.go('/home');

      // Vérifier les adoptions pendantes après login
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPendingAdoptions();
        }
      });
      return;
    }

    // fallback
    if (role == 'PRO') {
      context.go('/pro/home');
    } else {
      context.go('/home');
    }
  }

  Future<void> _checkPendingAdoptions() async {
    try {
      await checkAndShowAdoptionDialog(context, ref);
    } catch (e) {
      // Ignorer les erreurs silencieusement
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _authError = null;
      _loading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final api = ref.read(apiProvider);
      await api.googleAuth(
        googleId: account.id,
        email: account.email,
        firstName: account.displayName?.split(' ').first,
        lastName: account.displayName?.split(' ').skip(1).join(' '),
        photoUrl: account.photoUrl,
      );

      // Rafraîchir les données utilisateur
      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;
      setState(() => _loading = false);

      // Même logique de routage que _submit
      final me = ref.read(sessionProvider).user;
      final role = ((me?['role'] as String?) ?? 'USER').toUpperCase();

      if (role == 'ADMIN') {
        context.go('/admin/dashboard');
        return;
      }

      if (widget.asRole == 'pro') {
        Map<String, dynamic>? prov;
        try {
          prov = await _safeMyProvider();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorProfileRetrieval)),
          );
          return;
        }

        if (prov == null) {
          await _showDetectedClientDialogAndRedirect();
          return;
        }

        if (_isRejected(prov)) {
          if (!mounted) return;
          context.go('/pro/application/rejected');
          return;
        }

        final status = (prov['status'] ?? prov['state'] ?? '').toString().toUpperCase();
        final isApproved = (prov['isApproved'] == true) ||
            (prov['approved'] == true) ||
            (status == 'APPROVED');

        if (isApproved) {
          final kind = _providerKind(prov);
          final String target = switch (kind) {
            'daycare' => '/daycare/home',
            'petshop' => '/petshop/home',
            _ => '/pro/home',
          };
          if (!mounted) return;
          context.go(target);
        } else {
          if (!mounted) return;
          context.go('/pro/application/submitted');
        }
        return;
      }

      // Flux particulier
      if (widget.asRole == 'user') {
        try {
          final prov = await _safeMyProvider();
          if (prov != null) {
            if (_isRejected(prov)) {
              await _incorrectAndLogout();
              return;
            }
            await _showDetectedProDialogAndRedirect();
            return;
          }
        } catch (_) {}
        if (!mounted) return;

        // Vérifier si le profil est complet (prénom, nom, téléphone)
        final hasFirstName = me?['firstName']?.toString().trim().isNotEmpty ?? false;
        final hasLastName = me?['lastName']?.toString().trim().isNotEmpty ?? false;
        final hasPhone = me?['phone']?.toString().trim().isNotEmpty ?? false;

        if (!hasFirstName || !hasLastName || !hasPhone) {
          // Profil incomplet -> rediriger vers complétion
          context.go('/auth/profile-completion');
          return;
        }

        context.go('/home');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _checkPendingAdoptions();
          }
        });
        return;
      }

      // fallback
      if (role == 'PRO') {
        context.go('/pro/home');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _authError = '${l10n.errorGoogleSignIn}: ${e.toString()}';
      });
    }
  }

  void _goToRegister() {
    // 🔧 FIX: routes nommées pour éviter 404
    if (widget.asRole == 'pro') {
      context.pushNamed('registerPro');   // doît exister dans ton GoRouter
    } else {
      context.pushNamed('registerUser');  // doît exister dans ton GoRouter
    }
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(l10n.login),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          const SizedBox(height: 12),

          _LabeledField(
            label: l10n.emailOrPhone,
            controller: _id,
            keyboard: TextInputType.emailAddress,
            errorText: _errId,
            onChanged: (_) => setState(() => _authError = null),
          ),

          _LabeledField(
            label: l10n.password,
            controller: _pass,
            obscure: _obscure,
            errorText: _errPass,
            onChanged: (_) => setState(() => _authError = null),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            ),
          ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => context.push('/auth/forgot?as=${widget.asRole}'),
              child: Text(
                l10n.forgotPassword,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (_authError != null) ...[
            const SizedBox(height: 10),
            Text(
              _authError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: coral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? '...' : l10n.confirm),
            ),
          ),

          // Google Sign-In uniquement pour les utilisateurs (pas les pros)
          if (widget.asRole == 'user') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[400])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.or, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Divider(color: Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  foregroundColor: Colors.black87,
                ),
                onPressed: _loading ? null : _handleGoogleSignIn,
                icon: Image.network(
                  'https://www.google.com/favicon.ico',
                  height: 24,
                  width: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                ),
                label: Text(l10n.continueWithGoogle),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${l10n.noAccount} '),
                GestureDetector(
                  onTap: _goToRegister, // ✅ utilise les routes nommées
                  child: Text(
                    l10n.signUp,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboard;
  final String? errorText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboard,
    this.errorText,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              isDense: true,
              errorText: errorText,
              suffixIcon: suffixIcon,
            ),
          ),
        ],
      ),
    );
  }
}
