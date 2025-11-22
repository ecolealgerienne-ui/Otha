import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import 'admin_shared.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  bool _loading = false;
  Map<String, dynamic>? _quotas;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _adoptPosts = [];
  bool _loadingConversations = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      final userId = widget.user['id']?.toString() ?? '';

      // Charger les quotas, conversations et annonces en parallèle
      final results = await Future.wait([
        api.adminGetUserQuotas(userId),
        api.adminGetUserAdoptConversations(userId),
        api.adminGetUserAdoptPosts(userId),
      ]);

      if (mounted) {
        setState(() {
          _quotas = results[0] as Map<String, dynamic>;
          _conversations = results[1] as List<Map<String, dynamic>>;
          _adoptPosts = results[2] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetQuotas() async {
    final userId = widget.user['id']?.toString() ?? '';
    final name = _getUserName();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset quotas adoption'),
        content: Text('Réinitialiser les quotas de $name ?\n\n'
            '• Swipes/jour : 0/5\n'
            '• Annonces/jour : 0/1'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final api = ref.read(apiProvider);
      await api.adminResetUserAdoptQuotas(userId);
      await _loadData(); // Recharger les données
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Quotas réinitialisés'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateQuotas() async {
    final userId = widget.user['id']?.toString() ?? '';

    // On va créer un endpoint pour mettre à jour les limites de quotas
    final dailySwipeLimit = TextEditingController(text: '5');
    final dailyPostLimit = TextEditingController(text: '1');

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier les limites quotas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailySwipeLimit,
              decoration: const InputDecoration(
                labelText: 'Limite swipes/jour',
                hintText: 'Ex: 5',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dailyPostLimit,
              decoration: const InputDecoration(
                labelText: 'Limite annonces/jour',
                hintText: 'Ex: 1',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Ces limites seront appliquées pour cet utilisateur uniquement.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final swipeLimit = int.tryParse(dailySwipeLimit.text) ?? 5;
              final postLimit = int.tryParse(dailyPostLimit.text) ?? 1;
              Navigator.pop(ctx, {
                'dailySwipeLimit': swipeLimit,
                'dailyPostLimit': postLimit,
              });
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    // TODO: Créer l'endpoint backend pour modifier les limites
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Fonctionnalité en cours de développement'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _getUserName() {
    final firstName = widget.user['firstName']?.toString() ?? '';
    final lastName = widget.user['lastName']?.toString() ?? '';
    final email = widget.user['email']?.toString() ?? '';

    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return email.isNotEmpty ? email : 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user['firstName']?.toString() ?? '';
    final lastName = user['lastName']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final city = user['city']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'USER';
    final createdAt = user['createdAt']?.toString() ?? '';

    final swipesUsed = _quotas?['swipesUsed'] ?? 0;
    final swipesRemaining = _quotas?['swipesRemaining'] ?? 5;
    final postsUsed = _quotas?['postsUsed'] ?? 0;
    final postsRemaining = _quotas?['postsRemaining'] ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_getUserName()),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte informations utilisateur
                  _Card(
                    title: 'Informations utilisateur',
                    icon: Icons.person,
                    child: Column(
                      children: [
                        _InfoRow('Nom', firstName.isEmpty ? '-' : firstName),
                        _InfoRow('Prénom', lastName.isEmpty ? '-' : lastName),
                        _InfoRow('Email', email.isEmpty ? '-' : email),
                        _InfoRow('Téléphone', phone.isEmpty ? '-' : phone),
                        _InfoRow('Ville', city.isEmpty ? '-' : city),
                        _InfoRow('Rôle', role),
                        _InfoRow('Créé le', _formatDate(createdAt)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carte quotas adoption
                  _Card(
                    title: 'Quotas adoption',
                    icon: Icons.pets,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _QuotaCard(
                                title: 'Swipes (likes)',
                                icon: Icons.favorite,
                                used: swipesUsed,
                                limit: swipesUsed + swipesRemaining,
                                color: Colors.pink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuotaCard(
                                title: 'Annonces',
                                icon: Icons.post_add,
                                used: postsUsed,
                                limit: postsUsed + postsRemaining,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _resetQuotas,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reset quotas'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminColors.salmon,
                                  side: const BorderSide(color: AdminColors.salmon),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _updateQuotas,
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Modifier limites'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AdminColors.salmon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carte statistiques
                  _Card(
                    title: 'Statistiques',
                    icon: Icons.bar_chart,
                    child: Column(
                      children: [
                        _InfoRow('Swipes restants aujourd\'hui', '$swipesRemaining'),
                        _InfoRow('Annonces restantes aujourd\'hui', '$postsRemaining'),
                        const Divider(height: 24),
                        const Text(
                          'Plus de statistiques bientôt...',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carte historique messages
                  _Card(
                    title: 'Conversations adoption (${_conversations.length})',
                    icon: Icons.chat_bubble_outline,
                    child: _conversations.isEmpty
                        ? const Column(
                            children: [
                              SizedBox(height: 8),
                              Text(
                                'Aucune conversation',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              SizedBox(height: 8),
                            ],
                          )
                        : Column(
                            children: [
                              for (final conv in _conversations)
                                _ConversationTile(conversation: conv, currentUserId: widget.user['id']?.toString() ?? ''),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Carte annonces d'adoption
                  _Card(
                    title: 'Annonces d\'adoption (${_adoptPosts.length})',
                    icon: Icons.pets,
                    child: _adoptPosts.isEmpty
                        ? const Column(
                            children: [
                              SizedBox(height: 8),
                              Text(
                                'Aucune annonce',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              SizedBox(height: 8),
                            ],
                          )
                        : Column(
                            children: [
                              for (final post in _adoptPosts)
                                _AdoptPostTile(post: post),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoString;
    }
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AdminColors.salmon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = conversation['post'] as Map<String, dynamic>? ?? {};
    final owner = conversation['owner'] as Map<String, dynamic>? ?? {};
    final adopter = conversation['adopter'] as Map<String, dynamic>? ?? {};
    final lastMessage = conversation['lastMessage'] as Map<String, dynamic>?;

    final animalName = post['animalName']?.toString() ?? post['title']?.toString() ?? 'Animal';
    final ownerName = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim();
    final adopterName = '${adopter['firstName'] ?? ''} ${adopter['lastName'] ?? ''}'.trim();

    final isOwner = owner['id']?.toString() == currentUserId;
    final otherPerson = isOwner ? adopterName : ownerName;
    final role = isOwner ? 'Propriétaire' : 'Adoptant';

    final lastMessageText = lastMessage?['content']?.toString() ?? '';
    final createdAt = conversation['createdAt']?.toString() ?? '';
    final conversationId = conversation['id']?.toString() ?? '';

    // Déterminer s'il y a des signalements
    final reportedByOwner = conversation['reportedByOwner'] == true;
    final reportedByAdopter = conversation['reportedByAdopter'] == true;
    final hasReports = reportedByOwner || reportedByAdopter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: conversationId.isNotEmpty ? () => _showConversationDetails(context, ref, conversationId) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pets, size: 16, color: AdminColors.salmon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      animalName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: role == 'Propriétaire' ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: role == 'Propriétaire' ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Avec: $otherPerson',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              if (lastMessageText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lastMessageText,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (hasReports) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🚩', style: TextStyle(fontSize: 10)),
                          SizedBox(width: 2),
                          Text(
                            'Signalée',
                            style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showConversationDetails(BuildContext context, WidgetRef ref, String conversationId) async {
    showDialog(
      context: context,
      builder: (context) => _ConversationDetailsDialog(conversationId: conversationId),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}

class _QuotaCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int used;
  final int limit;
  final Color color;

  const _QuotaCard({
    required this.title,
    required this.icon,
    required this.used,
    required this.limit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = limit > 0 ? (used / limit) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$used / $limit',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptPostTile extends StatelessWidget {
  final Map<String, dynamic> post;

  const _AdoptPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final animalName = post['animalName']?.toString() ?? post['title']?.toString() ?? 'Animal';
    final species = post['species']?.toString() ?? '';
    final city = post['city']?.toString() ?? '';
    final status = post['status']?.toString() ?? 'PENDING';
    final adoptedAt = post['adoptedAt']?.toString();
    final createdAt = post['createdAt']?.toString() ?? '';
    final images = (post['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final imageUrl = images.isNotEmpty ? images.first['url']?.toString() : null;

    final Color statusColor;
    final String statusText;

    if (adoptedAt != null) {
      statusColor = const Color(0xFF4CAF50);
      statusText = 'Adopté ✓';
    } else {
      switch (status) {
        case 'APPROVED':
          statusColor = Colors.green;
          statusText = 'Approuvée';
          break;
        case 'REJECTED':
          statusColor = Colors.red;
          statusText = 'Refusée';
          break;
        case 'ARCHIVED':
          statusColor = Colors.grey;
          statusText = 'Archivée';
          break;
        default:
          statusColor = Colors.orange;
          statusText = 'En attente';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.pets, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.pets, color: Colors.grey),
            ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animalName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [species, city].where((s) => s.isNotEmpty).join(' • '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date
          Text(
            _formatDate(createdAt),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _ConversationDetailsDialog extends ConsumerWidget {
  final String conversationId;

  const _ConversationDetailsDialog({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadConversation(ref.read(apiProvider)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return AlertDialog(
            title: const Text('Erreur'),
            content: Text('Erreur: ${snapshot.error}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          );
        }

        final conv = snapshot.data!;
        final post = conv['post'] as Map<String, dynamic>? ?? {};
        final owner = conv['owner'] as Map<String, dynamic>? ?? {};
        final adopter = conv['adopter'] as Map<String, dynamic>? ?? {};
        final messages = (conv['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  post['animalName']?.toString() ?? 'Conversation',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info participants
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '👤 Propriétaire: ${owner['name']} (${owner['email']})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🐾 Adoptant: ${adopter['name']} (${adopter['email']})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Signalements
                if (conv['reportedByOwner'] == true || conv['reportedByAdopter'] == true) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange[50],
                      border: Border.all(color: Colors.deepOrange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🚩', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            const Text(
                              'Signalements',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (conv['reportedByAdopter'] == true) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '🐾 Signalé par l\'adoptant',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (conv['reportedAtByAdopter'] != null)
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(
                                          DateTime.parse(conv['reportedAtByAdopter'].toString()),
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Motif: ${conv['reportReasonByAdopter'] ?? 'Non spécifié'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        if (conv['reportedByOwner'] == true) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '👤 Signalé par le propriétaire',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (conv['reportedAtByOwner'] != null)
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(
                                          DateTime.parse(conv['reportedAtByOwner'].toString()),
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Motif: ${conv['reportReasonByOwner'] ?? 'Non spécifié'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Messages
                const Text(
                  'Messages:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text('Aucun message'))
                      : ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final sentByOwner = msg['sentByOwner'] == true;
                            final sentAt = DateTime.tryParse(msg['sentAt']?.toString() ?? '');

                            return Align(
                              alignment: sentByOwner ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                                ),
                                decoration: BoxDecoration(
                                  color: sentByOwner ? Colors.grey[200] : Colors.blueGrey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sentByOwner
                                          ? '${conv['ownerAnonymousName']} (Proprio)'
                                          : '${conv['adopterAnonymousName']} (Adoptant)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      msg['content']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    if (sentAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(sentAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadConversation(ApiClient api) async {
    return await api.adminAdoptGetConversationDetails(conversationId);
  }
}
