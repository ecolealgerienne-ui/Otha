import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import '../../core/session_controller.dart';

// Colors
const _primaryPurple = Color(0xFF6B5BFF);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class CareerChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const CareerChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<CareerChatScreen> createState() => _CareerChatScreenState();
}

class _CareerChatScreenState extends ConsumerState<CareerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _conversationData;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final data = await api.careerGetConversationMessages(widget.conversationId);

      if (mounted) {
        setState(() {
          _conversationData = data;
          final msgs = data['messages'];
          if (msgs is List) {
            _messages = msgs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
          _isLoading = false;
        });
        _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final api = ref.read(apiProvider);
      final result = await api.careerSendMessage(widget.conversationId, content);

      if (mounted) {
        setState(() {
          _messages.add(Map<String, dynamic>.from(result));
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _messageController.text = content;
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF8F8F8);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final session = ref.watch(sessionProvider);
    final currentUserId = session.user?['id']?.toString();

    final post = _conversationData?['post'] as Map<String, dynamic>?;
    final otherUser = _conversationData?['otherUser'] as Map<String, dynamic>?;

    String title = 'Conversation';
    if (post != null) {
      title = post['title']?.toString() ?? 'Annonce';
    }

    String? otherUserName;
    if (otherUser != null) {
      final firstName = otherUser['firstName']?.toString() ?? '';
      final lastName = otherUser['lastName']?.toString() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        otherUserName = '$firstName $lastName'.trim();
      } else if (otherUser['anonymousName'] != null) {
        otherUserName = otherUser['anonymousName'].toString();
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: textPrimary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherUserName ?? 'Conversation',
              style: TextStyle(fontSize: 16, color: textPrimary, fontWeight: FontWeight.bold),
            ),
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(fontSize: 12, color: _primaryPurple),
              ),
          ],
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
                        onPressed: _loadMessages,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Envoyez le premier message !',
                                style: TextStyle(color: textSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final senderId = msg['senderId']?.toString() ?? msg['sender']?['id']?.toString();
                                final isMe = senderId == currentUserId;
                                final content = msg['content']?.toString() ?? '';

                                return _MessageBubble(
                                  content: content,
                                  isMe: isMe,
                                  isDark: isDark,
                                );
                              },
                            ),
                    ),
                    _buildInputBar(cardColor, textPrimary, textSecondary, isDark),
                  ],
                ),
    );
  }

  Widget _buildInputBar(Color cardColor, Color textPrimary, Color? textSecondary, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Votre message...',
                hintStyle: TextStyle(color: textSecondary),
                filled: true,
                fillColor: isDark ? _darkCardBorder : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primaryPurple),
                  )
                : const Icon(Icons.send_rounded, color: _primaryPurple),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.content,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? _primaryPurple
              : isDark
                  ? _darkCard
                  : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
