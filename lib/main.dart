import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flatsync/services/isar_service.dart';
import 'package:flatsync/services/api_service.dart';
import 'package:flatsync/services/auth_service.dart';
import 'package:flatsync/services/contact_service.dart';
import 'package:flatsync/services/expense_service.dart';
import 'package:flatsync/services/notification_service.dart';
import 'package:flatsync/bloc/contact_provider.dart';
import 'package:flatsync/screens/auth/login_screen.dart';
import 'package:flatsync/screens/onboarding/onboarding_screen.dart';
import 'package:flatsync/screens/shell/app_shell.dart';
import 'package:flatsync/constants/app_theme.dart';
import 'package:flatsync/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final isarService = IsarService();
  await isarService.openDB();

  final apiService = ApiService();
  final authService = AuthService(apiService);
  final contactService = ContactService(apiService);
  final expenseService = ExpenseService(apiService, isarService);
  final notificationService = NotificationService(apiService);

  // Silent server wake-up
  apiService.wakeUpServer();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: isarService),
        Provider.value(value: apiService),
        Provider.value(value: authService),
        Provider.value(value: contactService),
        Provider.value(value: expenseService),
        Provider.value(value: notificationService),
        ChangeNotifierProvider(
          create: (_) => ContactProvider(isarService, contactService),
        ),
      ],
      child: const FlatSyncApp(),
    ),
  );
}

class FlatSyncApp extends StatefulWidget {
  const FlatSyncApp({super.key});

  @override
  State<FlatSyncApp> createState() => _FlatSyncAppState();
}

class _FlatSyncAppState extends State<FlatSyncApp> {
  late final Future<_LaunchDestination> _launchDestinationFuture;

  @override
  void initState() {
    super.initState();
    _launchDestinationFuture = _resolveLaunchDestination();
  }

  Future<_LaunchDestination> _resolveLaunchDestination() async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();

    final isLoggedIn = await authService.isLoggedIn();
    final hasSeenOnboarding =
        prefs.getBool(OnboardingScreen.seenKey) ?? false;

    return _LaunchDestination(
      isLoggedIn: isLoggedIn,
      hasSeenOnboarding: hasSeenOnboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitEasy',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routes: AppRoutes.routes,
      home: FutureBuilder<_LaunchDestination>(
        future: _launchDestinationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final launch = snapshot.data;
          if (launch?.isLoggedIn == true) {
            return const AppShell();
          }
          if (launch?.hasSeenOnboarding == true) {
            return const LoginScreen();
          }
          return const OnboardingScreen();
        },
      ),
    );
  }
}

class _LaunchDestination {
  const _LaunchDestination({
    required this.isLoggedIn,
    required this.hasSeenOnboarding,
  });

  final bool isLoggedIn;
  final bool hasSeenOnboarding;
}

