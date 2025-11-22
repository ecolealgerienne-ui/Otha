import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'package:intl/intl.dart';

final adoptConversationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.adminAdoptGetConversations();
});

class AdminAdoptConversationsScreen extends ConsumerWidget {
  const AdminAdoptConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(adoptConversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations Adoption'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Text('Aucune conversation'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(adoptConversationsProvider),
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final post = conv['post'] as Map<String, dynamic>? ?? {};
                final owner = conv['owner'] as Map<String, dynamic>? ?? {};
                final adopter = conv['adopter'] as Map<String, dynamic>? ?? {};
                final lastMessage = conv['lastMessage'] as Map<String, dynamic>?;
                final updatedAt = DateTime.tryParse(conv['updatedAt']?.toString() ?? '');

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Text(
                        (post['animalName']?.toString() ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      post['animalName']?.toString() ?? 'Sans nom',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '👤 Proprio: ${owner['name']} (${owner['email']})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '🐾 Adoptant: ${adopter['name']} (${adopter['email']})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (lastMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            lastMessage['content']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (conv['hiddenByOwner'] == true || conv['hiddenByAdopter'] == true) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (conv['hiddenByOwner'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Masqué par proprio',
                                    style: TextStyle(fontSize: 10, color: Colors.red),
                                  ),
                                ),
                              if (conv['hiddenByAdopter'] == true) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Masqué par adoptant',
                                    style: TextStyle(fontSize: 10, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: updatedAt != null
                        ? Text(
                            DateFormat('dd/MM HH:mm').format(updatedAt),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          )
                        : null,
                    onTap: () => _showConversationDetails(context, ref, conv['id'].toString()),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erreur: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(adoptConversationsProvider),
                child: const Text('Réessayer'),
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
}

class _ConversationDetailsDialog extends ConsumerWidget {
  final String conversationId;

  const _ConversationDetailsDialog({required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadConversation(api),
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
                      if (conv['hiddenByOwner'] == true || conv['hiddenByAdopter'] == true) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (conv['hiddenByOwner'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Masqué par proprio',
                                  style: TextStyle(fontSize: 10, color: Colors.red),
                                ),
                              ),
                            if (conv['hiddenByAdopter'] == true) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Masqué par adoptant',
                                  style: TextStyle(fontSize: 10, color: Colors.orange),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
