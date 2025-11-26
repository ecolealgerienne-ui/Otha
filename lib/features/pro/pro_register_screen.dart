
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/session_controller.dart';
import '../../core/api.dart';

const _coral = Color(0xFFF36C6C);

/* ========================= Helpers front ========================= */

bool _isValidHttpUrl(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  return RegExp(r'^(https?://)', caseSensitive: false).hasMatch(t);
}

/* ========================= Écran catégories ========================= */

class ProRegisterScreen extends ConsumerWidget {
  const ProRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Créer un compte professionnel'),
      ),
      body: _buildProCategoriesPage(context),
    );
  }

  Widget _buildProCategoriesPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Choisissez votre catégorie',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _CategoryCard(
                  color: _coral,
                  icon: Icons.local_hospital_outlined,
                  label: 'Vétérinaire',
                  onTap: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _VetWizard3Steps()),
                    );
                    if (ok == true && context.mounted) context.go('/pro/application/submitted');
                  },
                ),
                _CategoryCard(
                  color: Colors.black87,
                  icon: Icons.pets_outlined,
                  label: 'Garderie',
                  onTap: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _DaycareWizard3Steps()),
                    );
                    if (ok == true && context.mounted) context.go('/pro/application/submitted');
                  },
                ),
                _CategoryCard(
                  color: Colors.black54,
                  icon: Icons.storefront_outlined,
                  label: 'Animalerie',
                  onTap: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PetshopWizard3Steps()),
                    );
                    if (ok == true && context.mounted) context.go('/pro/application/submitted');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CategoryCard({required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

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
          decoration: BoxDecoration(color: active ? Colors.black87 : Colors.black26, shape: BoxShape.circle),
        );
      }),
    );
  }
}

/* ========================= Wizard VÉTÉRINAIRE ========================= */

class _VetWizard3Steps extends ConsumerStatefulWidget {
  const _VetWizard3Steps();
  @override
  ConsumerState<_VetWizard3Steps> createState() => _VetWizard3StepsState();
}

