import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/agriculture_options.dart';
import '../../core/app_colors.dart';
import '../../core/brand.dart';
import '../../core/farmer_theme.dart';
import '../../models/farmer_tip.dart';
import '../../models/prediction_history_item.dart';
import '../../models/user_profile.dart';
import '../../services/farmer_controller.dart';
import '../../services/farmer_preferences.dart';
import '../../widgets/farmer/farmer_card.dart';
import '../../widgets/farmer/farmer_dashboard_header.dart';
import '../../widgets/farmer/farmer_quick_action.dart';
import '../../widgets/farmer/farmer_section_title.dart';
import '../../widgets/farmer/farmer_shared.dart';

class FarmerDashboardPage extends StatefulWidget {
  const FarmerDashboardPage({
    super.key,
    required this.profile,
    required this.farmer,
    required this.onGetRecommendation,
    required this.onViewHistory,
    required this.onViewProfile,
  });

  final UserProfile profile;
  final FarmerController farmer;
  final VoidCallback onGetRecommendation;
  final VoidCallback onViewHistory;
  final VoidCallback onViewProfile;

  @override
  State<FarmerDashboardPage> createState() => _FarmerDashboardPageState();
}

class _FarmerDashboardPageState extends State<FarmerDashboardPage> {
  bool _showTips = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    widget.farmer.refresh(force: true);
  }

  Future<void> _loadPrefs() async {
    final show = await FarmerPreferences.showTipsOnDashboard();
    if (mounted) setState(() => _showTips = show);
  }

  Future<void> _openLatestFeedback() async {
    final latest = widget.farmer.latestEvaluation;
    if (latest == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run an evaluation first, then rate your harvest outcome.')),
        );
      }
      widget.onGetRecommendation();
      return;
    }
    await showFarmerEvaluationDetail(context, api: widget.farmer.api, predictionId: latest.id);
    widget.farmer.refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.farmer,
      builder: (context, _) {
        final f = widget.farmer;
        final name = widget.profile.displayName ?? 'Farmer';
        final recent = f.history.take(5).toList();

        return ColoredBox(
          color: FarmerTheme.surface,
          child: RefreshIndicator(
            onRefresh: () => f.refresh(force: true),
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: FarmerDashboardHeader(
                    displayName: name,
                    district: widget.profile.district,
                    evaluationCount: f.evaluationCount,
                    avgSoilHealth: f.avgSoilHealth,
                    lastCrop: f.latestEvaluation?.topCrop,
                    apiOnline: f.apiOnline && f.error == null,
                  ),
                ),
                if (f.loading && f.history.isEmpty && f.error == null)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (f.error != null && f.history.isEmpty)
                  SliverFillRemaining(
                    child: FarmerErrorState(message: f.error!, onRetry: () => f.refresh(force: true)),
                  )
                else ...[
                  if (widget.profile.district == null || widget.profile.district!.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(child: _districtPrompt()),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, widget.profile.district == null ? 12 : 20, 16, 0),
                    sliver: SliverToBoxAdapter(child: _primaryAction()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: const SliverToBoxAdapter(child: FarmerCapabilityRow()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: _quickActions(f.latestEvaluation != null)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: FarmerSectionTitle(
                        title: 'Recent evaluations',
                        action: TextButton(onPressed: widget.onViewHistory, child: const Text('View all')),
                      ),
                    ),
                  ),
                  if (recent.isEmpty)
                    SliverToBoxAdapter(
                      child: FarmerCard(
                        child: FarmerEmptyState(
                          icon: Icons.landscape_rounded,
                          title: 'No field evaluations yet',
                          message:
                              'Start your first ${Brand.productName} assessment for ranked crops, a fertilizer plan, soil health score, and district weather.',
                          actionLabel: 'Start first evaluation',
                          onAction: widget.onGetRecommendation,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _evaluationTile(recent[i]),
                          childCount: recent.length,
                        ),
                      ),
                    ),
                  if (_showTips && f.tips.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      sliver: const SliverToBoxAdapter(
                        child: FarmerSectionTitle(title: 'Extension advisory'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _advisoryCard(f.tips[i]),
                          childCount: f.tips.length.clamp(0, 4),
                        ),
                      ),
                    ),
                  ] else
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _districtPrompt() {
    return FarmerCard(
      padding: const EdgeInsets.all(14),
      borderColor: FarmerTheme.accent.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add your district', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  'Live Open-Meteo weather improves recommendations for ${Brand.region}.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                ),
              ],
            ),
          ),
          TextButton(onPressed: widget.onViewProfile, child: const Text('Set')),
        ],
      ),
    );
  }

  Widget _primaryAction() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onGetRecommendation,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: FarmerTheme.heroCtaDecoration(),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: FarmerTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MULTI-FACTOR AI',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.9)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'New crop & fertilizer evaluation',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter N-P-K, pH, moisture, climate, soil type, and season — get ranked crops, fertilizer plan, charts, and live weather.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions(bool hasEvaluations) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FarmerQuickAction(
                icon: Icons.analytics_rounded,
                label: 'Analyze',
                color: AppColors.primary,
                onTap: widget.onGetRecommendation,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FarmerQuickAction(
                icon: Icons.history_rounded,
                label: 'History',
                color: const Color(0xFF1976D2),
                onTap: widget.onViewHistory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FarmerQuickAction(
                icon: Icons.rate_review_rounded,
                label: 'Feedback',
                color: const Color(0xFFF57C00),
                onTap: hasEvaluations ? _openLatestFeedback : widget.onGetRecommendation,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FarmerQuickAction(
                icon: Icons.person_rounded,
                label: 'Profile',
                color: const Color(0xFF5D4037),
                onTap: widget.onViewProfile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _evaluationTile(PredictionHistoryItem h) {
    final when = DateFormat.MMMd().format(h.createdAt);
    final pct = (h.topConfidence * 100).toStringAsFixed(0);
    final health = h.soilHealthScore;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FarmerCard(
        onTap: () async {
          await showFarmerEvaluationDetail(context, api: widget.farmer.api, predictionId: h.id);
          widget.farmer.refresh(force: true);
        },
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primaryLight.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.topCrop.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    '$when · ${AgricultureOptions.seasonLabel(h.season)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                if (health > 0)
                  Text('Soil $health', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _advisoryCard(FarmerTip tip) {
    final icon = switch (tip.category) {
      'fertilizer' => Icons.compost_rounded,
      'crop' => Icons.grass_rounded,
      'system' => Icons.settings_suggest_rounded,
      _ => Icons.tips_and_updates_rounded,
    };
    final label = switch (tip.category) {
      'fertilizer' => 'FERTILIZER',
      'crop' => 'CROP',
      'system' => 'SYSTEM',
      _ => 'ADVISORY',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FarmerCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(tip.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    tip.message,
                    style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
