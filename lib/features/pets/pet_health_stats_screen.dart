// lib/features/pets/pet_health_stats_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';
import 'add_weight_dialog.dart';
import 'add_health_data_dialog.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _mint = Color(0xFF4ECDC4);
const _purple = Color(0xFF9B59B6);
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);

// Provider pour les statistiques de santé (par petId)
final healthStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  return api.getHealthStats(petId);
});

// Provider pour les stats via token (accès vétérinaire) - utilise les données du pet
final healthStatsByTokenProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, token) async {
  final api = ref.read(apiProvider);
  final petData = await api.getPetByToken(token);

  // Construire les stats à partir des données brutes du pet
  final weightRecords = (petData['weightRecords'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final medicalRecords = (petData['medicalRecords'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  // Extraire température et rythme cardiaque des medical records
  final tempData = medicalRecords
      .where((r) => r['temperatureC'] != null)
      .map((r) => {'date': r['date'], 'temperatureC': r['temperatureC']})
      .toList();
  final heartData = medicalRecords
      .where((r) => r['heartRate'] != null)
      .map((r) => {'date': r['date'], 'heartRate': r['heartRate']})
      .toList();

  // Build weight stats
  Map<String, dynamic>? weightStats;
  if (weightRecords.isNotEmpty) {
    final weights = weightRecords.map((w) => double.tryParse(w['weightKg'].toString()) ?? 0.0).toList();
    weightStats = {
      'current': weightRecords.first['weightKg'],
      'min': weights.reduce((a, b) => a < b ? a : b),
      'max': weights.reduce((a, b) => a > b ? a : b),
      'data': weightRecords,
    };
  }

  // Build temperature stats
  Map<String, dynamic>? tempStats;
  if (tempData.isNotEmpty) {
    final temps = tempData.map((t) => double.tryParse(t['temperatureC'].toString()) ?? 0.0).toList();
    tempStats = {
      'current': tempData.first['temperatureC'],
      'average': temps.reduce((a, b) => a + b) / temps.length,
      'data': tempData,
    };
  }

  // Build heart rate stats
  Map<String, dynamic>? heartStats;
  if (heartData.isNotEmpty) {
    final rates = heartData.map((h) => (h['heartRate'] as num).toDouble()).toList();
    heartStats = {
      'current': heartData.first['heartRate'],
      'average': (rates.reduce((a, b) => a + b) / rates.length).round(),
      'data': heartData,
    };
  }

  return {
    'weight': weightStats,
    'temperature': tempStats,
    'heartRate': heartStats,
  };
});

class PetHealthStatsScreen extends ConsumerWidget {
  final String petId;
  final String? token; // Token optionnel pour accès vétérinaire

  const PetHealthStatsScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    // Utiliser le provider approprié selon le mode d'accès
    final statsAsync = isVetAccess
        ? ref.watch(healthStatsByTokenProvider(token!))
        : ref.watch(healthStatsProvider(petId));

    final bgColor = isDark ? _darkBg : const Color(0xFFF8F9FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2D2D2D);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? _darkBg : _coralSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _coral),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.healthStats,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'SFPRO',
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(error.toString(), ref, isDark, l10n, textPrimary),
        data: (stats) => _buildStats(context, ref, stats, isDark, l10n, textPrimary, cardColor),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDataMenu(context, ref, isDark, l10n, textPrimary),
        backgroundColor: _coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDataMenu(BuildContext context, WidgetRef ref, bool isDark, AppLocalizations l10n, Color textPrimary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addData,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'SFPRO',
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showAddWeightDialog(context, ref, petId).then((_) {
                  ref.invalidate(healthStatsProvider(petId));
                });
              },
              icon: const Icon(Icons.monitor_weight),
              label: Text(l10n.addWeight),
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showAddHealthDataDialog(context, ref, petId).then((_) {
                  ref.invalidate(healthStatsProvider(petId));
                });
              },
              icon: const Icon(Icons.favorite),
              label: Text(l10n.addTempHeart),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    ).then((_) {
      // Refresh après fermeture du bottom sheet
      if (isVetAccess) {
        ref.invalidate(healthStatsByTokenProvider(token!));
      } else {
        ref.invalidate(healthStatsProvider(petId));
      }
    });
  }

  Widget _buildError(String error, WidgetRef ref, bool isDark, AppLocalizations l10n, Color textPrimary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 56, color: Colors.red),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.error,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'SFPRO',
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(healthStatsByTokenProvider(token!));
              } else {
                ref.invalidate(healthStatsProvider(petId));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _coral),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color cardColor,
  ) {
    final weightData = stats['weight'] as Map<String, dynamic>?;
    final tempData = stats['temperature'] as Map<String, dynamic>?;
    final heartData = stats['heartRate'] as Map<String, dynamic>?;

    final hasWeightData = (weightData?['data'] as List?)?.isNotEmpty ?? false;
    final hasTempData = (tempData?['data'] as List?)?.isNotEmpty ?? false;
    final hasHeartData = (heartData?['data'] as List?)?.isNotEmpty ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(weightData, tempData, heartData, isDark, l10n, textPrimary, cardColor),
          const SizedBox(height: 32),

          // Weight Chart
          if (hasWeightData) ...[
            _buildSectionHeader(l10n.weightEvolution, Icons.monitor_weight, _coral, textPrimary),
            const SizedBox(height: 16),
            _buildWeightChart(weightData!, isDark, cardColor, textPrimary),
            const SizedBox(height: 32),
          ],

          // Temperature Chart
          if (hasTempData) ...[
            _buildSectionHeader(l10n.temperatureHistory, Icons.thermostat, _mint, textPrimary),
            const SizedBox(height: 16),
            _buildTemperatureChart(tempData!, isDark, cardColor, textPrimary),
            const SizedBox(height: 32),
          ],

          // Heart Rate Chart
          if (hasHeartData) ...[
            _buildSectionHeader(l10n.heartRate, Icons.favorite, _purple, textPrimary),
            const SizedBox(height: 16),
            _buildHeartRateChart(heartData!, isDark, cardColor, textPrimary),
          ],

          // Empty state
          if (!hasWeightData && !hasTempData && !hasHeartData) _buildEmptyState(isDark, l10n, textPrimary),
        ],
      ),
    );
  }

  // Helper pour convertir une valeur en double de façon sécurisée
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildSummaryCards(
    Map<String, dynamic>? weight,
    Map<String, dynamic>? temp,
    Map<String, dynamic>? heart,
    bool isDark,
    AppLocalizations l10n,
    Color textPrimary,
    Color cardColor,
  ) {
    final currentWeight = _toDouble(weight?['current']);
    final minWeight = _toDouble(weight?['min']);
    final maxWeight = _toDouble(weight?['max']);
    final currentTemp = _toDouble(temp?['current']);
    final avgTemp = _toDouble(temp?['average']);

    return Row(
      children: [
        if (currentWeight != null)
          Expanded(
            child: _buildStatCard(
              icon: Icons.monitor_weight,
              label: l10n.currentWeight,
              value: '${currentWeight.toStringAsFixed(1)} kg',
              color: _coral,
              subtitle: minWeight != null && maxWeight != null
                  ? 'Min: ${minWeight.toStringAsFixed(1)} / Max: ${maxWeight.toStringAsFixed(1)}'
                  : null,
              isDark: isDark,
              textPrimary: textPrimary,
              cardColor: cardColor,
            ),
          ),
        if (currentWeight != null && currentTemp != null) const SizedBox(width: 12),
        if (currentTemp != null)
          Expanded(
            child: _buildStatCard(
              icon: Icons.thermostat,
              label: l10n.temperature,
              value: '${currentTemp.toStringAsFixed(1)}°C',
              color: _mint,
              subtitle: avgTemp != null ? '${l10n.average}: ${avgTemp.toStringAsFixed(1)}°C' : null,
              isDark: isDark,
              textPrimary: textPrimary,
              cardColor: cardColor,
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
    required bool isDark,
    required Color textPrimary,
    required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'SFPRO',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'SFPRO',
              color: textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'SFPRO',
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'SFPRO',
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeightChart(Map<String, dynamic> weightData, bool isDark, Color cardColor, Color textPrimary) {
    final dataList = (weightData['data'] as List).cast<Map<String, dynamic>>();
    if (dataList.isEmpty) return const SizedBox.shrink();

    final spots = dataList.asMap().entries.map((entry) {
      final data = entry.value;
      final weight = _toDouble(data['weightKg']) ?? 0.0;
      return FlSpot(entry.key.toDouble(), weight);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;
    final gridColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final labelColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _coral,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _coral.withOpacity(0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(1)} kg',
                          style: TextStyle(fontSize: 10, color: labelColor),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dataList.length) return const SizedBox.shrink();
                        final dateStr = dataList[index]['date'] as String;
                        final date = DateTime.parse(dateStr);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('dd/MM').format(date),
                            style: TextStyle(fontSize: 10, color: labelColor),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(dataList, 'weightKg', 'kg', isDark, textPrimary),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart(Map<String, dynamic> tempData, bool isDark, Color cardColor, Color textPrimary) {
    final dataList = (tempData['data'] as List).cast<Map<String, dynamic>>();
    if (dataList.isEmpty) return const SizedBox.shrink();

    final spots = dataList.asMap().entries.map((entry) {
      final data = entry.value;
      final temp = _toDouble(data['temperatureC']) ?? 0.0;
      return FlSpot(entry.key.toDouble(), temp);
    }).toList();

    const minY = 36.0;
    const maxY = 40.0;
    final gridColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final labelColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _mint,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _mint.withOpacity(0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(1)}°C',
                          style: TextStyle(fontSize: 10, color: labelColor),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dataList.length) return const SizedBox.shrink();
                        final dateStr = dataList[index]['date'] as String;
                        final date = DateTime.parse(dateStr);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('dd/MM').format(date),
                            style: TextStyle(fontSize: 10, color: labelColor),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(dataList, 'temperatureC', '°C', isDark, textPrimary),
        ],
      ),
    );
  }

  Widget _buildHeartRateChart(Map<String, dynamic> heartData, bool isDark, Color cardColor, Color textPrimary) {
    final dataList = (heartData['data'] as List).cast<Map<String, dynamic>>();
    if (dataList.isEmpty) return const SizedBox.shrink();

    final spots = dataList.asMap().entries.map((entry) {
      final data = entry.value;
      final hr = _toDouble(data['heartRate']) ?? 0.0;
      return FlSpot(entry.key.toDouble(), hr);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;
    final gridColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final labelColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _purple,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _purple.withOpacity(0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()} bpm',
                          style: TextStyle(fontSize: 10, color: labelColor),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dataList.length) return const SizedBox.shrink();
                        final dateStr = dataList[index]['date'] as String;
                        final date = DateTime.parse(dateStr);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('dd/MM').format(date),
                            style: TextStyle(fontSize: 10, color: labelColor),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(dataList, 'heartRate', 'bpm', isDark, textPrimary),
        ],
      ),
    );
  }

  Widget _buildChartLegend(
    List<Map<String, dynamic>> data,
    String valueKey,
    String unit,
    bool isDark,
    Color textPrimary,
  ) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = data[index];
          final dateStr = item['date'] as String;
          final date = DateTime.parse(dateStr);
          final value = item[valueKey];
          final ctx = item['context'] as String?;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SFPRO',
                    color: _coral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_toDouble(value)?.toStringAsFixed(1) ?? value} $unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SFPRO',
                    color: textPrimary,
                  ),
                ),
                if (ctx != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    ctx,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'SFPRO',
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n, Color textPrimary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noHealthData,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'SFPRO',
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.healthDataWillAppear,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'SFPRO',
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
