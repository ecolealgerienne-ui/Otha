import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Colors
const _primaryPurple = Color(0xFF6B5BFF);
const _purpleLight = Color(0xFFEDE9FF);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

// Refresh key to force reload
final _careerRefreshKey = StateProvider<int>((ref) => 0);

// Providers
final _careerFeedProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, type) async {
  ref.watch(_careerRefreshKey); // Depend on refresh key
  final api = ref.watch(apiProvider);
  return api.careerFeed(type: type);
});

final _myCareerPostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(_careerRefreshKey); // Depend on refresh key
  final api = ref.watch(apiProvider);
  return api.careerMyPosts();
});

class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key});

  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  String _searchCity = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    // Refresh on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    ref.read(_careerRefreshKey.notifier).state++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF8F8F8);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final currentType = _tabController.index == 0 ? 'REQUEST' : 'OFFER';
    final feedAsync = ref.watch(_careerFeedProvider(currentType));
    final myPostsAsync = ref.watch(_myCareerPostsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          _buildHeader(context, l10n, isDark, cardColor, textPrimary, textSecondary),

          // Tabs
          Container(
            color: cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: _primaryPurple,
              unselectedLabelColor: textSecondary,
              indicatorColor: _primaryPurple,
              indicatorWeight: 3,
              tabs: [
                Tab(text: l10n.careerRequests),
                Tab(text: l10n.careerOffers),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _searchCity = v),
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: l10n.careerSearchCity,
                hintStyle: TextStyle(color: textSecondary),
                prefixIcon: Icon(Icons.search, color: textSecondary),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryPurple),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeedList(feedAsync, l10n, isDark, cardColor, textPrimary, textSecondary),
                _buildFeedList(feedAsync, l10n, isDark, cardColor, textPrimary, textSecondary),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/career/create');
          _refreshData();
        },
        backgroundColor: _primaryPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          myPostsAsync.maybeWhen(
            data: (posts) => posts.isNotEmpty ? l10n.careerMyPost : l10n.careerCreatePost,
            orElse: () => l10n.careerCreatePost,
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 8, left: 12, right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : _primaryPurple),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? _primaryPurple.withOpacity(0.2) : _purpleLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primaryPurple, Color(0xFF8B7FFF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.work_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.careerTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  l10n.careerSubtitle,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await context.push('/career/conversations');
              _refreshData();
            },
            icon: Icon(Icons.chat_bubble_outline, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(
    AsyncValue<Map<String, dynamic>> feedAsync,
    AppLocalizations l10n,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color? textSecondary,
  ) {
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _primaryPurple)),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: textSecondary),
            const SizedBox(height: 12),
            Text('Erreur: $e', style: TextStyle(color: textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _refreshData(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (result) {
        final posts = (result['data'] as List<dynamic>?) ?? [];

        // Filter by city if search is active
        final filteredPosts = _searchCity.isEmpty
            ? posts
            : posts.where((p) {
                final city = (p['city'] ?? '').toString().toLowerCase();
                return city.contains(_searchCity.toLowerCase());
              }).toList();

        if (filteredPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: textSecondary),
                const SizedBox(height: 16),
                Text(
                  l10n.careerNoResults,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textPrimary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _refreshData();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              final post = filteredPosts[index] as Map<String, dynamic>;
              return _CareerCard(
                post: post,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                l10n: l10n,
                onTap: () async {
                  await context.push('/career/${post['id']}');
                  _refreshData();
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CareerCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  final Color cardColor;
  final Color textPrimary;
  final Color? textSecondary;
  final AppLocalizations l10n;
  final Future<void> Function() onTap;

  const _CareerCard({
    required this.post,
    required this.isDark,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = post['title']?.toString() ?? '';
    final publicBio = post['publicBio']?.toString() ?? '';
    final city = post['city']?.toString();
    final domain = post['domain']?.toString();
    final duration = post['duration']?.toString();
    final type = post['type']?.toString();
    final isOwn = post['isOwn'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with type badge and own indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: type == 'REQUEST'
                          ? _primaryPurple.withOpacity(isDark ? 0.3 : 0.1)
                          : Colors.green.withOpacity(isDark ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type == 'REQUEST' ? l10n.careerTypeRequest : l10n.careerTypeOffer,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: type == 'REQUEST' ? _primaryPurple : Colors.green,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isOwn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.careerMyPost,
                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Bio preview
              Text(
                publicBio,
                style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Tags row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (city != null && city.isNotEmpty)
                    _buildTag(Icons.location_on_outlined, city, isDark),
                  if (domain != null && domain.isNotEmpty)
                    _buildTag(Icons.work_outline, domain, isDark),
                  if (duration != null && duration.isNotEmpty)
                    _buildTag(Icons.schedule, duration, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? _darkCardBorder : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}
