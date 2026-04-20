import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/isar_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_button.dart';
import '../shell/app_shell.dart';
import 'login_screen.dart';

class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  bool _authenticating = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (!mounted) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });

    final biometric = context.read<BiometricAuthService>();
    final preferences = context.read<AppPreferencesService>();
    final available = await biometric.isAvailable();

    if (!available) {
      await preferences.setBiometricEnabled(false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
      return;
    }

    final ok = await biometric.authenticate(
      reason: 'Authenticate to open SettleFlow',
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
      return;
    }

    setState(() {
      _authenticating = false;
      _message = 'Biometric verification was not completed.';
    });
  }

  Future<void> _logout() async {
    final isar = context.read<IsarService>();
    final expenseService = context.read<ExpenseService>();
    final notificationService = context.read<NotificationService>();
    final preferences = context.read<AppPreferencesService>();
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    expenseService.clearAllCaches();
    await isar.clearUserData();
    await expenseService.clearPersistedCaches();
    await notificationService.unregisterDevice();
    await preferences.resetForLogout();
    await auth.logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppDimensions.appMargin(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 72),
              AppDimensions.h20(context),
              Text(
                'Unlock SettleFlow',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              AppDimensions.h10(context),
              Text(
                _authenticating
                    ? 'Waiting for biometric verification...'
                    : (_message ?? 'Authenticate to continue.'),
                textAlign: TextAlign.center,
              ),
              AppDimensions.h30(context),
              CustomButton(
                text: 'Try Again',
                onPressed: _authenticating ? null : _authenticate,
                isLoading: _authenticating,
              ),
              AppDimensions.h10(context),
              TextButton(
                onPressed: _authenticating ? null : _logout,
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
