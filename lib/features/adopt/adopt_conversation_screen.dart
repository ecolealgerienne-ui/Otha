// lib/features/adopt/adopt_conversation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

const _rosePrimary = Color(0xFFFF6B6B);
const _roseLight = Color(0xFFFFE8E8);
const _greenSuccess = Color(0xFF4CD964);

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
  bool _proposingAdoption = false;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
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
          _conversation = result;
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
        _showSnackBar('Erreur: $e', Colors.red);
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

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _proposeAdoption() async {
    final post = _conversation?['post'] as Map<String, dynamic>? ?? {};
    final otherPersonName = (_conversation?['otherPersonName'] ?? 'cette personne').toString();
    final animalName = (post['animalName'] ?? post['title'] ?? 'cet animal').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _greenSuccess.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: _greenSuccess),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Proposer l\'adoption')),
          ],
        ),
        content: Text(
          'Voulez-vous proposer l\'adoption de $animalName à $otherPersonName ?\n\n'
          'Cette personne recevra une notification pour confirmer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _greenSuccess,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.favorite, size: 18),
            label: const Text('Proposer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _proposingAdoption = true);

    try {
      final api = ref.read(apiProvider);
      final postId = post['id']?.toString();
      final adopterId = _conversation?['otherUserId']?.toString();

      if (postId != null) {
        await api.markAdoptPostAsAdopted(postId, adoptedById: adopterId);
        _showSnackBar('Proposition envoyée à $otherPersonName', _greenSuccess);
        await _loadMessages();
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _proposingAdoption = false);
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la conversation'),
        content: const Text('Cette conversation sera masquée de votre liste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiProvider);
      await api.adoptHideConversation(widget.conversationId);
      _showSnackBar('Conversation supprimée', Colors.grey);
      if (mounted) context.pop();
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _conversation?['post'] as Map<String, dynamic>? ?? {};
    final otherPersonName = (_conversation?['otherPersonName'] ?? 'Anonyme').toString();
    final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();
    final isOwner = _conversation?['isOwner'] == true;
    final isAdopted = post['adoptedAt'] != null;
    final pendingConfirmation = _conversation?['pendingAdoptionConfirmation'] == true;

    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // Custom header with animal info
          _buildHeader(context, animalName, otherPersonName, images),

          // Owner action banner (propose adoption)
          if (isOwner && !isAdopted && !pendingConfirmation)
            _buildAdoptionBanner(otherPersonName),

          // Pending confirmation banner
          if (pendingConfirmation)
            _buildPendingBanner(isOwner),

          // Adopted banner
          if (isAdopted)
            _buildAdoptedBanner(),

          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _rosePrimary))
                : _error != null
                    ? _buildErrorState()
                    : _buildMessagesList(),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String animalName, String otherPersonName, List<String> images) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 8, left: 12, right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _roseLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          // Animal avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
                  )
                : _buildPlaceholderAvatar(),
          ),
          const SizedBox(width: 12),
          // Names
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
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      otherPersonName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            onPressed: _deleteConversation,
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 44,
      height: 44,
      color: _roseLight,
      child: const Icon(Icons.pets, color: _rosePrimary, size: 24),
    );
  }

  Widget _buildAdoptionBanner(String otherPersonName) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenSuccess.withOpacity(0.1), _greenSuccess.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _greenSuccess.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _greenSuccess.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: _greenSuccess, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prêt à finaliser ?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Proposez l\'adoption à $otherPersonName',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _proposingAdoption ? null : _proposeAdoption,
            style: FilledButton.styleFrom(
              backgroundColor: _greenSuccess,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _proposingAdoption
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Proposer', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(bool isOwner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOwner
                  ? 'En attente de confirmation de l\'adoptant...'
                  : 'Une proposition d\'adoption vous attend !',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdoptedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _greenSuccess.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _greenSuccess.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: _greenSuccess, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Adoption confirmée !',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _greenSuccess,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Erreur: $_error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadMessages,
            style: FilledButton.styleFrom(backgroundColor: _rosePrimary),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucun message',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Commencez la conversation !',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    final post = _conversation?['post'] as Map<String, dynamic>? ?? {};

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['sentByMe'] == true;
        final content = (message['content'] ?? '').toString();
        final timestamp = message['sentAt'] as String?;

        final isCongratulationsMessage = content.contains('🎉 Félicitations') ||
            content.contains('changé une vie');

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
    );
  }

  Widget _buildInputBar() {
    return Container(
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
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _rosePrimary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _sending ? null : _sendMessage,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
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
          SnackBar(
            content: const Text('🎉 Adoption confirmée !'),
            backgroundColor: _greenSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        widget.onConfirmationChanged?.call();
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

  Future<void> _handleDecline() async {
    setState(() => _loading = true);

    try {
      final api = ref.read(apiProvider);
      await api.adoptDeclineAdoption(widget.conversationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adoption refusée')),
        );
        widget.onConfirmationChanged?.call();
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
          color: widget.isMe ? _rosePrimary : Colors.white,
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
            // Confirmation buttons
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Refuser', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _handleAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: _greenSuccess,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Accepter', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.isConfirmationMessage && _loading) ...[
              const SizedBox(height: 12),
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ],
            // Create pet profile button
            if (widget.isCongratulationsMessage && widget.adoptionPost != null && !widget.isMe) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final postId = widget.adoptionPost!['id']?.toString();
                    if (postId != null) {
                      try {
                        await ref.read(apiProvider).markAdoptPetProfileCreated(postId);
                      } catch (_) {}
                    }
                    if (context.mounted) {
                      context.push('/pets/add', extra: widget.adoptionPost);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _greenSuccess,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
