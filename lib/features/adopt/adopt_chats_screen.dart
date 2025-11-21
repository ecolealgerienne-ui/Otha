// lib/features/adopt/adopt_chats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

const _roseSoft = Color(0xFFFFEEF0);
const _roseAccent = Color(0xFFFF8A8A);

final _requestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.adoptMyIncomingRequests();
});

final _chatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.adoptMyConversations();
});

class AdoptChatsScreen extends ConsumerWidget {
  const AdoptChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: _initialTabFromQuery(context),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Discussions', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: _roseAccent,
            labelColor: _roseAccent,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'Demandes'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chats'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RequestsTab(),
            _ChatsTab(),
          ],
        ),
      ),
    );
  }

  int _initialTabFromQuery(BuildContext context) {
    final q = GoRouterState.of(context).uri.queryParameters['tab'];
    if (q == 'chats') return 1;
    return 0;
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_requestsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(_requestsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const _Empty(
            icon: Icons.inbox_outlined,
            text: 'Aucune demande pour le moment',
            subtitle: 'Les demandes d\'adoption apparaîtront ici',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _RequestTile(item: list[i]),
        );
      },
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _RequestTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = item['post'] as Map<String, dynamic>? ?? {};
    final requester = item['requester'] as Map<String, dynamic>? ?? {};
    final requestId = item['id']?.toString() ?? '';

    final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();
    final anonymousName = (requester['anonymousName'] ?? 'Anonyme').toString();
    final species = (post['species'] ?? '').toString();
    final city = (post['city'] ?? '').toString();

    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Image de l'animal
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: _roseSoft,
                            child: const Icon(Icons.pets, color: _roseAccent),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _roseSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pets, color: _roseAccent),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animalName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              anonymousName,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (species.isNotEmpty || city.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [species, city].where((s) => s.isNotEmpty).join(' • '),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await ref.read(apiProvider).adoptRejectRequest(requestId);
                        ref.invalidate(_requestsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demande refusée'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        final result = await ref.read(apiProvider).adoptAcceptRequest(requestId);
                        ref.invalidate(_requestsProvider);
                        ref.invalidate(_chatsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Demande acceptée ! Chat créé'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _roseAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_chatsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(_chatsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const _Empty(
            icon: Icons.chat_bubble_outline,
            text: 'Aucune conversation',
            subtitle: 'Acceptez des demandes pour démarrer un chat',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final conv = list[i];
            final post = conv['post'] as Map<String, dynamic>? ?? {};
            final conversationId = conv['id']?.toString() ?? '';
            final otherPersonName = (conv['otherPersonName'] ?? 'Anonyme').toString();
            final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();

            final lastMessage = conv['lastMessage'] as Map<String, dynamic>?;
            final lastMessageText = lastMessage != null
                ? (lastMessage['content'] ?? '').toString()
                : 'Aucun message';

            final images = (post['images'] as List<dynamic>?)
                ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
                .where((url) => url != null && url.isNotEmpty)
                .cast<String>()
                .toList() ?? [];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
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
                  onTap: () => context.push('/adopt/chat/$conversationId'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Image de l'animal
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: images.isNotEmpty
                              ? Image.network(
                                  images.first,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: _roseSoft,
                                    child: const Icon(Icons.pets, color: _roseAccent),
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _roseSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.pets, color: _roseAccent),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                animalName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    otherPersonName,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                lastMessageText,
                                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  final String subtitle;

  const _Empty({required this.icon, required this.text, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erreur',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: _roseAccent),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}
