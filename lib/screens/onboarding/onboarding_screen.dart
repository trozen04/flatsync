import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_text_styles.dart';
import '../../constants/flutter_font_style.dart';
import '../../screens/auth/login_screen.dart';
import '../../utils/image_assets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String seenKey = 'has_seen_onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _completing = false;

  late final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Ditch the Mental Math',
      description:
          'Easily add and split expenses between friends, roommates, and groups. Track real-time balances to see exactly who owes you and who you owe.',
      imagePath: ImageAssets.onboardingImage1,
      gradient:  [Color(0xFFE9F8FF), Color(0xFFCDEFFF), Color(0xFFBFE7F8)],
      orbColor:  Color(0x6650B7CC),
      buttonBackground:  Color(0xFF2C9DA1),
      buttonForeground: Colors.white,
      activeDotColor:  Color(0xFF2C9DA1),
    ),
    _OnboardingPageData(
      title: 'Effortless Connections',
      description:
          'Sync your contacts to find friends in seconds. Secure PIN-based authentication and OTP verification keep your data safe and onboarding easy.',
      imagePath: ImageAssets.onboardingImage2,
      gradient:  [Color(0xFFFFE2AE), Color(0xFFFFC87C), Color(0xFFFFB25C)],
      orbColor:  Color(0x66FF9F5B),
      buttonBackground:  Color(0xFF2C9DA1),
      buttonForeground: Colors.white,
      activeDotColor:  Color(0xFF2C9DA1),
    ),
    _OnboardingPageData(
      title: 'Always in Sync',
      description:
          'Works without internet and auto-syncs when back online. Enjoy real-time updates across multiple devices for full transparency.',
      imagePath: ImageAssets.onboardingImage3,
      gradient:  [Color(0xFFE7C7FF), Color(0xFFBA8CF6), Color(0xFF8A56E9)],
      orbColor:  Color(0x665E2CB5),
      buttonBackground: Colors.white,
      buttonForeground: Color(0xFF1E1F24),
      activeDotColor:  Color(0xFF4CC28A),
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_completing) return;

    setState(() => _completing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.seenKey, true);

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (mounted) {
      setState(() => _completing = false);
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_isLastPage) {
      await _completeOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: page.gradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -size.width * 0.18,
              right: -size.width * 0.22,
              child: _BlurOrb(
                size: size.width * 0.72,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            Positioned(
              bottom: size.height * 0.22,
              left: -size.width * 0.12,
              child: _BlurOrb(
                size: size.width * 0.56,
                color: page.orbColor,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 76),
                        _BrandHeader(),
                        SizedBox(
                          width: 76,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _completing ? null : _completeOnboarding,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF202124),
                                textStyle: AppTextStyles.titleSmall(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Skip'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (value) {
                          setState(() => _currentPage = value);
                        },
                        itemBuilder: (context, index) {
                          final item = _pages[index];
                          return _OnboardingPage(
                            data: item,
                            isActive: index == _currentPage,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _currentPage
                                  ? page.activeDotColor
                                  : Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _completing ? null : _handlePrimaryAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: page.buttonBackground,
                            foregroundColor: page.buttonForeground,
                            disabledBackgroundColor:
                                page.buttonBackground.withValues(alpha: 0.7),
                            disabledForegroundColor:
                                page.buttonForeground.withValues(alpha: 0.9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                            textStyle: AppTextStyles.titleLarge(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _completing
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      page.buttonForeground,
                                    ),
                                  ),
                                )
                              : Text(_isLastPage ? 'Get Started' : 'Next'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.isActive,
  });

  final _OnboardingPageData data;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageHeight = size.height * (size.height < 700 ? 0.26 : 0.34);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isActive ? 1 : 0.82,
      child: Column(
        children: [
          SizedBox(height: size.height * 0.04),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMedium(context).copyWith(
              fontSize: size.width < 360 ? 34 : 38,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF141414),
              height: 1.05,
            ),
          ),
          SizedBox(height: size.height * 0.035),
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: imageHeight,
                  maxWidth: size.width * 0.82,
                ),
                child: Image.asset(
                  data.imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: size.height * 0.03),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              data.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge(context).copyWith(
                fontSize: size.width < 360 ? 17 : 18,
                color: const Color(0xFF222327),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: size.height * 0.02),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF7BE0C3).withValues(alpha: 0.38),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF9FE6D9),
                ),
              ),
              const Icon(
                Icons.trending_up_rounded,
                size: 28,
                color: Color(0xFF1E2A2F),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SplitEasy',
          style: FlutterFontStyle.textStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF161616),
          ),
        ),
      ],
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.gradient,
    required this.orbColor,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.activeDotColor,
  });

  final String title;
  final String description;
  final String imagePath;
  final List<Color> gradient;
  final Color orbColor;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color activeDotColor;
}
