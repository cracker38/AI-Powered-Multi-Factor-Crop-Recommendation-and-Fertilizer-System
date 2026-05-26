import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Simple N-P-K bar chart: current vs optimal (kg/ha).
class NutrientBarChart extends StatelessWidget {
  const NutrientBarChart({
    super.key,
    required this.current,
    required this.optimal,
  });

  final Map<String, double> current;
  final Map<String, double> optimal;

  @override
  Widget build(BuildContext context) {
    const keys = ['N', 'P', 'K'];
    final maxVal = [
      ...current.values,
      ...optimal.values,
    ].fold<double>(1, (a, b) => b > a ? b : a);

    return Column(
      children: keys.map((k) {
        final cur = current[k] ?? 0;
        final opt = optimal[k] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    '${cur.toStringAsFixed(0)} / ${opt.toStringAsFixed(0)} kg/ha',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (opt / maxVal).clamp(0.05, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (cur / maxVal).clamp(0.05, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  _LegendDot(color: AppColors.primary, label: 'Current'),
                  SizedBox(width: 12),
                  _LegendDot(
                    color: Color(0xFFA5D6A7),
                    label: 'Target',
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
