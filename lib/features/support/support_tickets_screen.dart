import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

const _coral = Color(0xFFF2968F);

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final tickets = await api.getSupportTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
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

  void _showNewTicketDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String selectedCategory = 'GENERAL';
    bool isSending = false;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final inputFillColor = isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade100;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final categories = [
            {'value': 'GENERAL', 'label': l10n.supportCategoryGeneral, 'icon': Icons.help_outline, 'color': Colors.blue},
            {'value': 'APPEAL', 'label': l10n.supportCategoryAppeal, 'icon': Icons.gavel, 'color': Colors.red},
            {'value': 'BUG', 'label': l10n.supportCategoryBug, 'icon': Icons.bug_report, 'color': Colors.orange},
            {'value': 'FEATURE', 'label': l10n.supportCategoryFeature, 'icon': Icons.lightbulb, 'color': Colors.purple},
            {'value': 'BILLING', 'label': l10n.supportCategoryBilling, 'icon': Icons.receipt_long, 'color': Colors.green},
            {'value': 'OTHER', 'label': l10n.supportCategoryOther, 'icon': Icons.more_horiz, 'color': Colors.grey},
          ];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.9,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_coral, _coral.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.supportNewTicket,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor),
                            ),
                            Text(
                              l10n.supportTeamResponds24h,
                              style: TextStyle(fontSize: 13, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: subtitleColor),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category selection
                        Text(
                          l10n.supportRequestType,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: categories.map((cat) {
                            final isSelected = selectedCategory == cat['value'];
                            final color = cat['color'] as Color;
                            return GestureDetector(
                              onTap: () => setSheetState(() => selectedCategory = cat['value'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withOpacity(0.15) : inputFillColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? color : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cat['icon'] as IconData,
                                      size: 18,
                                      color: isSelected ? color : subtitleColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cat['label'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? color : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 28),

                        // Subject field
                        Text(
                          l10n.supportSubject,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: subjectController,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: l10n.supportSubjectHint,
                            hintStyle: TextStyle(color: subtitleColor.withOpacity(0.7)),
                            filled: true,
                            fillColor: inputFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _coral, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Message field
                        Text(
                          l10n.supportDescribeProblem,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: messageController,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: l10n.supportDescribeHint,
                            hintStyle: TextStyle(color: subtitleColor.withOpacity(0.7)),
                            filled: true,
                            fillColor: inputFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _coral, width: 2),
                            ),
                            contentPadding: const EdgeInsets.all(18),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Info box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.supportNotificationInfo,
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Submit button
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(ctx).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              if (subjectController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.supportEnterSubject),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (messageController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.supportEnterDescription),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSending = true);
                              Navigator.pop(ctx);
                              await _createTicket(
                                subjectController.text.trim(),
                                messageController.text.trim(),
                                selectedCategory,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.supportSendTicket,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createTicket(String subject, String message, String category) async {
    try {
      final api = ref.read(apiProvider);
      final ticket = await api.createSupportTicket(
        subject: subject,
        message: message,
        category: category,
      );

      if (mounted) {
        // Ouvrir la conversation directement
        context.push('/support/${ticket['id']}');
        _loadTickets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
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

  String _getStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'OPEN':
        return l10n.supportStatusOpen;
      case 'IN_PROGRESS':
        return l10n.supportStatusInProgress;
      case 'WAITING_USER':
        return l10n.supportStatusWaitingUser;
      case 'RESOLVED':
        return l10n.supportStatusResolved;
      case 'CLOSED':
        return l10n.supportStatusClosed;
      default:
        return status;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'APPEAL':
        return Icons.gavel;
      case 'BUG':
        return Icons.bug_report;
      case 'FEATURE':
        return Icons.lightbulb;
      case 'BILLING':
        return Icons.receipt;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50;
    final cardColor = isDark ? theme.cardColor : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.supportTitle,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
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
                      Text(l10n.error, style: TextStyle(color: subtitleColor)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _loadTickets, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.support_agent, size: 64, color: subtitleColor.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            l10n.supportNoTickets,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.supportNoTicketsDesc,
                            style: TextStyle(color: subtitleColor.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTickets,
                      color: _coral,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        itemBuilder: (ctx, i) {
                          final ticket = _tickets[i];
                          final status = ticket['status']?.toString() ?? 'OPEN';
                          final category = ticket['category']?.toString() ?? 'GENERAL';
                          final lastMessage = ticket['lastMessage'] as Map<String, dynamic>?;
                          final hasUnread = lastMessage?['isFromAdmin'] == true;

                          return GestureDetector(
                            onTap: () => context.push('/support/${ticket['id']}'),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: hasUnread
                                    ? Border.all(color: _coral, width: 2)
                                    : null,
                                boxShadow: isDark ? null : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: _getStatusColor(status),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ticket['subject']?.toString() ?? 'Sans titre',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: textColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (hasUnread)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _coral,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  l10n.supportStatusOpen,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (lastMessage != null)
                                          Text(
                                            lastMessage['content']?.toString() ?? '',
                                            style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getStatusLabel(status, l10n),
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: subtitleColor),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewTicketDialog,
        backgroundColor: _coral,
        icon: const Icon(Icons.add),
        label: Text(l10n.supportNewTicket),
      ),
    );
  }
}
