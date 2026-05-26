import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../shared/modern_auth_decor.dart';

class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D3B12),
            AppColors.gradientTop,
            Color(0xFF256029),
            Color(0xFF1B5E20),
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: AgriPatternPainter()),
          Positioned(
            top: -100,
            right: -50,
            child: _orb(240, AppColors.accent.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: _orb(200, Colors.white.withValues(alpha: 0.07)),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
