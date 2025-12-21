// lib/features/adopt/adopt_chats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _rosePrimary = Color(0xFFFF6B6B);
const _roseLight = Color(0xFFFFE8E8);
const _redDelete = Color(0xFFFF3B5C);

class AdoptChatsScreen extends ConsumerStatefulWidget {
  const AdoptChatsScreen({super.key});

  @override
  ConsumerState<AdoptChatsScreen> createState() => _AdoptChatsScreenState();
}

class _AdoptChatsScreenState extends ConsumerState<AdoptChatsScreen> {
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final results = await Future.wait([
        api.adoptMyIncomingRequests(),
        api.adoptMyConversations(),
      ]);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(results[0]);
          _chats = List<Map<String, dynamic>>.from(results[1]);
          _loading = false;
        });
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

  Future<void> _acceptRequest(String requestId) async {
    try {
      final api = ref.read(apiProvider);
      await api.adoptAcceptRequest(requestId);
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.adoptRequestAccepted, Colors.green);
      _loadData(); // Refresh instant
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n.adoptError}: $e', Colors.red);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      final api = ref.read(apiProvider);
      await api.adoptRejectRequest(requestId);
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.adoptRequestRejected, Colors.orange);
      _loadData(); // Refresh instant
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n.adoptError}: $e', Colors.red);
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      final api = ref.read(apiProvider);
      await api.adoptHideConversation(conversationId);
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.adoptConversationDeleted, Colors.grey);
      _loadData(); // Refresh instant
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar('${l10n.adoptError}: $e', Colors.red);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: topPadding + 8, left: 16, right: 16, bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _roseLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: _rosePrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.adoptMessages,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_requests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _rosePrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_requests.length} ${_requests.length > 1 ? l10n.adoptNews : l10n.adoptNew}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: _roseLight,
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(color: _rosePrimary),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? _ErrorState(error: _error!, onRetry: _loadData)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: _rosePrimary,
                        child: _requests.isEmpty && _chats.isEmpty
                            ? _EmptyState(onRefresh: _loadData)
                            : ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  // Section: Nouvelles demandes
                                  if (_requests.isNotEmpty) ...[
                                    _SectionHeader(
                                      title: l10n.adoptNewRequests,
                                      count: _requests.length,
                                    ),
                                    SizedBox(
                                      height: 175,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        itemCount: _requests.length,
                                        itemBuilder: (context, index) {
                                          return _RequestCard(
                                            request: _requests[index],
                                            onAccept: () {
                                              final id = _requests[index]['id']?.toString();
                                              if (id != null) _acceptRequest(id);
                                            },
                                            onReject: () {
                                              final id = _requests[index]['id']?.toString();
                                              if (id != null) _rejectRequest(id);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  // Section: Messages
                                  if (_chats.isNotEmpty) ...[
                                    _SectionHeader(
                                      title: l10n.adoptConversations,
                                      count: _chats.length,
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _chats.length,
                                      itemBuilder: (context, index) {
                                        return _ChatTile(
                                          chat: _chats[index],
                                          onTap: () {
                                            final id = _chats[index]['id']?.toString();
                                            if (id != null) context.push('/adopt/chat/$id');
                                          },
                                          onDelete: () {
                                            final id = _chats[index]['id']?.toString();
                                            if (id != null) _deleteConversation(id);
                                          },
                                        );
                                      },
                                    ),
                                  ],

                                  const SizedBox(height: 100),
                                ],
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

// Section header
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Request card (horizontal scroll)
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final post = request['post'] as Map<String, dynamic>? ?? {};
    final requester = request['requester'] as Map<String, dynamic>? ?? {};
    final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();
    final requesterName = (requester['anonymousName'] ?? 'Anonyme').toString();

    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image + badge NEW
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: images.isNotEmpty
                    ? Image.network(
                        images.first,
                        width: 140,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 140,
                          height: 80,
                          color: _roseLight,
                          child: const Icon(Icons.pets, color: _rosePrimary),
                        ),
                      )
                    : Container(
                        width: 140,
                        height: 80,
                        color: _roseLight,
                        child: const Icon(Icons.pets, color: _rosePrimary),
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rosePrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    animalName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    requesterName,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onReject,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: onAccept,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CD964).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check, size: 16, color: Color(0xFF4CD964)),
                    ),
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

// Chat tile with swipe to delete
class _ChatTile extends StatefulWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  double _dragOffset = 0;
  bool _showDeleteButton = false;
  static const double _deleteButtonWidth = 80;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-_deleteButtonWidth, 0);
      _showDeleteButton = _dragOffset < -20;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    setState(() {
      if (_dragOffset < -_deleteButtonWidth / 2) {
        _dragOffset = -_deleteButtonWidth;
        _showDeleteButton = true;
      } else {
        _dragOffset = 0;
        _showDeleteButton = false;
      }
    });
  }

  void _resetSwipe() {
    setState(() {
      _dragOffset = 0;
      _showDeleteButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.chat['post'] as Map<String, dynamic>? ?? {};
    final otherPersonName = (widget.chat['otherPersonName'] ?? 'Anonyme').toString();
    final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();

    final lastMessage = widget.chat['lastMessage'] as Map<String, dynamic>?;
    final lastMessageText = lastMessage != null
        ? (lastMessage['content'] ?? '').toString()
        : 'Aucun message';
    final lastMessageTime = lastMessage?['sentAt'] as String?;

    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          // Delete button (behind)
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: _redDelete,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: _deleteButtonWidth,
                alignment: Alignment.center,
                child: InkWell(
                  onTap: () {
                    _resetSwipe();
                    widget.onDelete();
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 24),
                      SizedBox(height: 2),
                      Text(
                        'Supprimer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Chat tile (front)
          GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onTap: () {
              if (_showDeleteButton) {
                _resetSwipe();
              } else {
                widget.onTap();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.translationValues(_dragOffset, 0, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: images.isNotEmpty
                          ? Image.network(
                              images.first,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: _roseLight,
                                child: const Icon(Icons.pets, color: _rosePrimary),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: _roseLight,
                              child: const Icon(Icons.pets, color: _rosePrimary),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  animalName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (lastMessageTime != null)
                                Text(
                                  _formatTime(lastMessageTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                otherPersonName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMessageText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}j';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

// Empty state
class _EmptyState extends ConsumerWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: _roseLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, size: 56, color: _rosePrimary),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.adoptNoMessages,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.adoptNoMessagesDesc,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: _rosePrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.adoptRefresh),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Error state
class _ErrorState extends ConsumerWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              l10n.adoptLoadingError,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _rosePrimary),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.adoptRetry),
            ),
          ],
        ),
      ),
    );
  }
}
