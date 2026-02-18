import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/app_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../data/repositories/isar_service.dart';
import 'auth/login_screen.dart';
import 'add_expense_screen.dart';
import 'contacts_screen.dart';
import 'balances_screen.dart';
import 'history_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _refreshing = false;

  late final List<Widget> _screens = const [
    AddExpenseScreen(),
    ContactsScreen(),
    BalancesScreen(),
    HistoryScreen(),
  ];

  Future<void> _logout() async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?\nAll local data will be cleared.',
      icon: Icons.logout,
      iconColor: Colors.red.shade400,
      confirmText: 'Logout',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      // Clear Isar database
      final isar = context.read<IsarService>();
      await isar.isar.writeTxn(() async {
        await isar.isar.clear();
      });
      
      // Logout from auth service
      await context.read<AuthService>().logout();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _refreshCurrentData() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      final expenseService = context.read<ExpenseService>();
      final contactService = context.read<ContactService>();
      final isar = context.read<IsarService>();

      await expenseService.refreshAll();
      final balances = await expenseService.getBalances(forceRefresh: true);
      if (balances.isNotEmpty) {
        await contactService.autoSyncFromBalances(balances, isar);
        contactService.notifyUpdate();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Add Expense', 'Contacts', 'Balances', 'Your Expenses'];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(titles[_selectedIndex], style: AppTextStyles.headlineSmall(context).copyWith(color: Colors.white),),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _refreshing ? null : _refreshCurrentData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: AppShadows.navigation),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Add',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Balances',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
