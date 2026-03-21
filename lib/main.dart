import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/services/isar_service.dart';
import 'package:flatsync/services/api_service.dart';
import 'package:flatsync/services/auth_service.dart';
import 'package:flatsync/services/contact_service.dart';
import 'package:flatsync/services/expense_service.dart';
import 'package:flatsync/bloc/contact_provider.dart';
import 'package:flatsync/screens/auth/login_screen.dart';
import 'package:flatsync/screens/shell/app_shell.dart';
import 'package:flatsync/constants/app_theme.dart';
import 'package:flatsync/routes/app_routes.dart';

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
      title: 'SplitEasy',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routes: AppRoutes.routes,
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

