import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/brand.dart';
import '../../widgets/shared/brand_logo.dart';
import '../../widgets/shared/modern_auth_decor.dart';
import '../../widgets/shared/splash_background.dart';

class SplashBrandScreen extends StatefulWidget {
  const SplashBrandScreen({
    super.key,
    this.animate = false,
    this.onAutoAdvance,
  });

  final bool animate;
  final VoidCallback? onAutoAdvance;

  @override
  State<SplashBrandScreen> createState() => _SplashBrandScreenState();
}

class _SplashBrandScreenState extends State<SplashBrandScreen> with TickerProviderStateMixin {
  late final AnimationController _main;
  late final Animation<double> _logoScale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _main = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _logoScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _main, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.2, 1, curve: Curves.easeOut)),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.25, 1, curve: Curves.easeOutCubic)),
    );
    if (widget.animate) {
      _main.forward();
      if (widget.onAutoAdvance != null) {
        Future<void>.delayed(const Duration(milliseconds: 2800), () {
          if (mounted) widget.onAutoAdvance!();
        });
      }
    } else {
      _main.value = 1;
    }
  }

  @override
  void dispose() {
    _main.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;
    final compact = MediaQuery.sizeOf(context).height < 720;
    final logoSize = compact ? 88.0 : 112.0;

    return SplashBackground(
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(28, 8, 28, bottomInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - bottomInset - 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: BrandLogo(size: logoSize, glow: true),
                        ),
                        SizedBox(height: compact ? 20 : 32),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFE8F5E9)],
                          ).createShader(bounds),
                          child: Text(
                            Brand.productName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  height: 1.1,
                                  fontSize: compact ? 28 : null,
                                ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          Brand.productFullName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: compact ? 13 : 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            GlassChip(icon: Icons.place_rounded, label: Brand.region),
                            GlassChip(icon: Icons.verified_rounded, label: 'Production'),
                          ],
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _miniStat(Icons.grass_rounded, 'Crop AI'),
                              const SizedBox(width: 10),
                              _miniStat(Icons.compost_rounded, 'Fertilizer'),
                              const SizedBox(width: 10),
                              _miniStat(Icons.wb_sunny_rounded, 'Weather'),
                            ],
                          ),
                        ],
                        SizedBox(height: compact ? 24 : 40),
                        Text(
                          Brand.tagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: compact ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Brand.versionLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
