// lib/features/daycare/daycare_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Clean color palette
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);

// Dark mode
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

// Commission
const kDaycareCommissionDa = 100;

/// Provider pour charger les animaux de l'utilisateur
final _userPetsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final pets = await api.myPets();
    return pets.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    return [];
  }
});

class DaycareBookingScreen extends ConsumerStatefulWidget {
  final String providerId;
  final Map<String, dynamic>? daycareData;

  const DaycareBookingScreen({
    super.key,
    required this.providerId,
    this.daycareData,
  });

  @override
  ConsumerState<DaycareBookingScreen> createState() => _DaycareBookingScreenState();
}

class _DaycareBookingScreenState extends ConsumerState<DaycareBookingScreen> {
  final _notesController = TextEditingController();

  // Selected pet
  String? _selectedPetId;

  // Dates
  DateTime? _startDate;
  DateTime? _endDate;

  // Time (hour values 0-23)
  int _startHour = 9;
  int _startMinute = 0;
  int _endHour = 17;
  int _endMinute = 0;

  // Booking type
  String _bookingType = 'hourly';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final daycare = widget.daycareData ?? {};

    final name = (daycare['displayName'] ?? l10n.daycare).toString();
    final hourlyRate = daycare['hourlyRate'] as int?;
    final dailyRate = daycare['dailyRate'] as int?;
    final availableDays = daycare['availableDays'] as List<dynamic>? ?? List.filled(7, true);

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor = isDark ? _darkCardBorder : const Color(0xFFE8E8E8);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    final petsAsync = ref.watch(_userPetsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _coralSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today_rounded, color: _coral, size: 18),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.bookDaycare,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (err, _) => _buildError(err.toString(), isDark, l10n),
        data: (pets) {
          if (pets.isEmpty) {
            return _buildNoPets(context, isDark, l10n);
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Daycare name
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.pets_rounded, color: _coral, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (hourlyRate != null || dailyRate != null)
                                    Text(
                                      hourlyRate != null
                                          ? '${hourlyRate + kDaycareCommissionDa} DA${l10n.perHour}'
                                          : '${dailyRate! + kDaycareCommissionDa} DA${l10n.perDay}',
                                      style: TextStyle(fontSize: 13, color: _coral),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Booking type
                      if (hourlyRate != null && dailyRate != null) ...[
                        _buildSectionTitle(l10n.bookingType, Icons.schedule_rounded, textPrimary),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _TypeButton(
                                label: l10n.hourlyRate,
                                icon: Icons.access_time_rounded,
                                selected: _bookingType == 'hourly',
                                onTap: () => setState(() => _bookingType = 'hourly'),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TypeButton(
                                label: l10n.dailyRate,
                                icon: Icons.calendar_month_rounded,
                                selected: _bookingType == 'daily',
                                onTap: () => setState(() => _bookingType = 'daily'),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Pet selection
                      _buildSectionTitle(l10n.selectAnimal, Icons.pets_rounded, textPrimary),
                      const SizedBox(height: 10),
                      _buildPetSelector(pets, cardColor, borderColor, textPrimary, textSecondary, isDark),

                      const SizedBox(height: 24),

                      // Date selection
                      _buildSectionTitle(
                        _bookingType == 'daily' ? l10n.selectDates : l10n.selectDate,
                        Icons.calendar_today_rounded,
                        textPrimary,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DateCard(
                              label: _bookingType == 'daily' ? l10n.arrival : l10n.selectDate,
                              date: _startDate,
                              onTap: () => _pickDate(context, isStart: true, availableDays: availableDays),
                              isDark: isDark,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                          if (_bookingType == 'daily') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateCard(
                                label: l10n.departure,
                                date: _endDate,
                                onTap: () => _pickDate(context, isStart: false, availableDays: availableDays),
                                isDark: isDark,
                                cardColor: cardColor,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Time selection (hourly only)
                      if (_bookingType == 'hourly') ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(l10n.selectTime, Icons.access_time_rounded, textPrimary),
                        const SizedBox(height: 10),
                        _buildTimePickers(cardColor, borderColor, textPrimary, textSecondary, isDark, l10n),
                      ],

                      const SizedBox(height: 24),

                      // Notes
                      _buildSectionTitle(l10n.notesOptional, Icons.note_outlined, textPrimary),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: l10n.notesHint,
                            hintStyle: TextStyle(color: textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Total
                      _buildTotalCard(hourlyRate, dailyRate, cardColor, borderColor, textPrimary, textSecondary, l10n),
                    ],
                  ),
                ),
              ),

              // Bottom button
              _buildBottomBar(textPrimary, cardColor, borderColor, l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _coral),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPetSelector(
    List<Map<String, dynamic>> pets,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: pets.map((pet) {
        final id = (pet['id'] ?? '').toString();
        final name = (pet['name'] ?? 'Sans nom').toString();
        final photoUrl = (pet['photoUrl'] ?? '').toString();
        final isSelected = _selectedPetId == id;

        return GestureDetector(
          onTap: () => setState(() => _selectedPetId = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? (isDark ? _coral.withOpacity(0.15) : _coralSoft) : cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _coral : borderColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoUrl.isNotEmpty)
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(photoUrl),
                  )
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? _darkCardBorder : Colors.grey[200],
                    child: Icon(Icons.pets, size: 18, color: isSelected ? _coral : textSecondary),
                  ),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? _coral : textPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded, size: 18, color: _coral),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePickers(
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Start time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.login_rounded, size: 18, color: _coral),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.arrival,
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const Spacer(),
              _TimeSelector(
                hour: _startHour,
                minute: _startMinute,
                onHourChanged: (h) => setState(() => _startHour = h),
                onMinuteChanged: (m) => setState(() => _startMinute = m),
                isDark: isDark,
                textPrimary: textPrimary,
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: borderColor),
          ),

          // End time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout_rounded, size: 18, color: _coral),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.departure,
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const Spacer(),
              _TimeSelector(
                hour: _endHour,
                minute: _endMinute,
                onHourChanged: (h) => setState(() => _endHour = h),
                onMinuteChanged: (m) => setState(() => _endMinute = m),
                isDark: isDark,
                textPrimary: textPrimary,
              ),
            ],
          ),

          // Duration indicator
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? _coral.withOpacity(0.1) : _coralSoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timelapse_rounded, size: 16, color: _coral),
                const SizedBox(width: 6),
                Text(
                  _getDurationText(l10n),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _coral,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDurationText(AppLocalizations l10n) {
    final startMinutes = _startHour * 60 + _startMinute;
    final endMinutes = _endHour * 60 + _endMinute;
    final duration = endMinutes - startMinutes;

    if (duration <= 0) return l10n.invalidDuration;

    final hours = duration ~/ 60;
    final mins = duration % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}min';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}min';
    }
  }

  Widget _buildTotalCard(
    int? hourlyRate,
    int? dailyRate,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    AppLocalizations l10n,
  ) {
    final total = _calculateTotal(hourlyRate, dailyRate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _coralSoft.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _coral.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.totalLabel,
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              if (_selectedPetId != null)
                Text(
                  _bookingType == 'hourly' ? _getDurationText(l10n) : _getDaysText(l10n),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
            ],
          ),
          Text(
            total != null ? '$total DA' : '---',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: total != null ? _coral : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getDaysText(AppLocalizations l10n) {
    if (_startDate == null || _endDate == null) return '';
    final days = _endDate!.difference(_startDate!).inDays + 1;
    return '$days ${days > 1 ? l10n.days : l10n.day}';
  }

  int? _calculateTotal(int? hourlyRate, int? dailyRate) {
    if (_selectedPetId == null) return null;

    if (_bookingType == 'hourly' && hourlyRate != null && _startDate != null) {
      final startMinutes = _startHour * 60 + _startMinute;
      final endMinutes = _endHour * 60 + _endMinute;
      final durationMinutes = endMinutes - startMinutes;

      if (durationMinutes <= 0) return null;

      final hours = (durationMinutes / 60).ceil();
      return (hourlyRate * hours) + kDaycareCommissionDa;
    } else if (_bookingType == 'daily' && dailyRate != null && _startDate != null && _endDate != null) {
      final days = _endDate!.difference(_startDate!).inDays + 1;
      if (days <= 0) return null;
      return (dailyRate * days) + kDaycareCommissionDa;
    }

    return null;
  }

  Widget _buildBottomBar(Color textPrimary, Color cardColor, Color borderColor, AppLocalizations l10n) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitBooking,
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              disabledBackgroundColor: _coral.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    l10n.confirmBooking,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoPets(BuildContext context, bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? _darkCardBorder : _coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets_rounded, size: 48, color: _coral),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noPetsRegistered,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registerPetFirst,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/pets/add'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addAnimal),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error, bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: _coral),
            ),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart, required List<dynamic> availableDays}) async {
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: isStart ? now : (_startDate ?? now),
      lastDate: DateTime(now.year + 1),
      selectableDayPredicate: (DateTime date) {
        final weekday = date.weekday == 7 ? 0 : date.weekday;
        final adjustedWeekday = weekday == 0 ? 6 : weekday - 1;
        if (adjustedWeekday >= availableDays.length) return true;
        return availableDays[adjustedWeekday] == true;
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: _coral, surface: _darkCard)
                : const ColorScheme.light(primary: _coral),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitBooking() async {
    final l10n = AppLocalizations.of(context);

    if (_selectedPetId == null) {
      _showSnackBar(l10n.pleaseSelectAnimal);
      return;
    }

    if (_startDate == null) {
      _showSnackBar(l10n.pleaseSelectDate);
      return;
    }

    if (_bookingType == 'daily' && _endDate == null) {
      _showSnackBar(l10n.pleaseSelectEndDate);
      return;
    }

    if (_bookingType == 'hourly') {
      final startMinutes = _startHour * 60 + _startMinute;
      final endMinutes = _endHour * 60 + _endMinute;
      if (endMinutes <= startMinutes) {
        _showSnackBar(l10n.invalidDuration);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiProvider);
      final daycare = widget.daycareData ?? {};
      final hourlyRate = daycare['hourlyRate'] as int?;
      final dailyRate = daycare['dailyRate'] as int?;

      // Get pet info
      final petsAsync = ref.read(_userPetsProvider);
      final pets = petsAsync.value ?? [];
      final pet = pets.firstWhere((p) => p['id'] == _selectedPetId, orElse: () => {});
      final petName = (pet['name'] ?? l10n.yourAnimal).toString();

      // Prepare dates
      DateTime startDateTime;
      DateTime endDateTime;

      if (_bookingType == 'hourly') {
        startDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startHour,
          _startMinute,
        );
        endDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _endHour,
          _endMinute,
        );
      } else {
        startDateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 9, 0);
        endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 17, 0);
      }

      // Calculate price
      int basePrice;
      if (_bookingType == 'hourly' && hourlyRate != null) {
        final durationInHours = endDateTime.difference(startDateTime).inMinutes / 60;
        basePrice = (durationInHours.ceil() * hourlyRate);
      } else if (_bookingType == 'daily' && dailyRate != null) {
        final durationInDays = endDateTime.difference(startDateTime).inDays + 1;
        basePrice = (durationInDays * dailyRate);
      } else {
        basePrice = _bookingType == 'hourly' ? 1000 : 5000;
      }

      final totalDa = basePrice + kDaycareCommissionDa;

      final booking = await api.createDaycareBooking(
        petId: _selectedPetId!,
        providerId: widget.providerId,
        startDate: startDateTime.toIso8601String(),
        endDate: endDateTime.toIso8601String(),
        priceDa: basePrice,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (!mounted) return;

      context.go('/daycare/booking-confirmation', extra: {
        'bookingId': booking['id'],
        'totalDa': totalDa,
        'petName': petName,
        'startDate': startDateTime.toIso8601String(),
        'endDate': endDateTime.toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;

      final errorMsg = e.toString();
      if (errorMsg.contains('403') ||
          errorMsg.contains('nouveau client') ||
          errorMsg.contains('honorer') ||
          errorMsg.contains('restreint') ||
          errorMsg.contains('Forbidden')) {
        _showTrustRestrictionDialog(context);
      } else {
        _showSnackBar('Erreur: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showTrustRestrictionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: _coralSoft, shape: BoxShape.circle),
          child: const Icon(Icons.schedule, color: _coral, size: 32),
        ),
        title: Text(l10n.oneStepAtATime, textAlign: TextAlign.center),
        content: Text(
          l10n.trustRestrictionMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.understood),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ───────────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _coral : (isDark ? _darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _coral : (isDark ? _darkCardBorder : const Color(0xFFE8E8E8)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _DateCard({
    required this.label,
    required this.date,
    required this.onTap,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? _coral : borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: date != null ? _coral : textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  date != null ? DateFormat('dd/MM/yyyy').format(date!) : '---',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: date != null ? textPrimary : textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final bool isDark;
  final Color textPrimary;

  const _TimeSelector({
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.isDark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hour
        _TimeUnit(
          value: hour,
          maxValue: 23,
          onChanged: onHourChanged,
          isDark: isDark,
          textPrimary: textPrimary,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
        // Minute
        _TimeUnit(
          value: minute,
          maxValue: 59,
          step: 15,
          onChanged: onMinuteChanged,
          isDark: isDark,
          textPrimary: textPrimary,
        ),
      ],
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final int value;
  final int maxValue;
  final int step;
  final ValueChanged<int> onChanged;
  final bool isDark;
  final Color textPrimary;

  const _TimeUnit({
    required this.value,
    required this.maxValue,
    this.step = 1,
    required this.onChanged,
    required this.isDark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _darkCardBorder : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          GestureDetector(
            onTap: () {
              int newValue = value + step;
              if (newValue > maxValue) newValue = 0;
              onChanged(newValue);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: _coral,
              ),
            ),
          ),
          // Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          // Down button
          GestureDetector(
            onTap: () {
              int newValue = value - step;
              if (newValue < 0) newValue = maxValue - (maxValue % step);
              onChanged(newValue);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _coral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
