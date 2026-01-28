import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/data/repositories/isar_service.dart';
import 'package:flatsync/src/data/repositories/expense_repository.dart';
import 'package:flatsync/src/services/sync/sync_service.dart';
import 'package:flatsync/src/services/background_service.dart';
import 'package:flatsync/src/services/notification_service.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/presentation/screens/app_shell.dart';
import 'package:flatsync/src/presentation/screens/user_setup_screen.dart';
import 'package:flatsync/src/core/theme/app_theme.dart';
import 'package:flatsync/src/core/user/user_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await IsarService.initialize();
  await UserProfile.initialize();
  
  // Initialize background service (before notification)
  await BackgroundService.initialize();
  await BackgroundService.start();
  
  // Defer notification initialization to avoid activity issues
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService.initialize();
    } catch (e) {
      developer.log('Failed to initialize notification service: $e');
    }
  });
  
  runApp(const FlatSyncApp());
}

class FlatSyncApp extends StatelessWidget {
  const FlatSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize repositories and services
    final isarService = IsarService();
    final expenseRepository = ExpenseRepository(isarService);

    return MultiProvider(
      providers: [
        // Services
        Provider(create: (_) => SyncService(expenseRepository)),

        // Repositories
        Provider<ExpenseRepository>(create: (_) => expenseRepository),

        // State providers
        ChangeNotifierProvider(
          create: (_) => ExpenseProvider(expenseRepository),
        ),
        ChangeNotifierProxyProvider<ExpenseProvider, BalanceProvider>(
          create: (context) => BalanceProvider(context.read<ExpenseProvider>()),
          update: (context, expenseProvider, previous) =>
              previous ?? BalanceProvider(expenseProvider),
        ),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: MaterialApp(
        title: 'FlatSync',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    if (UserProfile.isSetupComplete) {
      return const AppShell();
    } else {
      return UserSetupScreen();
    }
  }
}
