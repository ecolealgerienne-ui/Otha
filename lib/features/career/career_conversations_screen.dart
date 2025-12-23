import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Colors
const _primaryPurple = Color(0xFF6B5BFF);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

final _careerConversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.careerMyConversations();
});

class CareerConversationsScreen extends ConsumerWidget {
  const CareerConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF8F8F8);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final conversationsAsync = ref.watch(_careerConversationsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: textPrimary),
        ),
        title: Text(
          l10n.careerConversations,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: conversationsAsync.when(
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
                onPressed: () => ref.invalidate(_careerConversationsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.careerNoConversations,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contactez des annonces pour commencer',
                    style: TextStyle(color: textSecondary),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_careerConversationsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationCard(
                  conversation: conv,
                  isDark: isDark,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => context.push('/career/chat/${conv['id']}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final bool isDark;
  final Color cardColor;
  final Color textPrimary;
  final Color? textSecondary;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.isDark,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final post = conversation['post'] as Map<String, dynamic>?;
    final otherUser = conversation['otherUser'] as Map<String, dynamic>?;
    final lastMessage = conversation['lastMessage']?.toString() ?? '';
    final postTitle = post?['title']?.toString() ?? 'Annonce';
    final postType = post?['type']?.toString();

    String userName = 'Utilisateur';
    String? photoUrl;

    if (otherUser != null) {
      final firstName = otherUser['firstName']?.toString() ?? '';
      final lastName = otherUser['lastName']?.toString() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        userName = '$firstName $lastName'.trim();
      } else if (otherUser['anonymousName'] != null) {
        userName = otherUser['anonymousName'].toString();
      }
      photoUrl = otherUser['photoUrl']?.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? _darkCardBorder : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _primaryPurple.withOpacity(0.1),
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Icon(Icons.person, color: _primaryPurple)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: postType == 'REQUEST'
                                ? _primaryPurple.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            postType == 'REQUEST' ? 'Demande' : 'Offre',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: postType == 'REQUEST' ? _primaryPurple : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      postTitle,
                      style: TextStyle(fontSize: 13, color: _primaryPurple, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage.isNotEmpty ? lastMessage : 'Aucun message',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
