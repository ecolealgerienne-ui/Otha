import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';

const _coral = Color(0xFFF2968F);
const _coralLight = Color(0xFFFFE8E8);

class SupportConversationScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const SupportConversationScreen({super.key, required this.ticketId});

  @override
  ConsumerState<SupportConversationScreen> createState() => _SupportConversationScreenState();
}

class _SupportConversationScreenState extends ConsumerState<SupportConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _ticket;
  bool _loading = true;
  bool _sending = false;
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
      final result = await api.getSupportTicketMessages(widget.ticketId);
      final messages = (result['messages'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      if (mounted) {
        setState(() {
          _messages = messages;
          _ticket = result;
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

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sending = true);

    try {
      final api = ref.read(apiProvider);
      await api.sendSupportMessage(widget.ticketId, content);

      _messageController.clear();
      await _loadMessages(silent: true);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'Nouveau';
      case 'IN_PROGRESS':
        return 'En cours';
      case 'WAITING_USER':
        return 'En attente de votre réponse';
      case 'RESOLVED':
        return 'Résolu';
      case 'CLOSED':
        return 'Fermé';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'WAITING_USER':
        return Colors.purple;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _ticket?['status']?.toString() ?? 'OPEN';
    final isClosed = status == 'CLOSED' || status == 'RESOLVED';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ticket?['subject']?.toString() ?? 'Support',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _coral))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Erreur de chargement', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadMessages, child: const Text('Réessayer')),
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
                                'Aucun message',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _messages.length,
                              itemBuilder: (ctx, i) {
                                final msg = _messages[i];
                                final isFromAdmin = msg['isFromAdmin'] == true;
                                final content = msg['content']?.toString() ?? '';
                                final createdAt = DateTime.tryParse(msg['createdAt']?.toString() ?? '');
                                final timeStr = createdAt != null
                                    ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                                    : '';
                                final senderName = (msg['sender'] as Map<String, dynamic>?)?['name']?.toString() ?? '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    mainAxisAlignment: isFromAdmin
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (isFromAdmin) ...[
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _coral.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.support_agent,
                                            size: 18,
                                            color: _coral,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isFromAdmin ? Colors.white : _coral,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(18),
                                              topRight: const Radius.circular(18),
                                              bottomLeft: Radius.circular(isFromAdmin ? 4 : 18),
                                              bottomRight: Radius.circular(isFromAdmin ? 18 : 4),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (isFromAdmin && senderName.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text(
                                                    senderName,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: _coral,
                                                    ),
                                                  ),
                                                ),
                                              Text(
                                                content,
                                                style: TextStyle(
                                                  color: isFromAdmin ? Colors.black87 : Colors.white,
                                                  fontSize: 15,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  color: isFromAdmin
                                                      ? Colors.grey.shade500
                                                      : Colors.white.withOpacity(0.7),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Input area
                    if (!isClosed)
                      Container(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                        ),
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
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textCapitalization: TextCapitalization.sentences,
                                maxLines: 4,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: 'Votre message...',
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _sending ? null : _sendMessage,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _sending ? Colors.grey : _coral,
                                  shape: BoxShape.circle,
                                ),
                                child: _sending
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Closed ticket message
                    if (isClosed)
                      Container(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        color: Colors.grey.shade200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              status == 'RESOLVED' ? Icons.check_circle : Icons.block,
                              color: _getStatusColor(status),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status == 'RESOLVED'
                                  ? 'Ce ticket a été résolu'
                                  : 'Ce ticket est fermé',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
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
