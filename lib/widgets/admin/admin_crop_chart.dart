import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class AdminCropChart extends StatelessWidget {
  const AdminCropChart({super.key, required this.distribution});

  final Map<String, int> distribution;

  static const _palette = [
    Color(0xFF2E7D32),
    Color(0xFF1976D2),
    Color(0xFF7B1FA2),
    Color(0xFFF57C00),
    Color(0xFF00897B),
    Color(0xFFC62828),
    Color(0xFF5D4037),
    Color(0xFF455A64),
  ];

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No prediction data yet. Crop breakdown appears after farmers use recommendations.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }

    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    final entries = distribution.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _bar(
              context,
              crop: entries[i].key,
              count: entries[i].value,
              total: total,
              color: _palette[i % _palette.length],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required String crop,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? count / total : 0.0;
    final label = crop.isEmpty ? 'unknown' : crop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            Text(
              '$count · ${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}
