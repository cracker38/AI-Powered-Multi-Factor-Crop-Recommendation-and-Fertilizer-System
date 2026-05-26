import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/admin_theme.dart';

class AdminQuickNav extends StatelessWidget {
  const AdminQuickNav({
    super.key,
    required this.onFarmers,
    required this.onData,
    required this.onInsights,
    required this.onSettings,
  });

  final VoidCallback onFarmers;
  final VoidCallback onData;
  final VoidCallback onInsights;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(Icons.people_rounded, 'Farmers', 'Accounts', onFarmers, const Color(0xFF1565C0)),
      _Item(Icons.psychology_rounded, 'ML & data', 'Train', onData, AppColors.primary),
      _Item(Icons.analytics_rounded, 'Insights', 'Reports', onInsights, const Color(0xFF6A1B9A)),
      _Item(Icons.tune_rounded, 'Settings', 'Admin', onSettings, const Color(0xFF455A64)),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _NavCard(item: items[i])),
        ],
      ],
    );
  }
}

class _Item {
  const _Item(this.icon, this.label, this.hint, this.onTap, this.color);
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final Color color;
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.color.withValues(alpha: 0.12)),
            boxShadow: AdminTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              children: [
                Icon(item.icon, color: item.color, size: 26),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                Text(
                  item.hint,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
