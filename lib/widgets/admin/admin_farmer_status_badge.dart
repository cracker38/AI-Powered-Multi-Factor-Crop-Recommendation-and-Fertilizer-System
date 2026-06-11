import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/admin_user.dart';

class AdminFarmerStatusBadge extends StatelessWidget {
  const AdminFarmerStatusBadge({super.key, required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  (String, Color, Color) _style() {
    if (user.isPending) {
      return ('Pending', Colors.amber.shade900, Colors.amber.shade50);
    }
    if (user.isRejected) {
      return ('Rejected', AppColors.errorText, Colors.red.shade50);
    }
    if (user.disabled) {
      return ('Disabled', Colors.orange.shade900, Colors.orange.shade50);
    }
    return ('Active', AppColors.primary, AppColors.primary.withValues(alpha: 0.1));
  }
}
