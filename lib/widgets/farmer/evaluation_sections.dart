import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/agriculture_options.dart';
import '../../core/farmer_theme.dart';
import '../../models/fertilizer_recommendation.dart';
import 'farmer_card.dart';
import 'farmer_section_title.dart';
import 'nutrient_bar_chart.dart';

class SoilHealthCard extends StatelessWidget {
  const SoilHealthCard({super.key, required this.score, required this.label});
  final double score;
  final String label;

  Color get _color {
    if (score >= 75) return const Color(0xFF2E7D32);
    if (score >= 50) return const Color(0xFFF9A825);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    return FarmerCard(
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  strokeWidth: 7,
                  color: _color,
                  backgroundColor: _color.withValues(alpha: 0.15),
                ),
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Soil health index', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  label.isNotEmpty ? label : 'Assessment',
                  style: TextStyle(color: _color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Based on N-P-K, pH, and moisture readings',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FertilizerListSection extends StatelessWidget {
  const FertilizerListSection({super.key, required this.fertilizers});
  final List<FertilizerRecommendation> fertilizers;

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':
        return const Color(0xFFC62828);
      case 'low':
        return AppColors.textSecondary;
      default:
        return const Color(0xFFF57C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fertilizers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FarmerSectionTitle(title: 'Fertilizer recommendations'),
        ...fertilizers.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FarmerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.compost_rounded, color: Color(0xFFE65100)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            if (f.npk != '—')
                              Text('NPK: ${f.npk}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _priorityColor(f.priority).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _priorityColor(f.priority),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.scale_rounded, f.applicationRate),
                  const SizedBox(height: 6),
                  _infoRow(Icons.schedule_rounded, f.timing),
                  const SizedBox(height: 6),
                  _infoRow(Icons.info_outline_rounded, f.purpose),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary))),
      ],
    );
  }
}

class NutrientAnalysisSection extends StatelessWidget {
  const NutrientAnalysisSection({super.key, required this.analysis});
  final NutrientAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return FarmerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nutrient analysis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            '${AgricultureOptions.soilLabel(analysis.soilType)} · ${AgricultureOptions.seasonLabel(analysis.season)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          NutrientBarChart(current: analysis.current, optimal: analysis.optimal),
        ],
      ),
    );
  }
}

class WeatherInsightSection extends StatelessWidget {
  const WeatherInsightSection({super.key, required this.weather});
  final WeatherInsight weather;

  @override
  Widget build(BuildContext context) {
    return FarmerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_rounded, color: Color(0xFF1565C0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather.seasonName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(weather.seasonMonths, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(weather.seasonalRainfall, style: const TextStyle(height: 1.45, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(weather.seasonalAdvice, style: const TextStyle(height: 1.45, color: AppColors.textSecondary)),
          if (weather.districtNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(weather.districtNote, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
          ],
          ...weather.alerts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFF57F17)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a, style: const TextStyle(fontSize: 13, height: 1.4))),
                  ],
                ),
              ),
            ),
          ),
          if (weather.liveAvailable) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sensors_rounded, size: 18, color: Color(0xFF1565C0)),
                      SizedBox(width: 6),
                      Text('Live forecast (Open-Meteo)', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (weather.liveTemperatureC != null)
                    Text('Now: ${weather.liveTemperatureC}°C · Humidity ${weather.liveHumidityPct?.toStringAsFixed(0) ?? "—"}%'),
                  if (weather.forecastPrecipitationMm7d != null)
                    Text('7-day rain: ${weather.forecastPrecipitationMm7d} mm'),
                  if (weather.forecastDaily.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...weather.forecastDaily.take(4).map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${d.date} · ${d.precipitationMm} mm rain · ${d.tempMinC?.toStringAsFixed(0) ?? "?"}–${d.tempMaxC?.toStringAsFixed(0) ?? "?"}°C',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ],
          if (weather.forecastNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              weather.forecastNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class PrecisionNotesSection extends StatelessWidget {
  const PrecisionNotesSection({super.key, required this.notes});
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return FarmerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FarmerTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.eco_rounded, color: FarmerTheme.accent),
              ),
              const SizedBox(width: 12),
              const Text('Precision agriculture', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ...notes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Expanded(child: Text(n, style: const TextStyle(height: 1.45, color: AppColors.textSecondary))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
