import 'package:flatsync/constants/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_update/in_app_update.dart';

import '../auth/biometric_gate_screen.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/app_shell.dart';
import '../../services/auth_service.dart';
import '../../services/app_preferences_service.dart';
import '../../utils/image_assets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (_) {
      // Not on Play Store or check failed — ignore
    }
  }

  Future<void> _navigate() async {
    final authService = context.read<AuthService>();
    final preferences = context.read<AppPreferencesService>();
    final prefs = await SharedPreferences.getInstance();

    final isLoggedIn = await authService
        .isLoggedIn()
        .timeout(const Duration(seconds: 5), onTimeout: () => false);

    final hasSeenOnboarding = prefs.getBool(OnboardingScreen.seenKey) ?? false;

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      _checkForUpdate(),
    ]);

    if (!mounted) return;

    Widget destination;
    if (isLoggedIn) {
      destination = preferences.biometricEnabled
          ? const BiometricGateScreen()
          : const AppShell();
    } else if (hasSeenOnboarding) {
      destination = const LoginScreen();
    } else {
      destination = const OnboardingScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Image.asset(
            ImageAssets.appIcon,
            width: AppDimensions.width(context) * 0.5,
          ),
        ),
      ),
    );
  }
}
