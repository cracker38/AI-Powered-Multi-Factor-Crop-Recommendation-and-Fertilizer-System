import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Premium app mark for splash and auth.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 88,
    this.showRing = true,
    this.iconColor = Colors.white,
    this.glow = true,
  });

  final double size;
  final bool showRing;
  final Color iconColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow)
            Container(
              width: size * 1.15,
              height: size * 1.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    blurRadius: size * 0.35,
                    spreadRadius: size * 0.05,
                  ),
                ],
              ),
            ),
          if (showRing)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.5),
              ),
            ),
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.eco_rounded, size: size * 0.44, color: iconColor),
          ),
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: Container(
              padding: EdgeInsets.all(size * 0.08),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFFFFD54F)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.psychology_rounded, size: size * 0.17, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
