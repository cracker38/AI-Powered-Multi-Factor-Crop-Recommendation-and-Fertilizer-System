import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
