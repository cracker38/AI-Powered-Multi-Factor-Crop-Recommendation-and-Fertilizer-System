import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'modern_auth_decor.dart';

/// Layered gradient + ambient shapes for splash/onboarding.
class SplashBackground extends StatelessWidget {
  const SplashBackground({super.key, required this.child, this.variant = 0});

  final Widget child;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final mid = switch (variant) {
      1 => const Color(0xFF1E6B24),
      2 => const Color(0xFF174D1C),
      _ => AppColors.gradientMid,
    };
    final bottom = switch (variant) {
      2 => const Color(0xFF0F3312),
      _ => const Color(0xFF2E7D32),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D3B12),
            AppColors.gradientTop,
            mid,
            bottom,
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: AgriPatternPainter()),
          Positioned(
            top: -120,
            right: -80,
            child: _glowOrb(260, AppColors.accent.withValues(alpha: 0.15)),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.15,
            left: -60,
            child: _glowOrb(180, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -40,
            right: 20,
            child: _glowOrb(200, Colors.white.withValues(alpha: 0.06)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
