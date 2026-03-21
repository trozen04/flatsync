import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_shadows.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/shadowed_app_bar.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../auth/login_screen.dart';
import '../contacts/contacts_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/balances_screen.dart';
import '../expenses/history_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _refreshing = false;

  // 0 = Add, 1 = Contacts, 2 = Balances, 3 = History, 4 = Profile
  late final List<Widget?> _screens = List<Widget?>.filled(5, null, growable: false);

  Widget _screenFor(int index) {
    return _screens[index] ??= switch (index) {
      0 => const AddExpenseScreen(),
      1 => const ContactsScreen(),
      2 => BalancesScreen(onNavigateToAddExpense: () => setState(() => _selectedIndex = 0)),
      3 => const HistoryScreen(),
      _ => const ProfileScreen(showAppBar: false),
    };
  }

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
        final contacts = expenseService.getCachedBalanceContacts();
        if (contacts.isNotEmpty) {
          await contactService.upsertContactsByCanonical(isar, contacts);
          contactService.notifyUpdate();
        }
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Add Expense', 'Contacts', 'Balances', 'Your History', 'Profile'];
    final scheme = Theme.of(context).colorScheme;
    final navReserved = 92.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      appBar: ShadowedAppBar(
        child: AppBar(
          elevation: 8,
          scrolledUnderElevation: 0,
          title: Text(
            titles[_selectedIndex],
            style: AppTextStyles.headlineSmall(context).copyWith(color: Colors.white),
          ),
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
      ),
      body: Padding(
        // Screens inside AppShell are full Scaffolds; reserve space so their content
        // doesn't render behind the custom bottom bar.
        padding: EdgeInsets.only(bottom: navReserved),
        child: IndexedStack(
          index: _selectedIndex,
          children: List.generate(5, _screenFor),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: AppShadows.navigation),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 92,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 66,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant.withOpacity(0.65)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _BottomNavItem(
                            label: 'Contacts',
                            icon: Icons.people_outline,
                            selectedIcon: Icons.people,
                            selected: _selectedIndex == 1,
                            onTap: () => setState(() => _selectedIndex = 1),
                          ),
                        ),
                        Expanded(
                          child: _BottomNavItem(
                            label: 'Balances',
                            icon: Icons.account_balance_wallet_outlined,
                            selectedIcon: Icons.account_balance_wallet,
                            selected: _selectedIndex == 2,
                            onTap: () => setState(() => _selectedIndex = 2),
                          ),
                        ),
                        const SizedBox(width: 70), // space for center add button
                        Expanded(
                          child: _BottomNavItem(
                            label: 'History',
                            icon: Icons.history,
                            selectedIcon: Icons.history,
                            selected: _selectedIndex == 3,
                            onTap: () => setState(() => _selectedIndex = 3),
                          ),
                        ),
                        Expanded(
                          child: _BottomNavItem(
                            label: 'Profile',
                            icon: Icons.person_outline,
                            selectedIcon: Icons.person,
                            selected: _selectedIndex == 4,
                            onTap: () => setState(() => _selectedIndex = 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 22,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: FloatingActionButton(
                      heroTag: 'add_expense_fab',
                      elevation: 6,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      onPressed: () => setState(() => _selectedIndex = 0),
                      child: const Icon(Icons.add, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

