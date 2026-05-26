import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/shared/splash_background.dart';

class SplashOnboardingPage extends StatelessWidget {
  const SplashOnboardingPage({
    super.key,
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.accent,
    this.variant = 1,
  });

  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color accent;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + 52;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 120;
    final compact = MediaQuery.sizeOf(context).height < 720;

    return SplashBackground(
      variant: variant,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentMinHeight = (constraints.maxHeight - topInset - bottomInset).clamp(0.0, double.infinity);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, topInset, 24, bottomInset),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentMinHeight, maxWidth: 760),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.1)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        'STEP $step / 2',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 28),
                    Container(
                      padding: EdgeInsets.all(compact ? 18 : 24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [accent.withValues(alpha: 0.4), accent.withValues(alpha: 0.05)],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                      ),
                      child: Icon(icon, size: compact ? 44 : 52, color: Colors.white),
                    ),
                    SizedBox(height: compact ? 20 : 28),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 24 : 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: compact ? 14 : 16,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 24),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 14 : 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < bullets.length; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: i < bullets.length - 1 ? 12 : 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      bullets[i],
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        fontSize: compact ? 13 : 14,
                                        height: 1.45,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
