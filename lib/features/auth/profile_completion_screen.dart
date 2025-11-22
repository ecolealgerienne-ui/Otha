import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/router.dart';

/// Écran de complétion de profil pour les utilisateurs Google
/// Demande les informations manquantes : prénom, nom, téléphone
class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends ConsumerState<ProfileCompletionScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _errFirstName;
  String? _errLastName;
  String? _errPhone;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les données Google si disponibles
    final user = ref.read(sessionProvider).user;
    _firstNameController.text = user?.firstName ?? '';
    _lastNameController.text = user?.lastName ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _errFirstName = null;
      _errLastName = null;
      _errPhone = null;
    });

    bool valid = true;

    if (_firstNameController.text.trim().isEmpty) {
      setState(() => _errFirstName = 'Prénom requis');
      valid = false;
    }

    if (_lastNameController.text.trim().isEmpty) {
      setState(() => _errLastName = 'Nom requis');
      valid = false;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errPhone = 'Téléphone requis');
      valid = false;
    } else if (phone.length < 10) {
      setState(() => _errPhone = 'Numéro invalide (min. 10 chiffres)');
      valid = false;
    }

    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);

    try {
      final api = ref.read(apiProvider);
      await api.updateMe(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      // Rafraîchir le profil utilisateur
      await ref.read(sessionProvider.notifier).refreshMe();

      if (!mounted) return;

      // Rediriger vers la page d'accueil
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      String errorMsg = 'Erreur lors de la mise à jour du profil';
      if (e.toString().contains('phone')) {
        errorMsg = 'Ce numéro de téléphone est déjà utilisé';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, {TextInputType? keyboard, String? errorText}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        errorText: errorText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Compléter votre profil'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Empêcher le retour arrière
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Informations personnelles',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Veuillez compléter vos informations pour continuer',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              _label('Prénom'),
              _input(_firstNameController, errorText: _errFirstName),
              const SizedBox(height: 16),

              _label('Nom'),
              _input(_lastNameController, errorText: _errLastName),
              const SizedBox(height: 16),

              _label('Téléphone'),
              _input(_phoneController, keyboard: TextInputType.phone, errorText: _errPhone),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Continuer', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