class _VetWizard3StepsState extends ConsumerState<_VetWizard3Steps> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _mapsUrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  // Carte AVN (recto-verso)
  File? _avnFront;
  File? _avnBack;
  String? _avnFrontUrl;
  String? _avnBackUrl;

  // Photo de profil
  File? _profilePhoto;
  String? _profilePhotoUrl;

  final _picker = ImagePicker();

  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone, _errAddress, _errMapsUrl, _errAvn;

  bool _isValidEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) => s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));
  bool _isValidPhone(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return d.length >= 8 && d.length <= 16;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _phone.dispose();
    _address.dispose();
    _mapsUrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        if (first.isEmpty) {
          _errFirst = 'Prénom requis';
        } else if (first.length < 3) {
          _errFirst = 'Prénom: minimum 3 caractères';
        } else if (first.length > 15) {
          _errFirst = 'Prénom: maximum 15 caractères';
        } else {
          _errFirst = null;
        }
        if (last.isEmpty) {
          _errLast = 'Nom requis';
        } else if (last.length < 3) {
          _errLast = 'Nom: minimum 3 caractères';
        } else if (last.length > 15) {
          _errLast = 'Nom: maximum 15 caractères';
        } else {
          _errLast = null;
        }
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : 'Email invalide';
        _errPass = _isValidPassword(_pass.text) ? null : 'Mot de passe trop faible';
        if (_passConfirm.text.isEmpty) {
          _errPassConfirm = 'Confirmation requise';
        } else if (_passConfirm.text != _pass.text) {
          _errPassConfirm = 'Les mots de passe ne correspondent pas';
        } else {
          _errPassConfirm = null;
        }
        final phone = _phone.text.trim();
        if (phone.isEmpty) {
          _errPhone = 'Téléphone requis';
        } else if (!phone.startsWith('0')) {
          _errPhone = 'Le numéro doit commencer par 0';
        } else if (phone.length < 9 || phone.length > 10) {
          _errPhone = 'Le numéro doit contenir 9 ou 10 chiffres';
        } else {
          _errPhone = null;
        }
      } else if (step == 2) {
        _errAddress = _address.text.trim().isEmpty ? 'Adresse requise' : null;
        final mapsOk = _isValidHttpUrl(_mapsUrl.text);
        _errMapsUrl = mapsOk
            ? null
            : (_mapsUrl.text.trim().isEmpty ? 'Lien Google Maps requis' : 'URL invalide (http/https)');
      } else if (step == 3) {
        // Validation carte AVN (recto obligatoire, verso obligatoire)
        _errAvn = (_avnFront == null || _avnBack == null) ? 'Carte AVN recto-verso obligatoire' : null;
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    if (step == 2) return _errAddress == null && _errMapsUrl == null;
    if (step == 3) return _errAvn == null;
    return false;
  }

  Future<void> _next() async {
    if (!_validateStep(_step)) return;

    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier).registerOnly(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) {
            setState(() => _errEmail = 'Email déjà utilisé');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cet email est déjà utilisé.')));
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(sessionProvider).error ?? 'Inscription impossible')),
          );
          return;
        }
        _registered = true;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  Future<void> _submitFinal() async {
    if (!_validateStep(3)) return;
    setState(() => _loading = true);

    try {
      // IMPORTANT: Activer le flag pour bloquer les redirections du router
      ref.read(sessionProvider.notifier).setCompletingProRegistration(true);

      // Login d'abord (avec les identifiants de l'étape 1)
      final loginOk = await ref.read(sessionProvider.notifier).login(_email.text.trim(), _pass.text);
      if (!loginOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur de connexion')),
          );
        }
        return;
      }

      final api = ref.read(apiProvider);

      // Upload photo de profil (si présente)
      String? photoUrl;
      if (_profilePhoto != null) {
        try {
          photoUrl = await api.uploadLocalFile(_profilePhoto!, folder: 'avatars');
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload photo: $e')));
          // On continue même si l'upload photo échoue (optionnel)
        }
      }

      try {
        await api.updateMe(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          photoUrl: photoUrl,
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? '');
        if (status == 409 || msg.toLowerCase().contains('phone')) {
          setState(() {
            _errPhone = 'Téléphone déjà utilisé';
            _step = 1;
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce numéro est déjà utilisé.')));
          return;
        }
        rethrow;
      }

      final display = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      final displayName = display.isEmpty ? _email.text.split('@').first : display;

      final finalMaps = _mapsUrl.text.trim();
      if (finalMaps.isEmpty || !_isValidHttpUrl(finalMaps)) {
        setState(() {
          _errMapsUrl = finalMaps.isEmpty ? 'Lien Google Maps requis' : 'URL invalide (http/https)';
          _step = 2;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMapsUrl!)));
        return;
      }

      // Upload cartes AVN
      String? frontUrl, backUrl;
      if (_avnFront != null) {
        try {
          frontUrl = await api.uploadLocalFile(_avnFront!, folder: 'avn');
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload recto: $e')));
          return;
        }
      }
      if (_avnBack != null) {
        try {
          backUrl = await api.uploadLocalFile(_avnBack!, folder: 'avn');
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload verso: $e')));
          return;
        }
      }

      await api.upsertMyProvider(
        displayName: displayName,
        address: _address.text.trim(),
        specialties: {
          'kind': 'vet',
          'visible': true,
          'mapsUrl': finalMaps,
        },
        avnCardFront: frontUrl,
        avnCardBack: backUrl,
      );

      // Refresh user pour mettre à jour le role (user → provider)
      await ref.read(sessionProvider.notifier).refreshMe();

      // Déconnexion immédiate pour éviter la redirection automatique
      // L'utilisateur doit attendre l'approbation admin avant de pouvoir se connecter
      await ref.read(sessionProvider.notifier).logout();

      // Désactiver le flag (normalement déjà fait par logout, mais pour être sûr)
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? 'Erreur');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $msg')));
    } finally {
      if (mounted) setState(() => _loading = false);
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
        iconTheme: const IconThemeData(color: Colors.black87),
        title: null,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _buildStep())),
            const SizedBox(height: 8),
            _DotsIndicator(current: _step, total: 4),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_step > 0)
                  OutlinedButton(onPressed: _loading ? null : () => setState(() => _step -= 1), child: const Text('Précédent')),
                const Spacer(),
                FilledButton(onPressed: _loading ? null : (_step < 3 ? _next : _submitFinal), child: Text(_step < 3 ? 'Suivant' : 'Soumettre')),
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
        _label('Photo de profil (optionnelle)'),
        const SizedBox(height: 6),
        Center(
          child: GestureDetector(
            onTap: () => _pickProfilePhoto(),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: _profilePhoto != null ? FileImage(_profilePhoto!) : null,
              child: _profilePhoto == null
                  ? Icon(Icons.add_a_photo, size: 30, color: Colors.grey[600])
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _label('Prénom'),
        _input(_firstName, errorText: _errFirst, maxLength: 15),
        const SizedBox(height: 12),
        _label('Nom'),
        _input(_lastName, errorText: _errLast, maxLength: 15),
      ], key: const ValueKey('vet0'));
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
            suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility)),
            helperText: 'Min. 8 caractères avec une MAJUSCULE et une minuscule',
          ),
        ),
        const SizedBox(height: 12),
        _label('Confirmer le mot de passe'),
        TextField(
          controller: _passConfirm,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            isDense: true,
            errorText: _errPassConfirm,
            suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility)),
          ),
        ),
        const SizedBox(height: 12),
        _label('Téléphone'),
        _input(_phone, keyboard: TextInputType.phone, errorText: _errPhone, maxLength: 10),
      ], key: const ValueKey('vet1'));
    }

    if (_step == 2) {
      return _centeredForm([
        _label('Adresse du vétérinaire'),
        _input(_address, errorText: _errAddress),
        const SizedBox(height: 12),
        _label('Lien Google Maps (obligatoire)'),
        TextField(
          controller: _mapsUrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            isDense: true,
            errorText: _errMapsUrl,
            hintText: 'https://maps.google.com/...',
          ),
        ),
      ], key: const ValueKey('vet2'));
    }

    // Step 3: Upload carte AVN
    return _centeredForm([
      _label('Carte AVN (Attestation Vétérinaire Nationale)'),
      const SizedBox(height: 8),
      Text('Recto', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      _buildImagePicker(
        image: _avnFront,
        onTap: () => _pickImage(isBack: false),
        label: 'Téléverser recto',
      ),
      const SizedBox(height: 16),
      Text('Verso', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      _buildImagePicker(
        image: _avnBack,
        onTap: () => _pickImage(isBack: true),
        label: 'Téléverser verso',
      ),
      if (_errAvn != null) ...[
        const SizedBox(height: 12),
        Text(_errAvn!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ],
    ], key: const ValueKey('vet3'));
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
      if (image == null) return;

      setState(() {
        _profilePhoto = File(image.path);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _pickImage({required bool isBack}) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (image == null) return;

      setState(() {
        if (isBack) {
          _avnBack = File(image.path);
        } else {
          _avnFront = File(image.path);
        }
        _errAvn = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Widget _buildImagePicker({required File? image, required VoidCallback onTap, required String label}) {
    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(image, height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 16,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                onPressed: () => setState(() {
                  if (image == _avnFront) {
                    _avnFront = null;
                  } else {
                    _avnBack = null;
                  }
                }),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _centeredForm(List<Widget> children, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SizedBox(height: 8), ...children]),
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)));

  Widget _input(
    TextEditingController c, {
    bool obscure = false,
    TextInputType? keyboard,
    String? errorText,
    String? hintText,
    int? maxLength,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLength: maxLength,
      decoration: InputDecoration(
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        errorText: errorText,
        hintText: hintText,
        counterText: '',
      ),
    );
  }
}

/* ========================= Wizard GARDERIE ========================= */

class _DaycareWizard3Steps extends ConsumerStatefulWidget {
  const _DaycareWizard3Steps();
  @override
  ConsumerState<_DaycareWizard3Steps> createState() => _DaycareWizard3StepsState();
}

class _DaycareWizard3StepsState extends ConsumerState<_DaycareWizard3Steps> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();

  final _shopName = TextEditingController();
  final _address = TextEditingController();
  final _mapsUrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  final List<File> _daycareImages = [];
  final _picker = ImagePicker();

  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone, _errShop, _errAddress, _errMapsUrl, _errImages;

  bool _isValidEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) => s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));
  bool _isValidPhone(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return d.length >= 8 && d.length <= 16;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _phone.dispose();
    _shopName.dispose();
    _address.dispose();
    _mapsUrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        if (first.isEmpty) {
          _errFirst = 'Prénom requis';
        } else if (first.length < 3) {
          _errFirst = 'Prénom: minimum 3 caractères';
        } else if (first.length > 15) {
          _errFirst = 'Prénom: maximum 15 caractères';
        } else {
          _errFirst = null;
        }
        if (last.isEmpty) {
          _errLast = 'Nom requis';
        } else if (last.length < 3) {
          _errLast = 'Nom: minimum 3 caractères';
        } else if (last.length > 15) {
          _errLast = 'Nom: maximum 15 caractères';
        } else {
          _errLast = null;
        }
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : 'Email invalide';
        _errPass = _isValidPassword(_pass.text) ? null : 'Mot de passe trop faible';
        if (_passConfirm.text.isEmpty) {
          _errPassConfirm = 'Confirmation requise';
        } else if (_passConfirm.text != _pass.text) {
          _errPassConfirm = 'Les mots de passe ne correspondent pas';
        } else {
          _errPassConfirm = null;
        }
        final phone = _phone.text.trim();
        if (phone.isEmpty) {
          _errPhone = 'Téléphone requis';
        } else if (!phone.startsWith('0')) {
          _errPhone = 'Le numéro doit commencer par 0';
        } else if (phone.length < 9 || phone.length > 10) {
          _errPhone = 'Le numéro doit contenir 9 ou 10 chiffres';
        } else {
          _errPhone = null;
        }
      } else {
        _errShop = _shopName.text.trim().isEmpty ? 'Nom de la boutique requis' : null;
        _errAddress = _address.text.trim().isEmpty ? 'Adresse requise' : null;
        final mapsOk = _isValidHttpUrl(_mapsUrl.text);
        _errMapsUrl = mapsOk
            ? null
            : (_mapsUrl.text.trim().isEmpty ? 'Lien Google Maps requis' : 'URL invalide (http/https)');
        _errImages = _daycareImages.isEmpty ? 'Au moins 1 photo requise' : null;
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    return _errShop == null && _errAddress == null && _errMapsUrl == null && _errImages == null;
  }

  Future<void> _pickDaycareImage() async {
    if (_daycareImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() {
        _daycareImages.add(File(image.path));
        _errImages = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _removeDaycareImage(int index) {
    setState(() {
      _daycareImages.removeAt(index);
    });
  }

  Future<void> _next() async {
    if (!_validateStep(_step)) return;

    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier).registerOnly(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) {
            setState(() => _errEmail = 'Email déjà utilisé');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cet email est déjà utilisé.')));
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(sessionProvider).error ?? 'Inscription impossible')),
          );
          return;
        }
        _registered = true;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  Future<void> _submitFinal() async {
    if (!_validateStep(2)) return;
    setState(() => _loading = true);

    try {
      // IMPORTANT: Activer le flag pour bloquer les redirections du router
      ref.read(sessionProvider.notifier).setCompletingProRegistration(true);

      // Login d'abord (avec les identifiants de l'étape 1)
      final loginOk = await ref.read(sessionProvider.notifier).login(_email.text.trim(), _pass.text);
      if (!loginOk) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur de connexion')),
          );
        }
        return;
      }

      final api = ref.read(apiProvider);

      try {
        await api.updateMe(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
        );
      } on DioException catch (e) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        final status = e.response?.statusCode;
        final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? '');
        if (status == 409 || msg.toLowerCase().contains('phone')) {
          setState(() {
            _errPhone = 'Téléphone déjà utilisé';
            _step = 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce numéro est déjà utilisé.')));
          return;
        }
        rethrow;
      }

      final display = _shopName.text.trim().isEmpty ? _email.text.split('@').first : _shopName.text.trim();

      final finalMaps = _mapsUrl.text.trim();
      if (finalMaps.isEmpty || !_isValidHttpUrl(finalMaps)) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        setState(() {
          _errMapsUrl = finalMaps.isEmpty ? 'Lien Google Maps requis' : 'URL invalide (http/https)';
          _step = 2;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMapsUrl!)));
        return;
      }

      // Upload des photos de la garderie
      final List<String> imageUrls = [];
      for (int i = 0; i < _daycareImages.length; i++) {
        try {
          final url = await api.uploadLocalFile(_daycareImages[i], folder: 'daycare');
          imageUrls.add(url);
        } catch (e) {
          ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur upload photo ${i + 1}: $e')),
            );
          }
          return;
        }
      }

      await api.upsertMyProvider(
        displayName: display,
        address: _address.text.trim(),
        specialties: {
          'kind': 'daycare',
          'visible': true,
          'mapsUrl': finalMaps,
          'images': imageUrls,
        },
      );

      // Refresh user pour mettre à jour le role (user → provider)
      await ref.read(sessionProvider.notifier).refreshMe();

      // Déconnexion immédiate pour éviter la redirection automatique
      // L'utilisateur doit attendre l'approbation admin avant de pouvoir se connecter
      await ref.read(sessionProvider.notifier).logout();

      // Désactiver le flag (normalement déjà fait par logout, mais pour être sûr)
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? 'Erreur');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $msg')));
    } finally {
      if (mounted) setState(() => _loading = false);
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
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Inscription Garderie'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _buildStep())),
            const SizedBox(height: 8),
            _DotsIndicator(current: _step, total: 3),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_step > 0)
                  OutlinedButton(onPressed: _loading ? null : () => setState(() => _step -= 1), child: const Text('Précédent')),
                const Spacer(),
                FilledButton(onPressed: _loading ? null : (_step < 2 ? _next : _submitFinal), child: Text(_step < 2 ? 'Suivant' : 'Soumettre')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return _centeredForm([
        _label('Prénom'),
        _input(_firstName, errorText: _errFirst, maxLength: 15),
        const SizedBox(height: 12),
        _label('Nom'),
        _input(_lastName, errorText: _errLast, maxLength: 15),
      ], key: const ValueKey('day0'));
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
            suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility)),
            helperText: 'Min. 8 caractères avec une MAJUSCULE et une minuscule',
          ),
        ),
        const SizedBox(height: 12),
        _label('Confirmer le mot de passe'),
        TextField(
          controller: _passConfirm,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            isDense: true,
            errorText: _errPassConfirm,
            suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility)),
          ),
        ),
        const SizedBox(height: 12),
        _label('Téléphone'),
        _input(_phone, keyboard: TextInputType.phone, errorText: _errPhone, maxLength: 10),
      ], key: const ValueKey('day1'));
    }

    return _centeredForm([
      _label('Nom de la garderie'),
      _input(_shopName, errorText: _errShop),
      const SizedBox(height: 12),
      _label('Adresse de la garderie'),
      _input(_address, errorText: _errAddress),
      const SizedBox(height: 12),
      _label('Lien Google Maps (obligatoire)'),
      TextField(
        controller: _mapsUrl,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          isDense: true,
          errorText: _errMapsUrl,
          hintText: 'https://maps.google.com/...',
        ),
      ),
      const SizedBox(height: 16),
      _label('Photos de la garderie (1 à 3 photos)'),
      const SizedBox(height: 8),
      ..._daycareImages.asMap().entries.map((entry) {
        final index = entry.key;
        final image = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white),
                    padding: EdgeInsets.zero,
                    onPressed: () => _removeDaycareImage(index),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
      if (_daycareImages.length < 3)
        OutlinedButton.icon(
          onPressed: _pickDaycareImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(_daycareImages.isEmpty ? 'Ajouter une photo' : 'Ajouter une autre photo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      if (_errImages != null) ...[
        const SizedBox(height: 8),
        Text(_errImages!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ],
    ], key: const ValueKey('day2'));
  }

  Widget _centeredForm(List<Widget> children, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SizedBox(height: 8), ...children]),
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)));

  Widget _input(
    TextEditingController c, {
    bool obscure = false,
    TextInputType? keyboard,
    String? errorText,
    String? hintText,
    int? maxLength,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLength: maxLength,
      decoration: InputDecoration(
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        errorText: errorText,
        hintText: hintText,
        counterText: '',
      ),
    );
  }
}

