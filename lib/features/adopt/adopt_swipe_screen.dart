// lib/features/adopt/adopt_swipe_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'dart:math' as math;

final _feedProvider = StateNotifierProvider<_FeedNotifier, _FeedState>((ref) {
  return _FeedNotifier(ref);
});

final _quotasProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiProvider);
  return await api.adoptMyQuotas();
});

class _FeedState {
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final String? error;
  final int currentIndex;

  _FeedState({
    this.posts = const [],
    this.loading = false,
    this.error,
    this.currentIndex = 0,
  });

  _FeedState copyWith({
    List<Map<String, dynamic>>? posts,
    bool? loading,
    String? error,
    int? currentIndex,
  }) {
    return _FeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class _FeedNotifier extends StateNotifier<_FeedState> {
  final Ref ref;

  _FeedNotifier(this.ref) : super(_FeedState()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    if (state.loading) return;

    state = state.copyWith(loading: true, error: null);
    try {
      final api = ref.read(apiProvider);
      final result = await api.adoptFeed(limit: 10);
      final posts = (result['data'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      state = state.copyWith(posts: posts, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void nextCard() {
    if (state.currentIndex < state.posts.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }

    // Load more if near the end
    if (state.currentIndex >= state.posts.length - 2 && !state.loading) {
      loadFeed();
    }
  }

  void reset() {
    state = _FeedState();
    loadFeed();
  }
}

class AdoptSwipeScreen extends ConsumerWidget {
  const AdoptSwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(_feedProvider);
    final quotasAsync = ref.watch(_quotasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adopter'),
        actions: [
          quotasAsync.when(
            data: (quotas) {
              final swipesRemaining = quotas['swipesRemaining'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, size: 18),
                      const SizedBox(width: 4),
                      Text('$swipesRemaining/5'),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: feedState.loading && feedState.posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : feedState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Erreur: ${feedState.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(_feedProvider.notifier).loadFeed(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : feedState.posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pets, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Plus d\'annonces pour le moment'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.read(_feedProvider.notifier).reset(),
                            child: const Text('Recharger'),
                          ),
                        ],
                      ),
                    )
                  : _SwipeCards(
                      posts: feedState.posts,
                      currentIndex: feedState.currentIndex,
                    ),
    );
  }
}

class _SwipeCards extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int currentIndex;

  const _SwipeCards({
    required this.posts,
    required this.currentIndex,
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
        ref.invalidate(_quotasProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
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
      ref.read(_feedProvider.notifier).nextCard();
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
              padding: const EdgeInsets.all(20),
              child: _PostCard(post: widget.posts[widget.currentIndex + 1]),
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
                    padding: const EdgeInsets.all(16),
                    child: _PostCard(post: post),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Swipe indicators
        if (_isDragging && _dragX.abs() > 30)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                alignment: _dragX > 0 ? Alignment.centerLeft : Alignment.centerRight,
                padding: const EdgeInsets.all(32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _dragX > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _dragX > 0 ? Icons.favorite : Icons.close,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),

        // Bottom buttons
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                heroTag: 'pass',
                onPressed: () => _handleSwipe(false),
                backgroundColor: Colors.red,
                child: const Icon(Icons.close, size: 32),
              ),
              const SizedBox(width: 32),
              FloatingActionButton(
                heroTag: 'like',
                onPressed: () => _handleSwipe(true),
                backgroundColor: Colors.green,
                child: const Icon(Icons.favorite, size: 32),
              ),
            ],
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

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (images.isNotEmpty)
                  Image.network(
                    images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 64, color: Colors.grey),
                    ),
                  )
                else
                  Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.pets, size: 64, color: Colors.grey),
                  ),

                // Adopted badge
                if (adoptedAt != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
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
                  ),
              ],
            ),
          ),

          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    animalName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [species, ageText, city].where((s) => s.isNotEmpty).join(' • '),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
