// lib/features/adopt/adopt_swipe_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _rosePrimary = Color(0xFFFF6B6B);
const _roseLight = Color(0xFFFFE8E8);
const _greenLike = Color(0xFF4CD964);
const _redNope = Color(0xFFFF3B5C);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

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
          _backendMessage = posts.isEmpty ? AppLocalizations.of(context).adoptNoAds : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _backendMessage = '${AppLocalizations.of(context).adoptErrorLoading}: ${e.toString()}';
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

  void _handleSwipeComplete() {
    // Recharger complètement le feed après un swipe
    setState(() {
      _posts.clear();
      _currentIndex = 0;
      _backendMessage = null;
    });
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final quotasAsync = ref.watch(_quotasProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header style Tinder
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
                // Back button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/home'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : _rosePrimary, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Logo/Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        l10n.adoptHeader,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Quotas indicator
                quotasAsync.when(
                  data: (quotas) {
                    final swipesRemaining = quotas['swipesRemaining'] ?? 0;
                    final total = 5;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 18,
                            color: swipesRemaining > 0 ? _rosePrimary : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$swipesRemaining/$total',
                            style: TextStyle(
                              color: swipesRemaining > 0 ? _rosePrimary : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(width: 60),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: _loading && _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(color: _rosePrimary),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.adoptSearching,
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _posts.isEmpty
                    ? _EmptyState(onRefresh: _reset, isDark: isDark)
                    : _SwipeCards(
                        posts: _posts,
                        currentIndex: _currentIndex,
                        onNext: _nextCard,
                        onPrevious: _previousCard,
                        onMessage: (msg) => setState(() => _backendMessage = msg),
                        onInvalidateQuotas: () => ref.invalidate(_quotasProvider),
                        onSwipeComplete: _handleSwipeComplete,
                      ),
          ),

          // Backend message (toast style)
          if (_backendMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _backendMessage!.contains('❤️')
                    ? _greenLike.withOpacity(0.9)
                    : _backendMessage!.contains('❌') || _backendMessage!.contains('⏳')
                        ? Colors.orange.withOpacity(0.9)
                        : Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _backendMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// Empty state widget
class _EmptyState extends ConsumerWidget {
  final VoidCallback onRefresh;
  final bool isDark;
  const _EmptyState({required this.onRefresh, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? _rosePrimary.withOpacity(0.2) : _roseLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, size: 64, color: _rosePrimary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adoptNoAdsTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adoptNoAdsDesc,
              style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: _rosePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.adoptRefresh, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
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
  final VoidCallback onSwipeComplete;

  const _SwipeCards({
    required this.posts,
    required this.currentIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onMessage,
    required this.onInvalidateQuotas,
    required this.onSwipeComplete,
  });

  @override
  ConsumerState<_SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends ConsumerState<_SwipeCards> with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _dragY = 0;
  bool _isDragging = false;
  bool _isAnimating = false;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
      _isDragging = true;
    });
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_isAnimating) return;
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
    if (_isAnimating) return;
    _isAnimating = true;

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
        final l10n = AppLocalizations.of(context);
        widget.onMessage(isLike ? l10n.adoptRequestSent : l10n.adoptPassed);

        // Demander le rechargement du feed après le swipe
        widget.onSwipeComplete();
      } catch (e) {
        final l10n = AppLocalizations.of(context);
        final errorMsg = e.toString();

        // Détecter les différentes erreurs
        if (errorMsg.contains('403') || errorMsg.contains('Cannot swipe own post')) {
          widget.onMessage(l10n.adoptOwnPost);
        } else if (errorMsg.contains('quota') || errorMsg.contains('Quota') ||
                   errorMsg.contains('limite') || errorMsg.contains('limit')) {
          if (isLike) {
            widget.onMessage(l10n.adoptQuotaReached);
          } else {
            widget.onMessage(l10n.adoptQuotaReachedToday);
          }
        } else if (errorMsg.contains('400')) {
          widget.onMessage(l10n.adoptInvalidRequest);
        } else if (errorMsg.contains('429')) {
          widget.onMessage(l10n.adoptTooManyRequests);
        } else if (errorMsg.contains('500') || errorMsg.contains('502') || errorMsg.contains('503')) {
          widget.onMessage(l10n.adoptServerUnavailable);
        } else {
          widget.onMessage('❌ ${l10n.adoptError}: ${errorMsg.length > 50 ? '${errorMsg.substring(0, 50)}...' : errorMsg}');
        }
      }
    }

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _isDragging = false;
        _isAnimating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    if (widget.currentIndex >= widget.posts.length) {
      return _EmptyState(onRefresh: widget.onSwipeComplete, isDark: isDark);
    }

    final post = widget.posts[widget.currentIndex];
    final screenSize = MediaQuery.of(context).size;

    final angle = (_dragX / screenSize.width) * 0.3;
    final opacity = 1 - (_dragX.abs() / screenSize.width * 0.5);

    return Column(
      children: [
        // Cards area
        Expanded(
          child: Stack(
            children: [
              // Next card (preview) - visible underneath
              if (widget.currentIndex + 1 < widget.posts.length)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Transform.scale(
                      scale: 0.95,
                      child: Transform.translate(
                        offset: const Offset(0, 8),
                        child: _PostCard(post: widget.posts[widget.currentIndex + 1], isPreview: true),
                      ),
                    ),
                  ),
                ),

              // Current card
              Positioned.fill(
                child: AnimatedContainer(
                  duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
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
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: _PostCard(post: post),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // NOPE indicator (left side)
              if (_isDragging && _dragX < -30)
                Positioned(
                  top: 60,
                  right: 40,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: _redNope, width: 4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'NOPE',
                        style: TextStyle(
                          color: _redNope,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),

              // LIKE indicator (right side)
              if (_isDragging && _dragX > 30)
                Positioned(
                  top: 60,
                  left: 40,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: _greenLike, width: 4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIKE',
                        style: TextStyle(
                          color: _greenLike,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.only(bottom: 24, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NOPE button
              _ActionButton(
                icon: Icons.close,
                color: _redNope,
                size: 64,
                iconSize: 32,
                onTap: _isAnimating ? null : () => _handleSwipe(false),
              ),
              const SizedBox(width: 32),
              // LIKE button
              _ActionButton(
                icon: Icons.favorite,
                color: _greenLike,
                size: 64,
                iconSize: 32,
                onTap: _isAnimating ? null : () => _handleSwipe(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Action button widget
class _ActionButton extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? _darkCard : Colors.white,
            border: Border.all(color: color.withOpacity(isDark ? 0.5 : 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.3 : 0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final bool isPreview;

  const _PostCard({required this.post, this.isPreview = false});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  int _currentImageIndex = 0;
  Offset? _pointerDownPosition;

  String _getSpeciesIcon(String species) {
    switch (species.toLowerCase()) {
      case 'dog':
        return '🐕';
      case 'cat':
        return '🐱';
      case 'rabbit':
        return '🐰';
      case 'bird':
        return '🐦';
      default:
        return '🐾';
    }
  }

  String _getSpeciesLabel(String species, AppLocalizations l10n) {
    switch (species.toLowerCase()) {
      case 'dog':
        return l10n.adoptDog;
      case 'cat':
        return l10n.adoptCat;
      case 'rabbit':
        return l10n.adoptRabbit;
      case 'bird':
        return l10n.adoptBird;
      case 'other':
        return l10n.adoptOther;
      default:
        return species;
    }
  }

  String _getSexLabel(String? sex, AppLocalizations l10n) {
    if (sex == null) return '';
    switch (sex.toUpperCase()) {
      case 'M':
      case 'MALE':
        return l10n.adoptMale;
      case 'F':
      case 'FEMALE':
        return l10n.adoptFemale;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final images = (widget.post['images'] as List<dynamic>?)
        ?.map((e) => (e as Map<String, dynamic>)['url']?.toString())
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList() ?? [];

    final animalName = (widget.post['animalName'] ?? widget.post['title'] ?? 'Animal').toString();
    final species = (widget.post['species'] ?? '').toString();
    final city = (widget.post['city'] ?? '').toString();
    final sex = widget.post['sex']?.toString();
    final ageMonths = widget.post['ageMonths'] as int?;
    final description = (widget.post['description'] ?? '').toString();
    final adoptedAt = widget.post['adoptedAt'];

    final ageText = ageMonths != null
        ? ageMonths < 12
            ? '$ageMonths ${l10n.adoptMonths}'
            : '${(ageMonths / 12).floor()} ${ageMonths >= 24 ? l10n.adoptYears : l10n.adoptYear}'
        : '';

    final sexLabel = _getSexLabel(sex, l10n);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: widget.isPreview
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image courante
            if (images.isNotEmpty)
              Image.network(
                images[_currentImageIndex.clamp(0, images.length - 1)],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _roseLight,
                  child: Center(
                    child: Icon(Icons.pets, size: 80, color: _rosePrimary.withOpacity(0.5)),
                  ),
                ),
              )
            else
              Container(
                color: _roseLight,
                child: Center(
                  child: Icon(Icons.pets, size: 80, color: _rosePrimary.withOpacity(0.5)),
                ),
              ),

            // Zones de tap gauche/droite pour naviguer entre images
            if (images.length > 1 && !widget.isPreview)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _pointerDownPosition = event.position;
                  },
                  onPointerUp: (event) {
                    if (_pointerDownPosition != null) {
                      final distance = (event.position - _pointerDownPosition!).distance;
                      if (distance < 20) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final tapX = event.position.dx;

                        if (tapX < screenWidth / 2) {
                          if (_currentImageIndex > 0) {
                            setState(() => _currentImageIndex--);
                          }
                        } else {
                          if (_currentImageIndex < images.length - 1) {
                            setState(() => _currentImageIndex++);
                          }
                        }
                      }
                    }
                    _pointerDownPosition = null;
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Progress bars for images (top)
            if (images.length > 1)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(images.length, (index) {
                    final isActive = index == _currentImageIndex;
                    final isPast = index < _currentImageIndex;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < images.length - 1 ? 4 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive || isPast
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // Gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Adopted badge (top right)
            if (adoptedAt != null)
              Positioned(
                top: images.length > 1 ? 28 : 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        l10n.adoptAdopted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Info overlay (bottom)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name and age
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              animalName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ageText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                ageText,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tags row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Species tag
                          if (species.isNotEmpty)
                            _InfoTag(
                              icon: _getSpeciesIcon(species),
                              label: _getSpeciesLabel(species, l10n),
                            ),
                          // Sex tag
                          if (sexLabel.isNotEmpty)
                            _InfoTag(
                              icon: sex?.toUpperCase() == 'M' || sex?.toLowerCase() == 'male' ? '♂️' : '♀️',
                              label: sexLabel,
                              color: sex?.toUpperCase() == 'M' || sex?.toLowerCase() == 'male'
                                  ? const Color(0xFF64B5F6)
                                  : const Color(0xFFFF8A80),
                            ),
                          // City tag
                          if (city.isNotEmpty)
                            _InfoTag(
                              icon: '📍',
                              label: city,
                            ),
                        ],
                      ),

                      // Description
                      if (description.isNotEmpty && !widget.isPreview) ...[
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Info tag widget for species, sex, city
class _InfoTag extends StatelessWidget {
  final String icon;
  final String label;
  final Color? color;

  const _InfoTag({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.2) ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color?.withOpacity(0.5) ?? Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
