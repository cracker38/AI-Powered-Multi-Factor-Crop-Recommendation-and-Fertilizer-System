import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/agriculture_options.dart';
import '../../core/app_colors.dart';
import '../../core/farmer_theme.dart';
import '../../models/prediction_history_item.dart';
import '../../services/api_service.dart';
import '../../services/farmer_controller.dart';
import '../../widgets/farmer/farmer_card.dart';
import '../../widgets/farmer/farmer_page_header.dart';
import '../../widgets/farmer/farmer_shared.dart';

class FarmerHistoryPage extends StatefulWidget {
  const FarmerHistoryPage({super.key, required this.api, required this.farmer});

  final ApiService api;
  final FarmerController farmer;

  @override
  State<FarmerHistoryPage> createState() => _FarmerHistoryPageState();
}

class _FarmerHistoryPageState extends State<FarmerHistoryPage> {
  String _query = '';

  List<PredictionHistoryItem> get _all => widget.farmer.history;

  List<PredictionHistoryItem> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where(
          (h) =>
              h.topCrop.toLowerCase().contains(q) ||
              AgricultureOptions.seasonLabel(h.season).toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _load() => widget.farmer.refresh(force: true);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.farmer,
      builder: (context, _) {
        final f = widget.farmer;

        return ColoredBox(
          color: FarmerTheme.surface,
          child: Column(
            children: [
              FarmerPageHeader(
                title: 'Evaluation history',
                subtitle: '${_all.length} saved recommendations · tap for full report',
                icon: Icons.history_rounded,
                bottom: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search crop or season…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              Expanded(
                child: f.loading && _all.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : f.error != null && _all.isEmpty
                        ? FarmerErrorState(message: f.error!, onRetry: _load)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.primary,
                            child: _filtered.isEmpty
                                ? ListView(
                                    children: [
                                      FarmerEmptyState(
                                        icon: Icons.inbox_rounded,
                                        title: _all.isEmpty ? 'No evaluations yet' : 'No matches',
                                        message: _all.isEmpty
                                            ? 'Your crop and fertilizer reports appear here after each analysis.'
                                            : 'Try a different search term.',
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                    itemCount: _filtered.length,
                                    itemBuilder: (_, i) {
                                      final h = _filtered[i];
                                      final pct = (h.topConfidence * 100).toStringAsFixed(0);
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: FarmerCard(
                                          onTap: () async {
                                            await showFarmerEvaluationDetail(
                                              context,
                                              api: widget.api,
                                              predictionId: h.id,
                                            );
                                            _load();
                                          },
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.eco_rounded, color: AppColors.primary),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      h.topCrop.toUpperCase(),
                                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${DateFormat.yMMMd().add_jm().format(h.createdAt)} · ${AgricultureOptions.seasonLabel(h.season)}',
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                    ),
                                                    if (h.soilHealthScore > 0)
                                                      Text(
                                                        'Soil health ${h.soilHealthScore.toStringAsFixed(0)}',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '$pct%',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.primary,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
