// lib/features/adopt/adopt_create_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _rosePrimary = Color(0xFFFF6B6B);
const _roseLight = Color(0xFFFFE8E8);
const _greenSuccess = Color(0xFF4CD964);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

final _myPostsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.myAdoptPosts();
});

class AdoptCreateScreen extends ConsumerWidget {
  const AdoptCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_myPostsProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F8F8);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: topPadding + 8, left: 16, right: 16, bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.list_alt, color: _rosePrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.adoptMyAds,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _CreateEditPostScreen()),
                    ).then((_) => ref.invalidate(_myPostsProvider));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _rosePrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.adoptCreateButton, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return _EmptyState(
                    onCreatePost: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _CreateEditPostScreen()),
                      ).then((_) => ref.invalidate(_myPostsProvider));
                    },
                    isDark: isDark,
                    l10n: l10n,
                  );
                }

                // Stats summary
                final approved = posts.where((p) => p['status'] == 'APPROVED').length;
                final pending = posts.where((p) => p['status'] == 'PENDING').length;
                final adopted = posts.where((p) => p['adoptedAt'] != null).length;

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_myPostsProvider),
                  color: _rosePrimary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Stats cards
                      Row(
                        children: [
                          _StatCard(value: '${posts.length}', label: l10n.adoptTotal, color: Colors.grey, isDark: isDark),
                          const SizedBox(width: 8),
                          _StatCard(value: '$approved', label: l10n.adoptActive, color: _greenSuccess, isDark: isDark),
                          const SizedBox(width: 8),
                          _StatCard(value: '$pending', label: l10n.adoptPending, color: Colors.orange, isDark: isDark),
                          const SizedBox(width: 8),
                          _StatCard(value: '$adopted', label: l10n.adoptAdoptedPlural, color: _rosePrimary, isDark: isDark),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Posts list
                      ...posts.map((post) => _PostCard(
                        post: post,
                        isDark: isDark,
                        l10n: l10n,
                        onEdit: () {
                          final status = post['status']?.toString() ?? '';
                          if (status == 'ADOPTED' || post['adoptedAt'] != null) {
                            _showDialog(
                              context,
                              ref,
                              l10n.adoptModificationImpossible,
                              l10n.adoptAlreadyAdopted,
                              isDark,
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _CreateEditPostScreen(post: post)),
                          ).then((_) => ref.invalidate(_myPostsProvider));
                        },
                        onDelete: () => _confirmDelete(context, ref, post, isDark, l10n),
                        onMarkAsAdopted: () => _showAdopterSelection(context, ref, post, isDark, l10n),
                      )),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(color: _rosePrimary),
                    ),
                  ],
                ),
              ),
              error: (err, _) => _ErrorState(
                error: err.toString(),
                onRetry: () => ref.invalidate(_myPostsProvider),
                isDark: isDark,
                l10n: l10n,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref, String title, String content, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(content, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700])),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: _rosePrimary),
            child: Text(AppLocalizations.of(context).adoptOk),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdopterSelection(BuildContext context, WidgetRef ref, Map<String, dynamic> post, bool isDark, AppLocalizations l10n) async {
    final postId = post['id']?.toString();
    if (postId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? _darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AdopterSelectionSheet(
        postId: postId,
        postName: post['animalName']?.toString() ?? post['title']?.toString() ?? '',
        isDark: isDark,
        l10n: l10n,
        onAdopterSelected: (adopterId) async {
          Navigator.pop(ctx);
          try {
            final api = ref.read(apiProvider);
            await api.markAdoptPostAsAdopted(postId, adoptedById: adopterId);
            ref.invalidate(_myPostsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.adoptAdoptionConfirmed),
                  backgroundColor: _greenSuccess,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${l10n.adoptError}: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> post, bool isDark, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.adoptDeleteAdTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(l10n.adoptDeleteAdDesc, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final api = ref.read(apiProvider);
        await api.deleteAdoptPost(post['id'].toString());
        ref.invalidate(_myPostsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.adoptAdDeleted),
              backgroundColor: Colors.grey[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.adoptError}: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// Stats card widget
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({required this.value, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: _darkCardBorder) : null,
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Post card widget
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsAdopted;

  const _PostCard({
    required this.post,
    required this.isDark,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkAsAdopted,
  });

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    final title = (post['title'] ?? post['animalName'] ?? 'Animal').toString();
    final species = (post['species'] ?? '').toString();
    final city = (post['city'] ?? '').toString();
    final status = (post['status'] ?? 'PENDING').toString();
    final ageMonths = post['ageMonths'] as int?;
    final adoptedAt = post['adoptedAt'];
    final isAdopted = adoptedAt != null;
    final isApproved = status == 'APPROVED';

    final ageText = ageMonths != null
        ? ageMonths < 12
            ? '$ageMonths ${l10n.adoptMonths}'
            : '${(ageMonths / 12).floor()} ${ageMonths >= 24 ? l10n.adoptYears : l10n.adoptYear}'
        : '';

    final speciesLabel = species == 'dog' ? l10n.adoptDog : species == 'cat' ? l10n.adoptCat : species;

    // Status badge
    final statusColor = isAdopted
        ? _greenSuccess
        : status == 'APPROVED'
            ? _greenSuccess
            : status == 'REJECTED'
                ? Colors.red
                : Colors.orange;

    final statusText = isAdopted
        ? l10n.adoptStatusAdopted
        : status == 'APPROVED'
            ? l10n.adoptStatusActive
            : status == 'REJECTED'
                ? l10n.adoptStatusRejected
                : l10n.adoptStatusPending;

    final statusIcon = isAdopted
        ? Icons.check_circle
        : status == 'APPROVED'
            ? Icons.visibility
            : status == 'REJECTED'
                ? Icons.cancel
                : Icons.hourglass_top;

    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: _darkCardBorder) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAdopted ? null : onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image with status indicator
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: images.isNotEmpty
                          ? Image.network(
                              images.first,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    // Status badge on image
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? _darkCard : Colors.white, width: 2),
                        ),
                        child: Icon(statusIcon, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (speciesLabel.isNotEmpty) ...[
                            Icon(Icons.pets, size: 12, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              speciesLabel,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                          if (ageText.isNotEmpty) ...[
                            Text(' • ', style: TextStyle(color: textSecondary)),
                            Text(
                              ageText,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                          if (city.isNotEmpty) ...[
                            Text(' • ', style: TextStyle(color: textSecondary)),
                            Icon(Icons.location_on, size: 12, color: textSecondary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                city,
                                style: TextStyle(fontSize: 12, color: textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Column(
                  children: [
                    // "Faire adopter" button - only for approved, not adopted posts
                    if (isApproved && !isAdopted)
                      IconButton(
                        onPressed: onMarkAsAdopted,
                        icon: const Icon(Icons.favorite, color: _rosePrimary, size: 20),
                        tooltip: l10n.adoptMarkAsAdopted,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (!isAdopted)
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined, color: textSecondary, size: 20),
                        tooltip: l10n.adoptModify,
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      tooltip: l10n.delete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.pets, color: _rosePrimary, size: 32),
    );
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreatePost;
  final bool isDark;
  final AppLocalizations l10n;

  const _EmptyState({required this.onCreatePost, required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, size: 64, color: _rosePrimary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adoptNoAdsInList,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adoptCreateFirstAd,
              style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCreatePost,
              style: FilledButton.styleFrom(
                backgroundColor: _rosePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.adoptCreateAd, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// Error state
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final bool isDark;
  final AppLocalizations l10n;

  const _ErrorState({required this.error, required this.onRetry, required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              l10n.adoptLoadingError,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _rosePrimary),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.adoptRetry),
            ),
          ],
        ),
      ),
    );
  }
}

// Adopter selection bottom sheet
class _AdopterSelectionSheet extends ConsumerStatefulWidget {
  final String postId;
  final String postName;
  final bool isDark;
  final AppLocalizations l10n;
  final Function(String adopterId) onAdopterSelected;

  const _AdopterSelectionSheet({
    required this.postId,
    required this.postName,
    required this.isDark,
    required this.l10n,
    required this.onAdopterSelected,
  });

  @override
  ConsumerState<_AdopterSelectionSheet> createState() => _AdopterSelectionSheetState();
}

class _AdopterSelectionSheetState extends ConsumerState<_AdopterSelectionSheet> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final api = ref.read(apiProvider);
      final conversations = await api.getAdoptPostConversations(widget.postId);
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDark ? Colors.white : Colors.black87;
    final textSecondary = widget.isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite, color: _rosePrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.l10n.adoptChooseAdopter,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      widget.postName,
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: _rosePrimary),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '${widget.l10n.adoptLoadingError}: $_error',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_conversations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 48, color: textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      widget.l10n.adoptNoInterestedPeople,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.l10n.adoptNoInterestedPeopleDesc,
                      style: TextStyle(color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _conversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  final otherUserId = conv['otherUserId']?.toString();
                  final otherPersonName = (conv['otherPersonName'] ?? widget.l10n.adoptAnonymous).toString();
                  final lastMessageRaw = conv['lastMessage'];
                  String lastMessageText;
                  if (lastMessageRaw is Map<String, dynamic>) {
                    lastMessageText = (lastMessageRaw['content'] ?? '').toString();
                  } else if (lastMessageRaw is String) {
                    lastMessageText = lastMessageRaw;
                  } else {
                    lastMessageText = widget.l10n.adoptNoMessage;
                  }

                  final post = conv['post'] as Map<String, dynamic>? ?? {};
                  final images = (post['images'] as List<dynamic>?)
                      ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
                      .where((url) => url != null && url.isNotEmpty)
                      .cast<String>()
                      .toList() ?? [];

                  return Container(
                    decoration: BoxDecoration(
                      color: widget.isDark ? _darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.isDark ? _darkCardBorder : Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Avatar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: images.isNotEmpty
                                ? Image.network(
                                    images.first,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: widget.isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                                      child: const Icon(Icons.person, color: _rosePrimary),
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: widget.isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.person, color: _rosePrimary),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Name and last message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherPersonName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessageText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Select button
                          FilledButton(
                            onPressed: otherUserId != null
                                ? () => widget.onAdopterSelected(otherUserId)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _rosePrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Icon(Icons.favorite, size: 18),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Create/Edit screen
class _CreateEditPostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? post;

  const _CreateEditPostScreen({this.post});

  @override
  ConsumerState<_CreateEditPostScreen> createState() => _CreateEditPostScreenState();
}

class _CreateEditPostScreenState extends ConsumerState<_CreateEditPostScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _city;
  late final TextEditingController _desc;

  String _species = 'dog';
  String _sex = 'unknown';
  final List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  bool _submitting = false;

  String _mapSexFromBackend(String? backendSex) {
    if (backendSex == null) return 'unknown';
    final s = backendSex.toUpperCase();
    if (s == 'M') return 'male';
    if (s == 'F') return 'female';
    if (s == 'U') return 'unknown';
    final lower = backendSex.toLowerCase();
    if (lower == 'male' || lower == 'female' || lower == 'unknown') return lower;
    return 'unknown';
  }

  String _mapSexToBackend(String dropdownValue) {
    if (dropdownValue == 'male') return 'M';
    if (dropdownValue == 'female') return 'F';
    return 'U';
  }

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _title = TextEditingController(text: p?['title']?.toString() ?? '');
    _name = TextEditingController(text: p?['animalName']?.toString() ?? '');
    _city = TextEditingController(text: p?['city']?.toString() ?? '');
    _desc = TextEditingController(text: p?['description']?.toString() ?? '');
    _species = (p?['species']?.toString() ?? 'dog').toLowerCase();
    _sex = _mapSexFromBackend(p?['sex']?.toString());

    final ageMonths = p?['ageMonths'] as int?;
    if (ageMonths != null) {
      if (ageMonths < 12) {
        _age = TextEditingController(text: '$ageMonths mois');
      } else {
        _age = TextEditingController(text: '${(ageMonths / 12).floor()} ans');
      }
    } else {
      _age = TextEditingController();
    }

    final images = (p?['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
    _existingImageUrls = images ?? [];
  }

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _age.dispose();
    _city.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_newImages.length + _existingImageUrls.length >= 3) return;
    final pic = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (pic != null) setState(() => _newImages.add(pic));
  }

  void _removeNewImage(int i) => setState(() => _newImages.removeAt(i));
  void _removeExistingImage(int i) => setState(() => _existingImageUrls.removeAt(i));

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adoptAddPhoto)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiProvider);
      final urls = <String>[..._existingImageUrls];
      for (final x in _newImages) {
        final url = await api.uploadLocalFile(File(x.path), folder: 'adopt');
        urls.add(url);
      }

      int? ageMonths;
      final ageText = _age.text.trim().toLowerCase();
      if (ageText.isNotEmpty) {
        final monthsMatch = RegExp(r'(\d+)\s*mois').firstMatch(ageText);
        final yearsMatch = RegExp(r'(\d+)\s*an').firstMatch(ageText);
        if (monthsMatch != null) {
          ageMonths = int.tryParse(monthsMatch.group(1)!);
        } else if (yearsMatch != null) {
          final years = int.tryParse(yearsMatch.group(1)!);
          if (years != null) ageMonths = years * 12;
        }
      }

      final isEdit = widget.post != null;

      if (isEdit) {
        await api.updateAdoptPost(
          widget.post!['id'].toString(),
          title: _title.text.trim(),
          animalName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          species: _species,
          sex: _mapSexToBackend(_sex),
          ageMonths: ageMonths,
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          photos: urls,
        );
      } else {
        await api.createAdoptPost(
          title: _title.text.trim(),
          animalName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          species: _species,
          sex: _mapSexToBackend(_sex),
          ageMonths: ageMonths,
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          photos: urls,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? l10n.adoptAdModified
                : l10n.adoptAdCreated),
            backgroundColor: _greenSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.adoptError}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.post != null;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F8F8);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: topPadding + 8, left: 12, right: 16, bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : _rosePrimary),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? l10n.adoptEditAd : l10n.adoptNewAd,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Photos section
                  _buildSectionTitle(l10n.adoptPhotos, Icons.photo_library, required: true, isDark: isDark),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Existing images
                        ..._existingImageUrls.asMap().entries.map((e) => _buildImageTile(
                          imageUrl: e.value,
                          onRemove: () => _removeExistingImage(e.key),
                          isDark: isDark,
                        )),
                        // New images
                        ..._newImages.asMap().entries.map((e) => _buildImageTile(
                          file: File(e.value.path),
                          onRemove: () => _removeNewImage(e.key),
                          isDark: isDark,
                        )),
                        // Add button
                        if (_newImages.length + _existingImageUrls.length < 3)
                          _buildAddImageButton(isDark, l10n),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  _buildSectionTitle(l10n.adoptInformations, Icons.info_outline, required: true, isDark: isDark),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _title,
                    label: l10n.adoptAdTitle,
                    hint: l10n.adoptAdTitleHint,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.adoptRequired : null,
                    maxLength: 140,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _name,
                    label: l10n.adoptAnimalName,
                    hint: l10n.adoptAnimalNameHint,
                    maxLength: 100,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Species & Sex
                  Row(
                    children: [
                      Expanded(child: _buildSpeciesDropdown(isDark, l10n)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSexDropdown(isDark, l10n)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Age & City
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _age,
                          label: l10n.adoptAge,
                          hint: l10n.adoptAgeHint,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _city,
                          label: l10n.adoptCity,
                          hint: l10n.adoptCityHint,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  _buildTextField(
                    controller: _desc,
                    label: l10n.adoptDescription,
                    hint: l10n.adoptDescriptionHint,
                    maxLines: 4,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _rosePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? l10n.adoptSaveChanges : l10n.adoptPublishAd,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {bool required = false, bool isDark = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _rosePrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: Colors.red)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    int? maxLength,
    int maxLines = 1,
    bool isDark = false,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? _darkCard : Colors.white,
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
          borderSide: const BorderSide(color: _rosePrimary, width: 2),
        ),
        counterText: '',
      ),
      validator: validator,
      maxLength: maxLength,
      maxLines: maxLines,
    );
  }

  Widget _buildSpeciesDropdown(bool isDark, AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      value: _species,
      dropdownColor: isDark ? _darkCard : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      items: [
        DropdownMenuItem(value: 'dog', child: Text(l10n.adoptDog, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
        DropdownMenuItem(value: 'cat', child: Text(l10n.adoptCat, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
        DropdownMenuItem(value: 'other', child: Text(l10n.adoptOther, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
      ],
      onChanged: (v) => setState(() => _species = v ?? 'dog'),
      decoration: InputDecoration(
        labelText: l10n.adoptSpecies,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        filled: true,
        fillColor: isDark ? _darkCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildSexDropdown(bool isDark, AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      value: _sex,
      dropdownColor: isDark ? _darkCard : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      items: [
        DropdownMenuItem(value: 'unknown', child: Text(l10n.adoptUnknown, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
        DropdownMenuItem(value: 'male', child: Text(l10n.adoptMale, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
        DropdownMenuItem(value: 'female', child: Text(l10n.adoptFemale, style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
      ],
      onChanged: (v) => setState(() => _sex = v ?? 'unknown'),
      decoration: InputDecoration(
        labelText: l10n.adoptSex,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        filled: true,
        fillColor: isDark ? _darkCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildImageTile({String? imageUrl, File? file, required VoidCallback onRemove, bool isDark = false}) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: _darkCardBorder) : null,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(imageUrl, width: 100, height: 100, fit: BoxFit.cover)
                : Image.file(file!, width: 100, height: 100, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(bool isDark, AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? _rosePrimary.withOpacity(0.1) : _roseLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _rosePrimary.withOpacity(0.3), width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: _rosePrimary.withOpacity(0.7), size: 32),
            const SizedBox(height: 4),
            Text(
              l10n.adoptAddPhotoButton,
              style: TextStyle(fontSize: 11, color: _rosePrimary.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
