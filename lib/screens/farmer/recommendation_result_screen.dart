import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/farmer_theme.dart';
import '../../models/crop_prediction.dart';
import '../../widgets/farmer/evaluation_sections.dart';
import '../../services/api_service.dart';
import '../../widgets/farmer/farmer_card.dart';
import '../../widgets/farmer/farmer_section_title.dart';
import '../../widgets/farmer/outcome_feedback_sheet.dart';

class RecommendationResultScreen extends StatelessWidget {
  const RecommendationResultScreen({
    super.key,
    required this.prediction,
    this.api,
  });

  final CropPrediction prediction;
  final ApiService? api;

  @override
  Widget build(BuildContext context) {
    final pct = prediction.topConfidence;
    final pctLabel = (pct * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: FarmerTheme.surface,
      appBar: AppBar(
        title: const Text('Crop & fertilizer plan'),
        backgroundColor: FarmerTheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: FarmerTheme.heroCtaDecoration(),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: Colors.white24,
                        color: FarmerTheme.accent,
                      ),
                    ),
                    Text(
                      '$pctLabel%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'AI recommended crop',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  prediction.topCrop.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suitability index: $pctLabel%',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (prediction.seasonLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    prediction.seasonLabel,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (prediction.isLowConfidence) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFE65100)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Low suitability — follow the improvement plan below before relying on this crop choice.',
                      style: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (prediction.improvementActions.isNotEmpty)
            ImprovementActionsSection(
              actions: prediction.improvementActions,
              confidencePct: pctLabel,
            ),
          if (prediction.improvementActions.isNotEmpty) const SizedBox(height: 12),
          if (prediction.environmentAnalysis.isNotEmpty) ...[
            EnvironmentAnalysisSection(lines: prediction.environmentAnalysis),
            const SizedBox(height: 12),
          ],
          if (prediction.soilHealthScore > 0)
            SoilHealthCard(score: prediction.soilHealthScore, label: prediction.soilHealthLabel),
          const SizedBox(height: 12),
          if (prediction.nutrientAnalysis != null)
            NutrientAnalysisSection(analysis: prediction.nutrientAnalysis!),
          const SizedBox(height: 12),
          FertilizerListSection(fertilizers: prediction.fertilizers),
          const SizedBox(height: 12),
          if (prediction.weatherInsight != null) WeatherInsightSection(weather: prediction.weatherInsight!),
          const SizedBox(height: 12),
          if (prediction.precisionNotes.isNotEmpty) PrecisionNotesSection(notes: prediction.precisionNotes),
          const SizedBox(height: 12),
          FarmerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.biotech_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Text('Scientific reasoning', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(prediction.explanation, style: const TextStyle(height: 1.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (prediction.predictionId != null && api != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showOutcomeFeedbackSheet(
                context,
                api: api!,
                predictionId: prediction.predictionId!,
                recommendedCrop: prediction.topCrop,
              ),
              icon: const Icon(Icons.rate_review_rounded),
              label: const Text('Rate harvest outcome'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
          if (prediction.predictionId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Saved to your recommendation history',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const FarmerSectionTitle(title: 'All ranked crops'),
          ...prediction.fullRanking.asMap().entries.map((e) {
            final r = e.value;
            final isTop = e.key == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FarmerCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderColor: isTop ? AppColors.primary : null,
                child: Row(
                  children: [
                    Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isTop ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        r.crop,
                        style: TextStyle(
                          fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
                          fontSize: isTop ? 16 : 14,
                        ),
                      ),
                    ),
                    Text(
                      '${(r.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isTop ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Model: ${prediction.modelVersion}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