/* ========================= Wizard ANIMALERIE ========================= */

class _PetshopWizard3Steps extends ConsumerStatefulWidget {
  const _PetshopWizard3Steps();
  @override
  ConsumerState<_PetshopWizard3Steps> createState() => _PetshopWizard3StepsState();
}

class _PetshopWizard3StepsState extends ConsumerState<_PetshopWizard3Steps> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _phone = TextEditingController();

  final _shopName = TextEditingController();
  final _address = TextEditingController();
  final _mapsUrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registered = false;

  String? _errFirst, _errLast, _errEmail, _errPass, _errPassConfirm, _errPhone, _errShop, _errAddress, _errMapsUrl;

  bool _isValidEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());
  bool _isValidPassword(String s) => s.length >= 8 && s.contains(RegExp(r'[A-Z]')) && s.contains(RegExp(r'[a-z]'));
  bool _isValidPhone(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return d.length >= 8 && d.length <= 16;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _phone.dispose();
    _shopName.dispose();
    _address.dispose();
    _mapsUrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    setState(() {
      if (step == 0) {
        final first = _firstName.text.trim();
        final last = _lastName.text.trim();
        if (first.isEmpty) {
          _errFirst = 'Prénom requis';
        } else if (first.length < 3) {
          _errFirst = 'Prénom: minimum 3 caractères';
        } else if (first.length > 15) {
          _errFirst = 'Prénom: maximum 15 caractères';
        } else {
          _errFirst = null;
        }
        if (last.isEmpty) {
          _errLast = 'Nom requis';
        } else if (last.length < 3) {
          _errLast = 'Nom: minimum 3 caractères';
        } else if (last.length > 15) {
          _errLast = 'Nom: maximum 15 caractères';
        } else {
          _errLast = null;
        }
      } else if (step == 1) {
        _errEmail = _isValidEmail(_email.text) ? null : 'Email invalide';
        _errPass = _isValidPassword(_pass.text) ? null : 'Mot de passe trop faible';
        if (_passConfirm.text.isEmpty) {
          _errPassConfirm = 'Confirmation requise';
        } else if (_passConfirm.text != _pass.text) {
          _errPassConfirm = 'Les mots de passe ne correspondent pas';
        } else {
          _errPassConfirm = null;
        }
        final phone = _phone.text.trim();
        if (phone.isEmpty) {
          _errPhone = 'Téléphone requis';
        } else if (!phone.startsWith('0')) {
          _errPhone = 'Le numéro doit commencer par 0';
        } else if (phone.length < 9 || phone.length > 10) {
          _errPhone = 'Le numéro doit contenir 9 ou 10 chiffres';
        } else {
          _errPhone = null;
        }
      } else {
        _errShop = _shopName.text.trim().isEmpty ? 'Nom de la boutique requis' : null;
        _errAddress = _address.text.trim().isEmpty ? 'Adresse requise' : null;
        final mapsOk = _isValidHttpUrl(_mapsUrl.text);
        _errMapsUrl = mapsOk
            ? null
            : (_mapsUrl.text.trim().isEmpty ? 'Lien Google Maps requis' : 'URL invalide (http/https)');
      }
    });
    if (step == 0) return _errFirst == null && _errLast == null;
    if (step == 1) return _errEmail == null && _errPass == null && _errPassConfirm == null && _errPhone == null;
    return _errShop == null && _errAddress == null && _errMapsUrl == null;
  }

  Future<void> _next() async {
    if (!_validateStep(_step)) return;

    if (_step == 1 && !_registered) {
      setState(() => _loading = true);
      try {
        final ok = await ref.read(sessionProvider.notifier).registerOnly(_email.text.trim(), _pass.text);
        if (!mounted) return;
        if (!ok) {
          final err = (ref.read(sessionProvider).error ?? '').toLowerCase();
          if (err.contains('409') || err.contains('already in use') || err.contains('email')) {
            setState(() => _errEmail = 'Email déjà utilisé');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cet email est déjà utilisé.')));
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(sessionProvider).error ?? 'Inscription impossible')),
          );
          return;
        }
        _registered = true;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  Future<void> _submitFinal() async {
    if (!_validateStep(2)) return;
    setState(() => _loading = true);

    try {
      // IMPORTANT: Activer le flag pour bloquer les redirections du router
      ref.read(sessionProvider.notifier).setCompletingProRegistration(true);

      // Login d'abord (avec les identifiants de l'étape 1)
      final loginOk = await ref.read(sessionProvider.notifier).login(_email.text.trim(), _pass.text);
      if (!loginOk) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur de connexion')),
          );
        }
        return;
      }

      final api = ref.read(apiProvider);

      try {
        await api.updateMe(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
        );
      } on DioException catch (e) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        final status = e.response?.statusCode;
        final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? '');
        if (status == 409 || msg.toLowerCase().contains('phone')) {
          setState(() {
            _errPhone = 'Téléphone déjà utilisé';
            _step = 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce numéro est déjà utilisé.')));
          return;
        }
        rethrow;
      }

      final display = _shopName.text.trim().isEmpty ? _email.text.split('@').first : _shopName.text.trim();

      final finalMaps = _mapsUrl.text.trim();
      if (finalMaps.isEmpty || !_isValidHttpUrl(finalMaps)) {
        ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
        setState(() {
          _errMapsUrl = finalMaps.isEmpty ? 'Lien Google Maps requis' : 'URL invalide (http/https)';
          _step = 2;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMapsUrl!)));
        return;
      }

      await api.upsertMyProvider(
        displayName: display,
        address: _address.text.trim(),
        specialties: {
          'kind': 'petshop',
          'visible': true,
          'mapsUrl': finalMaps,
        },
      );

      // Refresh user pour mettre à jour le role (user → provider)
      await ref.read(sessionProvider.notifier).refreshMe();

      // Déconnexion immédiate pour éviter la redirection automatique
      // L'utilisateur doit attendre l'approbation admin avant de pouvoir se connecter
      await ref.read(sessionProvider.notifier).logout();

      // Désactiver le flag (normalement déjà fait par logout, mais pour être sûr)
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      ref.read(sessionProvider.notifier).setCompletingProRegistration(false);
      final msg = (e.response?.data is Map) ? (e.response?.data['message']?.toString() ?? '') : (e.message ?? 'Erreur');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $msg')));
    } finally {
      if (mounted) setState(() => _loading = false);
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
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Inscription Animalerie'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _buildStep())),
            const SizedBox(height: 8),
            _DotsIndicator(current: _step, total: 3),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_step > 0)
                  OutlinedButton(onPressed: _loading ? null : () => setState(() => _step -= 1), child: const Text('Précédent')),
                const Spacer(),
                FilledButton(onPressed: _loading ? null : (_step < 2 ? _next : _submitFinal), child: Text(_step < 2 ? 'Suivant' : 'Soumettre')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return _centeredForm([
        _label('Prénom'),
        _input(_firstName, errorText: _errFirst, maxLength: 15),
        const SizedBox(height: 12),
        _label('Nom'),
        _input(_lastName, errorText: _errLast, maxLength: 15),
      ], key: const ValueKey('pet0'));
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
            suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility)),
            helperText: 'Min. 8 caractères avec une MAJUSCULE et une minuscule',
          ),
        ),
        const SizedBox(height: 12),
        _label('Confirmer le mot de passe'),
        TextField(
          controller: _passConfirm,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            isDense: true,
            errorText: _errPassConfirm,
            suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility)),
          ),
        ),
        const SizedBox(height: 12),
        _label('Téléphone'),
        _input(_phone, keyboard: TextInputType.phone, errorText: _errPhone, maxLength: 10),
      ], key: const ValueKey('pet1'));
    }

    return _centeredForm([
      _label('Nom de la boutique'),
      _input(_shopName, errorText: _errShop),
      const SizedBox(height: 12),
      _label('Adresse de la boutique'),
      _input(_address, errorText: _errAddress),
      const SizedBox(height: 12),
      _label('Lien Google Maps (obligatoire)'),
      TextField(
        controller: _mapsUrl,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          isDense: true,
          errorText: _errMapsUrl,
          hintText: 'https://maps.google.com/...',
        ),
      ),
    ], key: const ValueKey('pet2'));
  }

  Widget _centeredForm(List<Widget> children, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SizedBox(height: 8), ...children]),
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 13)));

  Widget _input(
    TextEditingController c, {
    bool obscure = false,
    TextInputType? keyboard,
    String? errorText,
    String? hintText,
    int? maxLength,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLength: maxLength,
      decoration: InputDecoration(
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        errorText: errorText,
        hintText: hintText,
        counterText: '',
      ),
    );
  }
}
