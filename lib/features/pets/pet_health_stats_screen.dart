// lib/features/pets/pet_health_stats_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'add_weight_dialog.dart';
import 'add_health_data_dialog.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);
const _mint = Color(0xFF4ECDC4);
const _purple = Color(0xFF9B59B6);

// Provider pour les statistiques de santé (par petId)
final healthStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, petId) async {
  final api = ref.read(apiProvider);
  return api.getHealthStats(petId);
});

// Provider pour les stats via token (accès vétérinaire) - utilise les données du pet
final healthStatsByTokenProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, token) async {
  final api = ref.read(apiProvider);
  final petData = await api.getPetByToken(token);
  // Extraire les données de santé du pet (si disponibles via getPetByToken)
  // On essaie d'abord de charger les stats via petId
  final petId = petData['id']?.toString();
  if (petId != null) {
    try {
      return await api.getHealthStats(petId);
    } catch (_) {
      // Fallback: construire les stats à partir des données brutes
    }
  }
  // Construire les stats à partir des données brutes du pet
  final weightRecords = (petData['weightRecords'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  return {
    'weight': weightRecords.isNotEmpty ? {
      'current': weightRecords.first['weightKg'],
      'data': weightRecords,
    } : null,
    'temperature': null,
    'heartRate': null,
  };
});

class PetHealthStatsScreen extends ConsumerWidget {
  final String petId;
  final String? token; // Token optionnel pour accès vétérinaire

  const PetHealthStatsScreen({super.key, required this.petId, this.token});

  bool get isVetAccess => token != null && token!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Utiliser le provider approprié selon le mode d'accès
    final statsAsync = isVetAccess
        ? ref.watch(healthStatsByTokenProvider(token!))
        : ref.watch(healthStatsProvider(petId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Statistiques de santé',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
        error: (error, stack) => _buildError(error.toString(), ref),
        data: (stats) => _buildStats(context, ref, stats),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDataMenu(context, ref),
        backgroundColor: _coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDataMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ajouter des données',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
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
              label: const Text('Ajouter un poids'),
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
              label: const Text('Ajouter température / rythme'),
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

  Widget _buildError(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Erreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (isVetAccess) {
                ref.invalidate(healthStatsByTokenProvider(token!));
              } else {
                ref.invalidate(healthStatsProvider(petId));
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, WidgetRef ref, Map<String, dynamic> stats) {
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
          _buildSummaryCards(weightData, tempData, heartData),
          const SizedBox(height: 32),

          // Weight Chart
          if (hasWeightData) ...[
            _buildSectionHeader('Évolution du poids', Icons.monitor_weight, _coral),
            const SizedBox(height: 16),
            _buildWeightChart(weightData!),
            const SizedBox(height: 32),
          ],

          // Temperature Chart
          if (hasTempData) ...[
            _buildSectionHeader('Historique de température', Icons.thermostat, _mint),
            const SizedBox(height: 16),
            _buildTemperatureChart(tempData!),
            const SizedBox(height: 32),
          ],

          // Heart Rate Chart
          if (hasHeartData) ...[
            _buildSectionHeader('Fréquence cardiaque', Icons.favorite, _purple),
            const SizedBox(height: 16),
            _buildHeartRateChart(heartData!),
          ],

          // Empty state
          if (!hasWeightData && !hasTempData && !hasHeartData) _buildEmptyState(),
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
              label: 'Poids actuel',
              value: '${currentWeight.toStringAsFixed(1)} kg',
              color: _coral,
              subtitle: minWeight != null && maxWeight != null
                  ? 'Min: ${minWeight.toStringAsFixed(1)} / Max: ${maxWeight.toStringAsFixed(1)}'
                  : null,
            ),
          ),
        if (currentWeight != null && currentTemp != null) const SizedBox(width: 12),
        if (currentTemp != null)
          Expanded(
            child: _buildStatCard(
              icon: Icons.thermostat,
              label: 'Température',
              value: '${currentTemp.toStringAsFixed(1)}°C',
              color: _mint,
              subtitle: avgTemp != null ? 'Moy: ${avgTemp.toStringAsFixed(1)}°C' : null,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              color: _ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _buildWeightChart(Map<String, dynamic> weightData) {
    final dataList = (weightData['data'] as List).cast<Map<String, dynamic>>();
    if (dataList.isEmpty) return const SizedBox.shrink();

    final spots = dataList.asMap().entries.map((entry) {
      final data = entry.value;
      final weight = _toDouble(data['weightKg']) ?? 0.0;
      return FlSpot(entry.key.toDouble(), weight);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
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
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(dataList, 'weightKg', 'kg'),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart(Map<String, dynamic> tempData) {
    final dataList = (tempData['data'] as List).cast<Map<String, dynamic>>();
    if (dataList.isEmpty) return const SizedBox.shrink();

    final spots = dataList.asMap().entries.map((entry) {
      final data = entry.value;
      final temp = _toDouble(data['temperatureC']) ?? 0.0;
      return FlSpot(entry.key.toDouble(), temp);
    }).toList();

    final minY = 36.0;
    final maxY = 40.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
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
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(dataList, 'temperatureC', '°C'),
        ],
      ),
    );
  }

  Widget _buildHeartRateChart(Map<String, dynamic> heartData) {
    final dataList = (heartData['data'] as List).cast<Map<String, dynamic>>();
    if (dataList.isEmpty) return const SizedBox.shrink();

    final spots = dataList.asMap().entries.map((entry) {
      final data = entry.value;
      final hr = _toDouble(data['heartRate']) ?? 0.0;
      return FlSpot(entry.key.toDouble(), hr);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
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
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(dataList, 'heartRate', 'bpm'),
        ],
      ),
    );
  }

  Widget _buildChartLegend(List<Map<String, dynamic>> data, String valueKey, String unit) {
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
          final context = item['context'] as String?;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _coralSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _coral),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_toDouble(value)?.toStringAsFixed(1) ?? value} $unit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                ),
                if (context != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    context,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'Aucune donnée de santé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les données de santé apparaîtront ici\naprès les visites vétérinaires',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
