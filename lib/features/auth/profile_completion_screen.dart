import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/session_controller.dart';

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
    _firstNameController.text = (user?['firstName'] ?? '').toString();
    _lastNameController.text = (user?['lastName'] ?? '').toString();
    _phoneController.text = (user?['phone'] ?? '').toString();
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
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: const Color(0xFFF36C6C),
        ),
      );
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A4A4A),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, {TextInputType? keyboard, String? errorText}) {
    const coral = Color(0xFFF36C6C);
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: coral, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const coral = Color(0xFFF36C6C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Logo et titre
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: coral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 40,
                    color: coral,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Complétez votre profil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A4A4A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quelques informations supplémentaires\npour finaliser votre inscription',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 48),

              _label('Prénom'),
              _input(_firstNameController, errorText: _errFirstName),
              const SizedBox(height: 20),

              _label('Nom'),
              _input(_lastNameController, errorText: _errLastName),
              const SizedBox(height: 20),

              _label('Téléphone'),
              _input(_phoneController, keyboard: TextInputType.phone, errorText: _errPhone),
              const SizedBox(height: 40),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: coral.withOpacity(0.4),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Continuer'),
                ),
              ),

              const SizedBox(height: 16),

              // Note de confidentialité
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Vos informations sont sécurisées et ne seront jamais partagées sans votre consentement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
