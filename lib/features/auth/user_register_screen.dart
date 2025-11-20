// lib/features/auth/user_register_screen.dart
// Inscription CLIENT en 3 étapes :
// 1) Nom / Prénom
// 2) Email / Mot de passe / Téléphone (register ici avec vérif email)
// 3) Photo de profil (optionnelle, "Ignorer") puis -> /onboard/pet

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session_controller.dart';
import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);

class UserRegisterScreen extends ConsumerStatefulWidget {
  const UserRegisterScreen({super.key});
  @override
  ConsumerState<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends ConsumerState<UserRegisterScreen> {
  // Champs
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _pass      = TextEditingController();
  final _phone     = TextEditingController();

  // UI
  int _step = 0; // 0: noms, 1: email/mdp/tel (register), 2: avatar (optionnel)
  bool _loading = false;
  bool _obscure = true;
  bool _registered = false; // éviter de double-register

  // Erreurs
  String? _errFirst, _errLast, _errEmail, _errPass, _errPhone;

  // Avatar (étape 3)
  File? _avatarFile;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ---- Helpers validation
  bool _isValidEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) =>
      s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));
  bool _isValidPhone(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return d.length >= 8 && d.length <= 16;
  }

  bool _validateStep(int step) {
    setState(() {
      if (step == 0) {
        _errFirst = _firstName.text.trim().isEmpty ? 'Prénom requis' : null;
        _errLast  = _lastName.text.trim().isEmpty ? 'Nom requis' : null;
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : 'Email invalide';
        _errPass  = _isValidPassword(_pass.text) ? null : 'Mot de passe trop faible';
        _errPhone = _phone.text.trim().isEmpty
            ? 'Téléphone requis'
            : (_isValidPhone(_phone.text) ? null : 'Téléphone invalide');
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPhone == null;
    return true;
  }

  Future<void> _next() async {
    // Validation de l’étape courante
    if (!_validateStep(_step)) return;

    // À l’étape 1, on tente le register pour vérifier l’email tout de suite
    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier)
            .register(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          // Email déjà pris
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) {
            setState(() { _errEmail = 'Email déjà utilisé'; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cet email est déjà utilisé.')),
            );
            return; // rester sur l’étape 1
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(sessionProvider).error ?? 'Inscription impossible')),
          );
          return;
        }
        _registered = true; // tokens OK maintenant
        // Tout de suite après l’inscription, on pousse le nom/prénom/téléphone
        try {
          await ref.read(apiProvider).updateMe(
            firstName: _firstName.text.trim(),
            lastName : _lastName.text.trim(),
            phone    : _phone.text.trim(),
          );
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final msg = (e.response?.data is Map)
              ? (e.response?.data['message']?.toString() ?? '')
              : (e.message ?? '');
          if (status == 409 || msg.toLowerCase().contains('phone')) {
            setState(() { _errPhone = 'Téléphone déjà utilisé'; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ce numéro est déjà utilisé.')),
            );
            return; // rester sur l’étape 1 pour corriger
          }
          rethrow;
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    // Passer à l’étape suivante
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  // Étape 3 : avatar optionnel
  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    setState(() => _avatarFile = File(x.path));
  }

  Future<void> _finish({required bool skip}) async {
    // Si l’utilisateur ignore la photo, on passe direct à l’ajout d’un animal
    if (skip || _avatarFile == null) {
      if (!mounted) return;
      context.go('/onboard/pet');
      return;
    }

    // Sinon, upload + meUpdate(photoUrl)
    setState(() => _uploadingAvatar = true);
    try {
      final api = ref.read(apiProvider);
      await api.ensureAuth();

      String url = await api.uploadLocalFile(_avatarFile!, folder: 'avatar');
      await api.meUpdate(photoUrl: url);
      if (!mounted) return;
      context.go('/onboard/pet');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload avatar échoué: $e')),
      );
      // On n’empêche pas la suite : on va quand même vers l’ajout animal
      context.go('/onboard/pet');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Créer un compte'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStep(),
              ),
            ),
            const SizedBox(height: 8),
            _DotsIndicator(current: _step, total: 3),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _loading ? null : () => setState(() => _step -= 1),
                    child: const Text('Précédent'),
                  ),
                const Spacer(),
                if (_step < 2)
                  FilledButton(
                    onPressed: _loading ? null : _next,
                    style: FilledButton.styleFrom(backgroundColor: _coral, foregroundColor: Colors.white),
                    child: Text(_loading ? '...' : 'Suivant'),
                  )
                else
                  Row(
                    children: [
                      TextButton(
                        onPressed: _uploadingAvatar ? null : () => _finish(skip: true),
                        child: const Text('Ignorer'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _uploadingAvatar ? null : () => _finish(skip: false),
                        style: FilledButton.styleFrom(backgroundColor: _coral, foregroundColor: Colors.white),
                        child: Text(_uploadingAvatar ? '...' : 'Terminer'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return _centeredForm([
        _label('Prénom'),
        _input(_firstName, errorText: _errFirst),
        const SizedBox(height: 12),
        _label('Nom'),
        _input(_lastName, errorText: _errLast),
      ], key: const ValueKey('step0'));
    }

    if (_step == 1) {
      return _centeredForm([
        _label('Adresse email'),
        _input(_email, keyboard: TextInputType.emailAddress, errorText: _errEmail),
        const SizedBox(height: 12),
        _label('Mot de passe'),
        TextField(
          controller: _pass,
          obscureText: _obscure,
          decoration: InputDecoration(
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            isDense: true,
            errorText: _errPass,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            ),
            helperText: 'Min. 8 caractères, avec MAJUSCULE et minuscule',
          ),
        ),
        const SizedBox(height: 12),
        _label('Téléphone'),
        _input(_phone, keyboard: TextInputType.phone, errorText: _errPhone),
        const SizedBox(height: 6),
        Text(
          'Nous vérifions l’email et créons le compte à cette étape.',
          style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12),
        ),
      ], key: const ValueKey('step1'));
    }

    // Étape 2 : Avatar optionnel
    return _avatarStep(key: const ValueKey('step2'));
  }

  // ---- Étape 3 (avatar)
  Widget _avatarStep({Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Photo de profil (optionnel)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white,
                      backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                      child: _avatarFile == null ? const Icon(Icons.person, size: 42, color: Colors.black38) : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _uploadingAvatar ? null : _pickAvatar,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Choisir une photo'),
                        ),
                        if (_avatarFile != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _uploadingAvatar ? null : () => setState(() => _avatarFile = null),
                            icon: const Icon(Icons.close),
                            label: const Text('Retirer'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous pouvez ignorer cette étape et ajouter une photo plus tard.',
                      style: TextStyle(color: Colors.black.withOpacity(.6), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- UI helpers
  Widget _centeredForm(List<Widget> children, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SizedBox(height: 8), ...children],
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)),
      );

  Widget _input(
    TextEditingController c, {
    TextInputType? keyboard,
    String? errorText,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        errorText: errorText,
      ),
    );
  }
}

// -- petits ronds d’étapes --
class _DotsIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _DotsIndicator({required this.current, required this.total});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.black87 : Colors.black26,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
