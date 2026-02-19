import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/data/repositories/isar_service.dart';
import 'package:flatsync/src/services/api_service.dart';
import 'package:flatsync/src/services/auth_service.dart';
import 'package:flatsync/src/services/contact_service.dart';
import 'package:flatsync/src/services/expense_service.dart';
import 'package:flatsync/src/presentation/state/contact_provider.dart';
import 'package:flatsync/src/presentation/screens/auth/login_screen.dart';
import 'package:flatsync/src/presentation/screens/contact_selection_screen.dart';
import 'package:flatsync/src/presentation/screens/app_shell.dart';
import 'package:flatsync/src/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final isarService = IsarService();
  await isarService.openDB();
  
  final apiService = ApiService();
  final authService = AuthService(apiService);
  final contactService = ContactService(apiService);
  final expenseService = ExpenseService(apiService, isarService);

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
        ChangeNotifierProvider(
          create: (_) => ContactProvider(isarService, contactService),
        ),
      ],
      child: const FlatSyncApp(),
    ),
  );
}

class FlatSyncApp extends StatelessWidget {
  const FlatSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slice',
      theme: AppTheme.lightTheme,
      routes: {
        '/contact-selection': (context) => const ContactSelectionScreen(),
      },
      home: FutureBuilder<bool>(
        future: context.read<AuthService>().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == true
              ? const AppShell()
              : const LoginScreen();
        },
      ),
    );
  }
}
