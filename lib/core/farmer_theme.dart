import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class FarmerTheme {
  static const surface = Color(0xFFEEF3EE);
  static const accent = Color(0xFFFFB300);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2E0F), Color(0xFF1B5E20), Color(0xFF43A047)],
  );

  static BoxDecoration headerDecoration() => const BoxDecoration(gradient: headerGradient);

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow,
      );

  static BoxDecoration heroCtaDecoration() => BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary.withValues(alpha: 0.95)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );
}
