import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/live_climate.dart';

class LiveClimateBanner extends StatelessWidget {
  const LiveClimateBanner({
    super.key,
    required this.climate,
    this.loading = false,
    this.onRefresh,
  });

  final LiveClimate? climate;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Loading live weather for your district…')),
          ],
        ),
      );
    }

    final c = climate;
    if (c == null) return const SizedBox.shrink();

    if (!c.available) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                c.reason.isNotEmpty
                    ? 'Live weather unavailable: ${c.reason}'
                    : 'Live weather unavailable. Set your district in profile or try again.',
                style: TextStyle(color: Colors.orange.shade900, height: 1.35),
              ),
            ),
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Retry',
              ),
          ],
        ),
      );
    }

    final sourceLine = [
      if (c.source.isNotEmpty) c.source,
      if (c.secondarySource.isNotEmpty) c.secondarySource,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_sync_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live climate (automatic)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.district} · ${c.temperatureC?.toStringAsFixed(1) ?? "—"}°C · '
                      '${c.humidityPct?.toStringAsFixed(0) ?? "—"}% humidity · '
                      '${c.rainfallMm?.toStringAsFixed(0) ?? "—"} mm rain (7-day)',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (sourceLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sourceLine,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh weather',
                ),
            ],
          ),
          if (c.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              c.note,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
