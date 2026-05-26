import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/brand.dart';
import 'brand_logo.dart';
import 'splash_background.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key, this.message = 'Loading your workspace…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SplashBackground(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 88, glow: true),
                const SizedBox(height: 28),
                Text(
                  Brand.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
