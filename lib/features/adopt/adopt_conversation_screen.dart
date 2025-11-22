// lib/features/adopt/adopt_conversation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

class AdoptConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const AdoptConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<AdoptConversationScreen> createState() => _AdoptConversationScreenState();
}

class _AdoptConversationScreenState extends ConsumerState<AdoptConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _conversation;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Polling toutes les 5 secondes pour actualiser les messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_loading && !_sending) {
        _loadMessages(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiProvider);
      final result = await api.adoptGetConversationMessages(widget.conversationId);
      final messages = (result['messages'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      if (mounted) {
        setState(() {
          _messages = messages;
          _conversation = result; // Le backend renvoie directement l'objet, pas {conversation: {...}}
          _loading = false;
        });
        if (!silent) {
          _scrollToBottom();
        }
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final api = ref.read(apiProvider);
      await api.adoptSendMessage(widget.conversationId, content);

      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _conversation?['post'] as Map<String, dynamic>? ?? {};
    final otherPersonName = (_conversation?['otherPersonName'] ?? 'Anonyme').toString();
    final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              animalName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              otherPersonName,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $_error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadMessages,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Messages list
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun message. Commencez la conversation !',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isMe = message['sentByMe'] == true;
                                final content = (message['content'] ?? '').toString();
                                final timestamp = message['sentAt'] as String?;

                                // Détecter le message de félicitations
                                final isCongratulationsMessage = content.contains('🎉 Félicitations') ||
                                    content.contains('changé une vie');

                                // Détecter le message de confirmation d'adoption
                                final isConfirmationMessage = content.contains('🐾 Voulez-vous adopter') &&
                                    (_conversation?['pendingAdoptionConfirmation'] == true) &&
                                    !isMe;

                                return _MessageBubble(
                                  content: content,
                                  isMe: isMe,
                                  timestamp: timestamp,
                                  isCongratulationsMessage: isCongratulationsMessage,
                                  adoptionPost: isCongratulationsMessage ? post : null,
                                  isConfirmationMessage: isConfirmationMessage,
                                  conversationId: widget.conversationId,
                                  onConfirmationChanged: () => _loadMessages(),
                                );
                              },
                            ),
                    ),

                    // Input bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 12,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Votre message...',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFFFF8A8A),
                            child: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                    onPressed: _sendMessage,
                                    padding: EdgeInsets.zero,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _MessageBubble extends ConsumerStatefulWidget {
  final String content;
  final bool isMe;
  final String? timestamp;
  final bool isCongratulationsMessage;
  final Map<String, dynamic>? adoptionPost;
  final bool isConfirmationMessage;
  final String conversationId;
  final VoidCallback? onConfirmationChanged;

  const _MessageBubble({
    required this.content,
    required this.isMe,
    this.timestamp,
    this.isCongratulationsMessage = false,
    this.adoptionPost,
    this.isConfirmationMessage = false,
    required this.conversationId,
    this.onConfirmationChanged,
  });

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  bool _loading = false;

  Future<void> _handleAccept() async {
    setState(() => _loading = true);

    try {
      final api = ref.read(apiProvider);
      await api.adoptConfirmAdoption(widget.conversationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Félicitations ! L\'adoption est confirmée !'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        widget.onConfirmationChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _loading = true);

    try {
      final api = ref.read(apiProvider);
      await api.adoptDeclineAdoption(widget.conversationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adoption refusée. L\'annonce reste disponible.'),
          ),
        );
        widget.onConfirmationChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: widget.isMe ? const Color(0xFFFF8A8A) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.content,
              style: TextStyle(
                color: widget.isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (widget.timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(widget.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMe ? Colors.white70 : Colors.grey[500],
                ),
              ),
            ],
            // Boutons "Accepter" / "Refuser" pour le message de confirmation d'adoption
            if (widget.isConfirmationMessage && !_loading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleDecline,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Colors.grey),
                        foregroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Refuser', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _handleAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Accepter', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.isConfirmationMessage && _loading) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            // Bouton "Créer le profil" pour le message de félicitations
            if (widget.isCongratulationsMessage && widget.adoptionPost != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    // Marquer le profil pet comme en cours de création
                    final postId = widget.adoptionPost!['id']?.toString();
                    if (postId != null) {
                      try {
                        await ref.read(apiProvider).markAdoptPetProfileCreated(postId);
                      } catch (e) {
                        // Ignorer l'erreur, on laisse l'utilisateur créer le profil
                      }
                    }

                    // Naviguer vers le pet onboarding avec les données d'adoption
                    if (context.mounted) {
                      context.push('/pets/add', extra: widget.adoptionPost);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.pets, size: 20),
                  label: const Text('Créer le profil'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
