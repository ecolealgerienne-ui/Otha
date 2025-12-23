import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/session_controller.dart';

// Colors
const _primaryPurple = Color(0xFF6B5BFF);
const _purpleLight = Color(0xFFEDE9FF);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);
const _greenSuccess = Color(0xFF4CD964);

class CareerCreateScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingPost;

  const CareerCreateScreen({super.key, this.existingPost});

  @override
  ConsumerState<CareerCreateScreen> createState() => _CareerCreateScreenState();
}

class _CareerCreateScreenState extends ConsumerState<CareerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _type = 'REQUEST'; // REQUEST or OFFER

  // Form controllers
  final _titleController = TextEditingController();
  final _publicBioController = TextEditingController();
  final _cityController = TextEditingController();
  final _domainController = TextEditingController();
  final _durationController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailedBioController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requirementsController = TextEditingController();

  String? _cvImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.existingPost != null) {
      _populateForm(widget.existingPost!);
    }
  }

  void _populateForm(Map<String, dynamic> post) {
    _type = post['type']?.toString() ?? 'REQUEST';
    _titleController.text = post['title']?.toString() ?? '';
    _publicBioController.text = post['publicBio']?.toString() ?? '';
    _cityController.text = post['city']?.toString() ?? '';
    _domainController.text = post['domain']?.toString() ?? '';
    _durationController.text = post['duration']?.toString() ?? '';
    _fullNameController.text = post['fullName']?.toString() ?? '';
    _emailController.text = post['email']?.toString() ?? '';
    _phoneController.text = post['phone']?.toString() ?? '';
    _detailedBioController.text = post['detailedBio']?.toString() ?? '';
    _salaryController.text = post['salary']?.toString() ?? '';
    _requirementsController.text = post['requirements']?.toString() ?? '';
    _cvImageUrl = post['cvImageUrl']?.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _publicBioController.dispose();
    _cityController.dispose();
    _domainController.dispose();
    _durationController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _detailedBioController.dispose();
    _salaryController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      final data = {
        'type': _type,
        'title': _titleController.text.trim(),
        'publicBio': _publicBioController.text.trim(),
        if (_cityController.text.isNotEmpty) 'city': _cityController.text.trim(),
        if (_domainController.text.isNotEmpty) 'domain': _domainController.text.trim(),
        if (_durationController.text.isNotEmpty) 'duration': _durationController.text.trim(),
        if (_fullNameController.text.isNotEmpty) 'fullName': _fullNameController.text.trim(),
        if (_emailController.text.isNotEmpty) 'email': _emailController.text.trim(),
        if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text.trim(),
        if (_detailedBioController.text.isNotEmpty) 'detailedBio': _detailedBioController.text.trim(),
        if (_cvImageUrl != null) 'cvImageUrl': _cvImageUrl,
        if (_salaryController.text.isNotEmpty) 'salary': _salaryController.text.trim(),
        if (_requirementsController.text.isNotEmpty) 'requirements': _requirementsController.text.trim(),
      };

      final l10n = AppLocalizations.of(context);

      if (widget.existingPost != null) {
        await api.careerUpdatePost(widget.existingPost!['id'], data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.careerPostUpdated),
              backgroundColor: _greenSuccess,
            ),
          );
        }
      } else {
        await api.careerCreatePost(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.careerPostPublished),
              backgroundColor: _greenSuccess,
            ),
          );
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF8F8F8);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final isEditing = widget.existingPost != null;

    // Check if user is PRO - only PROs can create OFFER type
    final session = ref.watch(sessionProvider);
    final userRole = (session.user?['role'] ?? 'USER').toString().toUpperCase();
    final isPro = userRole == 'PRO' || userRole == 'ADMIN';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.close, color: textPrimary),
        ),
        title: Text(
          isEditing ? l10n.careerEditPost : l10n.careerCreatePost,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _isLoading ? null : _deletePost,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector (only for new posts AND only for PRO users)
            if (!isEditing && isPro) ...[
              Text(
                'Type d\'annonce',
                style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: l10n.careerTypeRequest,
                      subtitle: 'Je cherche un stage/emploi',
                      icon: Icons.person_search,
                      isSelected: _type == 'REQUEST',
                      isDark: isDark,
                      onTap: () => setState(() => _type = 'REQUEST'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeButton(
                      label: l10n.careerTypeOffer,
                      subtitle: 'Je propose un emploi',
                      icon: Icons.business_center,
                      isSelected: _type == 'OFFER',
                      isDark: isDark,
                      onTap: () => setState(() => _type = 'OFFER'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Public info section
            _buildSectionHeader(l10n.careerPublicInfo, Icons.public, textPrimary),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _titleController,
              label: l10n.careerTitle2,
              hint: l10n.careerTitleHint,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              required: true,
              maxLength: 100,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _publicBioController,
              label: l10n.careerPublicBio,
              hint: l10n.careerPublicBioHint,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              required: true,
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: l10n.careerCity,
                    hint: 'Alger',
                    isDark: isDark,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _domainController,
                    label: l10n.careerDomain,
                    hint: l10n.careerDomainHint,
                    isDark: isDark,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    prefixIcon: Icons.work_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _durationController,
              label: l10n.careerDuration,
              hint: l10n.careerDurationHint,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              prefixIcon: Icons.schedule,
            ),

            // Private info section (only for REQUEST)
            if (_type == 'REQUEST') ...[
              const SizedBox(height: 24),
              _buildSectionHeader(l10n.careerPrivateInfo, Icons.lock_outline, textPrimary),
              Text(
                l10n.careerPrivateInfoNote,
                style: TextStyle(fontSize: 12, color: textSecondary, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _fullNameController,
                label: l10n.careerFullName,
                hint: 'Votre nom complet',
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _emailController,
                      label: l10n.careerEmail,
                      hint: 'email@exemple.com',
                      isDark: isDark,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneController,
                      label: l10n.careerPhone,
                      hint: '0555 XX XX XX',
                      isDark: isDark,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _detailedBioController,
                label: l10n.careerDetailedBio,
                hint: l10n.careerDetailedBioHint,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                maxLines: 5,
                maxLength: 2000,
              ),
            ],

            // Offer specific fields
            if (_type == 'OFFER') ...[
              const SizedBox(height: 24),
              _buildSectionHeader('Détails de l\'offre', Icons.info_outline, textPrimary),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _salaryController,
                label: l10n.careerSalary,
                hint: 'Ex: 50 000 DA/mois',
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                prefixIcon: Icons.attach_money,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _requirementsController,
                label: l10n.careerRequirements,
                hint: 'Ex: Diplôme vétérinaire, 2 ans d\'expérience...',
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                maxLines: 4,
                maxLength: 1000,
              ),
            ],

            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEditing ? 'Mettre à jour' : 'Publier',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _primaryPurple),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color? textSecondary,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: TextStyle(color: textPrimary),
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        labelStyle: TextStyle(color: textSecondary),
        hintText: hint,
        hintStyle: TextStyle(color: textSecondary?.withOpacity(0.5)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: textSecondary, size: 20) : null,
        filled: true,
        fillColor: cardColor,
        counterStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryPurple),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Ce champ est requis';
              return null;
            }
          : null,
    );
  }

  Future<void> _deletePost() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'annonce ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingPost != null) {
      setState(() => _isLoading = true);
      try {
        final api = ref.read(apiProvider);
        await api.careerDeletePost(widget.existingPost!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.careerPostDeleted), backgroundColor: _greenSuccess),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryPurple.withOpacity(isDark ? 0.3 : 0.1)
              : isDark
                  ? _darkCard
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryPurple : (isDark ? _darkCardBorder : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? _primaryPurple : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? _primaryPurple : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
