// lib/features/adopt/adopt_chats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

const _kInk = Color(0xFF1F2328);
const _kCoral = Color(0xFFF36C6C);

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
        appBar: AppBar(
          title: const Text('Discussions'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'Demandes'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Confirmés'),
          ]),
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
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const _Empty(text: 'Aucune demande pour le moment.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.pets)),
        title: Text(animalName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('De: $anonymousName\n${[species, city].where((s) => s.isNotEmpty).join(' · ')}'),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                try {
                  await ref.read(apiProvider).adoptRejectRequest(requestId);
                  ref.invalidate(_requestsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demande refusée')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child: const Text('Refuser'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final result = await ref.read(apiProvider).adoptAcceptRequest(requestId);
                  ref.invalidate(_requestsProvider);
                  ref.invalidate(_chatsProvider);
                  if (context.mounted) {
                    final convId = result['conversationId']?.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demande acceptée ! Chat créé')),
                    );
                    // TODO: Naviguer vers le chat si on veut
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child: const Text('Accepter'),
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
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const _Empty(text: 'Aucun chat confirmé.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                title: Text('$animalName • $otherPersonName', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(lastMessageText, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  // TODO: Naviguer vers l'écran de chat
                  context.push('/adopt/chat/$conversationId');
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: Colors.black54)));
}