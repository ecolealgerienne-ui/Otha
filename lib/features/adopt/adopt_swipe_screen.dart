// lib/features/adopt/adopt_swipe_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

final _quotasProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.adoptMyQuotas();
});

class AdoptSwipeScreen extends ConsumerStatefulWidget {
  const AdoptSwipeScreen({super.key});

  @override
  ConsumerState<AdoptSwipeScreen> createState() => _AdoptSwipeScreenState();
}

class _AdoptSwipeScreenState extends ConsumerState<AdoptSwipeScreen> {
  List<Map<String, dynamic>> _posts = [];
  int _currentIndex = 0;
  bool _loading = false;
  String? _error;
  String? _backendMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final result = await api.adoptFeed(limit: 10);
      final posts = (result['items'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _loading = false;
          _backendMessage = posts.isEmpty ? 'Aucune annonce disponible' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _backendMessage = 'Erreur chargement: ${e.toString()}';
        });
      }
    }
  }

  void _nextCard() {
    if (_currentIndex < _posts.length - 1) {
      setState(() {
        _currentIndex++;
        _backendMessage = null;
      });
    }

    // Load more if near the end
    if (_currentIndex >= _posts.length - 2 && !_loading) {
      _loadFeed();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _backendMessage = null;
      });
    }
  }

  void _reset() {
    setState(() {
      _posts.clear();
      _currentIndex = 0;
      _error = null;
      _backendMessage = null;
    });
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final quotasAsync = ref.watch(_quotasProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // Main content
          _loading && _posts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 24),
                          Text(
                            'Plus d\'annonces pour le moment',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Recharger'),
                          ),
                        ],
                      ),
                    )
                  : _SwipeCards(
                      posts: _posts,
                      currentIndex: _currentIndex,
                      onNext: _nextCard,
                      onPrevious: _previousCard,
                      onMessage: (msg) => setState(() => _backendMessage = msg),
                      onInvalidateQuotas: () => ref.invalidate(_quotasProvider),
                    ),

          // Previous button (top left)
          if (_posts.isNotEmpty && _currentIndex > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _previousCard,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),

          // Quotas indicator (top right)
          quotasAsync.when(
            data: (quotas) {
              final swipesRemaining = quotas['swipesRemaining'] ?? 0;
              return Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '$swipesRemaining/5',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),

          // Backend message (bottom)
          if (_backendMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _backendMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeCards extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(String) onMessage;
  final VoidCallback onInvalidateQuotas;

  const _SwipeCards({
    required this.posts,
    required this.currentIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onMessage,
    required this.onInvalidateQuotas,
  });

  @override
  ConsumerState<_SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends ConsumerState<_SwipeCards> {
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
      _isDragging = true;
    });
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_dragX.abs() > 100) {
      final isLike = _dragX > 0;
      await _handleSwipe(isLike);
    } else {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isDragging = false;
      });
    }
  }

  Future<void> _handleSwipe(bool isLike) async {
    // Animate out
    setState(() {
      _dragX = isLike ? 500 : -500;
    });

    final postId = widget.posts[widget.currentIndex]['id']?.toString();
    if (postId != null) {
      try {
        await ref.read(apiProvider).adoptSwipe(
          postId: postId,
          action: isLike ? 'LIKE' : 'PASS',
        );
        widget.onInvalidateQuotas();
        widget.onMessage(isLike ? '❤️ Demande envoyée' : 'Passé');
      } catch (e) {
        final errorMsg = e.toString();

        // Détecter les différentes erreurs
        if (errorMsg.contains('403') || errorMsg.contains('Cannot swipe own post')) {
          widget.onMessage('❌ Cette annonce vous appartient');
        } else if (errorMsg.contains('quota') || errorMsg.contains('Quota') ||
                   errorMsg.contains('limite') || errorMsg.contains('limit')) {
          if (isLike) {
            widget.onMessage('⏳ Quota atteint : 5 likes maximum par jour');
          } else {
            widget.onMessage('⏳ Quota atteint pour aujourd\'hui');
          }
        } else if (errorMsg.contains('400')) {
          widget.onMessage('⚠️ Requête invalide. Veuillez réessayer');
        } else if (errorMsg.contains('429')) {
          widget.onMessage('⏳ Trop de requêtes. Patientez un moment');
        } else if (errorMsg.contains('500') || errorMsg.contains('502') || errorMsg.contains('503')) {
          widget.onMessage('🔧 Serveur temporairement indisponible');
        } else {
          widget.onMessage('❌ Erreur: ${errorMsg.length > 50 ? errorMsg.substring(0, 50) + '...' : errorMsg}');
        }
      }
    }

    // Wait for animation then show next
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isDragging = false;
      });
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentIndex >= widget.posts.length) {
      return const Center(child: Text('Plus d\'annonces'));
    }

    final post = widget.posts[widget.currentIndex];
    final screenSize = MediaQuery.of(context).size;

    final angle = (_dragX / screenSize.width) * 0.4;
    final opacity = 1 - (_dragX.abs() / screenSize.width);

    return Stack(
      children: [
        // Next card (preview)
        if (widget.currentIndex + 1 < widget.posts.length)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Transform.scale(
                scale: 0.92,
                child: _PostCard(post: widget.posts[widget.currentIndex + 1]),
              ),
            ),
          ),

        // Current card
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(_dragX, _dragY * 0.3),
            child: Transform.rotate(
              angle: angle,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _PostCard(post: post),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Swipe indicators
        if (_isDragging && _dragX.abs() > 50)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                alignment: _dragX > 0 ? Alignment.centerLeft : Alignment.centerRight,
                padding: const EdgeInsets.all(48),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (_dragX > 0 ? Colors.green : Colors.red).withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _dragX > 0 ? Icons.favorite : Icons.close,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final images = (post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    final animalName = (post['animalName'] ?? post['title'] ?? 'Animal').toString();
    final species = (post['species'] ?? '').toString();
    final city = (post['city'] ?? '').toString();
    final ageMonths = post['ageMonths'] as int?;
    final description = (post['description'] ?? '').toString();
    final adoptedAt = post['adoptedAt'];

    final ageText = ageMonths != null
        ? ageMonths < 12
            ? '$ageMonths mois'
            : '${(ageMonths / 12).floor()} an${ageMonths >= 24 ? 's' : ''}'
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image (full screen)
            if (images.isNotEmpty)
              Image.network(
                images.first,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.pets, size: 100, color: Colors.grey),
                ),
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.pets, size: 100, color: Colors.grey),
              ),

            // Gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Info overlay (bottom)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            animalName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (adoptedAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ADOPTÉ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if ([species, ageText, city].where((s) => s.isNotEmpty).isNotEmpty)
                      Text(
                        [species, ageText, city].where((s) => s.isNotEmpty).join(' • '),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
