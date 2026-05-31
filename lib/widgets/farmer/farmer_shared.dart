import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/farmer_theme.dart';
import '../../models/prediction_detail.dart';
import '../../services/api_service.dart';
import 'evaluation_sections.dart';
import 'outcome_feedback_sheet.dart';

class FarmerEmptyState extends StatelessWidget {
  const FarmerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class FarmerErrorState extends StatelessWidget {
  const FarmerErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.errorText),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.errorText)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class FarmerCapabilityRow extends StatelessWidget {
  const FarmerCapabilityRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _Cap(icon: Icons.grass_rounded, label: 'Crop AI')),
        SizedBox(width: 8),
        Expanded(child: _Cap(icon: Icons.compost_rounded, label: 'Fertilizer')),
        SizedBox(width: 8),
        Expanded(child: _Cap(icon: Icons.cloud_rounded, label: 'Weather')),
      ],
    );
  }
}

class _Cap extends StatelessWidget {
  const _Cap({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: FarmerTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class FarmerOnlineBadge extends StatelessWidget {
  const FarmerOnlineBadge({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF69F0AE) : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            online ? 'SYNCED' : 'OFFLINE',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

Future<void> showFarmerEvaluationDetail(
  BuildContext context, {
  required ApiService api,
  required String predictionId,
}) async {
  try {
    final json = await api.fetchPredictionDetail(predictionId);
    final detail = PredictionDetail.fromJson(json);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(detail.topCrop.toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '${(detail.topConfidence * 100).toStringAsFixed(1)}% suitability',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              if (detail.seasonLabel.isNotEmpty)
                Text(detail.seasonLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(
                _formatDate(detail.createdAt),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (detail.improvementActions.isNotEmpty)
                ImprovementActionsSection(
                  actions: detail.improvementActions,
                  confidencePct: (detail.topConfidence * 100).toStringAsFixed(1),
                ),
              if (detail.improvementActions.isNotEmpty) const SizedBox(height: 12),
              if (detail.soilHealthScore > 0)
                SoilHealthCard(score: detail.soilHealthScore, label: detail.soilHealthLabel),
              const SizedBox(height: 12),
              if (detail.nutrientAnalysis != null) NutrientAnalysisSection(analysis: detail.nutrientAnalysis!),
              const SizedBox(height: 8),
              FertilizerListSection(fertilizers: detail.fertilizers),
              const SizedBox(height: 8),
              if (detail.weatherInsight != null) WeatherInsightSection(weather: detail.weatherInsight!),
              const SizedBox(height: 12),
              _detailBlock('ML explanation', detail.explanation),
              const SizedBox(height: 16),
              _detailBlock(
                'Field data',
                'N ${detail.nitrogen} · P ${detail.phosphorus} · K ${detail.potassium}\n'
                'pH ${detail.soilPh} · Moisture ${detail.soilMoisture}% · ${detail.temperatureC}°C\n'
                'Rain ${detail.rainfallMm} mm · Humidity ${detail.humidityPct}%',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => showOutcomeFeedbackSheet(
                  c,
                  api: api,
                  predictionId: detail.id,
                  recommendedCrop: detail.topCrop,
                  existingRating: detail.hasFeedback ? detail.feedbackRating : null,
                ),
                icon: Icon(detail.hasFeedback ? Icons.check_circle_rounded : Icons.rate_review_rounded),
                label: Text(detail.hasFeedback ? 'View harvest feedback' : 'Rate harvest outcome'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

String _formatDate(DateTime dt) {
  return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

Widget _detailBlock(String title, String body) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      Text(body, style: const TextStyle(height: 1.45, color: AppColors.textSecondary)),
    ],
  );
}
