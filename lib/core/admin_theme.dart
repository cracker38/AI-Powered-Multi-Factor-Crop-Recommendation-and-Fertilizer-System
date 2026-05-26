import 'package:flutter/material.dart';

abstract final class AdminTheme {
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2E0F), Color(0xFF1B5E20), Color(0xFF2E7D32)],
  );

  static const surface = Color(0xFFEEF3EE);
  static const card = Colors.white;
  static const accent = Color(0xFFFFC107);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static BoxDecoration headerDecoration() => const BoxDecoration(gradient: headerGradient);
}
