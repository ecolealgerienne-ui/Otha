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

class CareerDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const CareerDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<CareerDetailScreen> createState() => _CareerDetailScreenState();
}

class _CareerDetailScreenState extends ConsumerState<CareerDetailScreen> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  String? _error;
  bool _isContacting = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final post = await api.careerGetPost(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _contactPost() async {
    setState(() => _isContacting = true);

    try {
      final api = ref.read(apiProvider);
      final result = await api.careerContactPost(widget.postId);
      final conversationId = result['conversationId']?.toString();

      if (mounted && conversationId != null) {
        context.push('/career/chat/$conversationId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isContacting = false);
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

    // Check user role
    final session = ref.watch(sessionProvider);
    final userId = session.user?['id']?.toString();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: textPrimary),
        ),
        title: Text(
          l10n.careerTitle,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryPurple))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: textSecondary),
                      const SizedBox(height: 12),
                      Text('Erreur: $_error', style: TextStyle(color: textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadPost,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _post == null
                  ? Center(child: Text('Annonce non trouvée', style: TextStyle(color: textSecondary)))
                  : _buildContent(l10n, isDark, cardColor, textPrimary, textSecondary, userId),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color? textSecondary,
    String? userId,
  ) {
    final post = _post!;
    final title = post['title']?.toString() ?? '';
    final publicBio = post['publicBio']?.toString() ?? '';
    final city = post['city']?.toString();
    final domain = post['domain']?.toString();
    final duration = post['duration']?.toString();
    final type = post['type']?.toString();
    final isOwn = post['isOwn'] == true || post['createdById'] == userId;
    final createdBy = post['createdBy'] as Map<String, dynamic>?;

    // Private fields (only visible for pros or own post)
    final fullName = post['fullName']?.toString();
    final email = post['email']?.toString();
    final phone = post['phone']?.toString();
    final detailedBio = post['detailedBio']?.toString();
    final cvImageUrl = post['cvImageUrl']?.toString();

    // Offer fields
    final salary = post['salary']?.toString();
    final requirements = post['requirements']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: type == 'REQUEST'
                  ? _primaryPurple.withOpacity(isDark ? 0.3 : 0.1)
                  : Colors.green.withOpacity(isDark ? 0.3 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              type == 'REQUEST' ? l10n.careerTypeRequest : l10n.careerTypeOffer,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: type == 'REQUEST' ? _primaryPurple : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (city != null && city.isNotEmpty)
                _buildTag(Icons.location_on_outlined, city, isDark, textSecondary),
              if (domain != null && domain.isNotEmpty)
                _buildTag(Icons.work_outline, domain, isDark, textSecondary),
              if (duration != null && duration.isNotEmpty)
                _buildTag(Icons.schedule, duration, isDark, textSecondary),
              if (salary != null && salary.isNotEmpty)
                _buildTag(Icons.attach_money, salary, isDark, textSecondary),
            ],
          ),
          const SizedBox(height: 24),

          // Public bio section
          _buildSection(
            l10n.careerPublicBio,
            Icons.public,
            publicBio,
            textPrimary,
            textSecondary,
            cardColor,
            isDark,
          ),

          // Private info section (if visible)
          if (fullName != null || email != null || phone != null || detailedBio != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? _darkCardBorder : Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: _primaryPurple),
                      const SizedBox(width: 8),
                      Text(
                        l10n.careerPrivateInfo,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (fullName != null && fullName.isNotEmpty)
                    _buildInfoRow(Icons.person_outline, fullName, textPrimary, textSecondary),
                  if (email != null && email.isNotEmpty)
                    _buildInfoRow(Icons.email_outlined, email, textPrimary, textSecondary),
                  if (phone != null && phone.isNotEmpty)
                    _buildInfoRow(Icons.phone_outlined, phone, textPrimary, textSecondary),
                  if (detailedBio != null && detailedBio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.careerDetailedBio,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailedBio,
                      style: TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // CV Image (if visible)
          if (cvImageUrl != null && cvImageUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? _darkCardBorder : Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      cvImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 100,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Requirements (for offers)
          if (requirements != null && requirements.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSection(
              l10n.careerRequirements,
              Icons.checklist,
              requirements,
              textPrimary,
              textSecondary,
              cardColor,
              isDark,
            ),
          ],

          // Creator info
          if (createdBy != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? _darkCardBorder : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: createdBy['photoUrl'] != null
                        ? NetworkImage(createdBy['photoUrl'])
                        : null,
                    child: createdBy['photoUrl'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          createdBy['firstName'] != null
                              ? '${createdBy['firstName']} ${createdBy['lastName'] ?? ''}'
                              : 'Anonyme',
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        if (createdBy['role'] != null)
                          Text(
                            createdBy['role'] == 'PRO' ? 'Professionnel' : 'Utilisateur',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 100), // Space for floating button
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, bool isDark, Color? textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? _darkCardBorder : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 13, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    String content,
    Color textPrimary,
    Color? textSecondary,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _primaryPurple),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(fontSize: 15, color: textPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textPrimary, Color? textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: textPrimary)),
          ),
        ],
      ),
    );
  }
}
