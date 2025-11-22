// lib/features/start/start_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/api.dart';
import '../../core/session_controller.dart';

enum StartVariant { user, pro }

class StartScreen extends ConsumerStatefulWidget {
  final StartVariant variant;
  const StartScreen({super.key, required this.variant});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  bool _loading = false;

  String get _bg =>
      widget.variant == StartVariant.user ? 'assets/images/fond_d.png' : 'assets/images/fond_g.png';

  String get _title => widget.variant == StartVariant.user
      ? 'Prenez soin de\nvotre compagnon'
      : 'Bienvenue\nsur vethome';

  String get _subtitle => widget.variant == StartVariant.user
      ? 'vos animaux méritent le meilleur !'
      : 'Parce que vos soins font toute la différence';

  String get _loginQuery => widget.variant == StartVariant.user ? 'user' : 'pro';

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);

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

      // Vérifier si le profil est complet
      final user = ref.read(sessionProvider).user;
      final hasFirstName = (user?['firstName']?.toString().trim().isNotEmpty) ?? false;
      final hasLastName = (user?['lastName']?.toString().trim().isNotEmpty) ?? false;
      final hasPhone = (user?['phone']?.toString().trim().isNotEmpty) ?? false;

      if (!hasFirstName || !hasLastName || !hasPhone) {
        // Profil incomplet -> rediriger vers complétion
        context.go('/auth/profile-completion');
      } else {
        // Profil complet -> rediriger vers home
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la connexion Google: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond photo
          Image.asset(_bg, fit: BoxFit.cover),

          // Légère superposition sombre pour lisibilité
          Container(color: Colors.black.withOpacity(0.15)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo en haut
                  Row(
                    children: [
                      Image.asset('assets/images/logo_vethome.png', height: 36),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),

                  const Spacer(),

                  // Carte "verre dépoli"
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4A4A4A),
                                shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Se connecter (corail)
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: coral,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 6,
                                  shadowColor: Colors.black45,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () {
                                  // Le login lit encore ?as=user|pro
                                  context.push('/auth/login?as=$_loginQuery');
                                },
                                child: const Text('Se connecter'),
                              ),
                            ),

                            // Différent pour user et pro
                            if (widget.variant == StartVariant.user) ...[
                              // Pour les utilisateurs : Google Sign-In + lien inscription
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Expanded(child: Divider(thickness: 1.0)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'Ou',
                                      style: TextStyle(
                                        color: Colors.black.withOpacity(0.55),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider(thickness: 1.0)),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Bouton Google Sign-In
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: Colors.black.withOpacity(0.15)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _handleGoogleSignIn,
                                  icon: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.transparent,
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  label: const Text(
                                    'Se connecter avec Google',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              // Lien inscription pour user
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Pas de compte ? ',
                                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                                  ),
                                  InkWell(
                                    onTap: () => context.pushNamed('registerUser'),
                                    child: const Text(
                                      "S'inscrire",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Pour les pros : juste le bouton S'inscrire
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: coral, width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: () => context.pushNamed('registerPro'),
                                  child: const Text(
                                    "S'inscrire",
                                    style: TextStyle(color: coral),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
