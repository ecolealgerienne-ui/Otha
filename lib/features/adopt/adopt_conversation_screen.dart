// lib/features/adopt/adopt_conversation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

final _conversationProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, conversationId) async {
  final api = ref.read(apiProvider);
  return await api.adoptGetConversationMessages(conversationId);
});

class AdoptConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const AdoptConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<AdoptConversationScreen> createState() => _AdoptConversationScreenState();
}

class _AdoptConversationScreenState extends ConsumerState<AdoptConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).adoptSendMessage(widget.conversationId, text);
      _messageController.clear();
      ref.invalidate(_conversationProvider(widget.conversationId));

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync = ref.watch(_conversationProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        title: conversationAsync.when(
          data: (conv) {
            final otherPersonName = (conv['otherPersonName'] ?? 'Chat').toString();
            return Text(otherPersonName);
          },
          loading: () => const Text('Chat'),
          error: (_, __) => const Text('Chat'),
        ),
      ),
      body: conversationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (conversation) {
          final messages = conversation['messages'] as List<dynamic>? ?? [];
          final myAnonymousName = (conversation['myAnonymousName'] ?? 'Vous').toString();
          final otherPersonName = (conversation['otherPersonName'] ?? 'Anonyme').toString();

          return Column(
            children: [
              // Messages list
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('Aucun message'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final msg = messages[i] as Map<String, dynamic>;
                          final sentByMe = msg['sentByMe'] == true;
                          final content = (msg['content'] ?? '').toString();
                          final senderName = (msg['senderName'] ?? '').toString();

                          return Align(
                            alignment: sentByMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: sentByMe ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: sentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    senderName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(content),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Input field
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Votre message...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_sending,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
