import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

      // Charger les quotas et conversations en parallèle
      final results = await Future.wait([
        api.adminGetUserQuotas(userId),
        api.adminGetUserAdoptConversations(userId),
      ]);

      if (mounted) {
        setState(() {
          _quotas = results[0] as Map<String, dynamic>;
          _conversations = results[1] as List<Map<String, dynamic>>;
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

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
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

    return Container(
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
