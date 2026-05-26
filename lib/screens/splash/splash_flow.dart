import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/app_colors.dart';
import '../../core/brand.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/shared/modern_auth_decor.dart';
import 'splash_brand_screen.dart';
import 'splash_onboarding_page.dart';

class SplashFlow extends StatefulWidget {
  const SplashFlow({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashFlow> createState() => _SplashFlowState();
}

class _SplashFlowState extends State<SplashFlow> {
  static const _pageCount = 3;

  final _pageController = PageController();
  final _onboarding = OnboardingService();
  int _page = 0;
  bool _showBrandOnly = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final done = await _onboarding.isCompleted();
    if (!mounted) return;
    if (done) {
      setState(() => _showBrandOnly = true);
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (mounted) widget.onFinished();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _onboarding.markCompleted();
    widget.onFinished();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showBrandOnly) {
      return const SplashBrandScreen(animate: true);
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              SplashBrandScreen(
                animate: true,
                onAutoAdvance: _page == 0
                    ? () {
                        if (_page == 0 && _pageController.hasClients) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      }
                    : null,
              ),
              const SplashOnboardingPage(
                step: 1,
                variant: 1,
                icon: Icons.analytics_outlined,
                title: 'Intelligent\ncrop selection',
                subtitle:
                    'Machine learning ranks the best crops for your soil, climate, and season.',
                bullets: [
                  'N-P-K nutrients, pH & moisture',
                  'Temperature, rainfall & humidity',
                  'District-based live weather',
                ],
                accent: AppColors.accent,
              ),
              const SplashOnboardingPage(
                step: 2,
                variant: 2,
                icon: Icons.compost_rounded,
                title: 'Precision\nfertilizer plans',
                subtitle:
                    'Actionable fertilizer guidance and harvest feedback for continuous improvement.',
                bullets: [
                  'Urea, DAP, MOP & organic advice',
                  'Soil health & nutrient charts',
                  'Rwanda Season A / B / C',
                ],
                accent: Color(0xFF81C784),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        Brand.productName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const Spacer(),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pageCount,
                    effect: WormEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 6,
                      activeDotColor: AppColors.accent,
                      dotColor: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SplashBottomBar(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_page == _pageCount - 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            'Secure access to ${Brand.productName}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      GradientPrimaryButton(
                        onPressed: _next,
                        label: _page == _pageCount - 1 ? 'Get started' : 'Continue',
                        icon: Icons.arrow_forward_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
