import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_dimensions.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell_navigation.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../contacts/contacts_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/history_screen.dart';
import '../profile/profile_screen.dart';
import 'package:in_app_update/in_app_update.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _refreshing = false;

  // 0 = Contacts, 1 = History, 2 = Profile, 3 = Add.
  final List<Widget?> _screens = List<Widget?>.filled(4, null, growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (_) {}
  }

  void _resetScreenCache() {
    for (var i = 0; i < _screens.length; i++) {
      _screens[i] = null;
    }
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _screenFor(int index) {
    return _screens[index] ??= switch (index) {
      0 => const ContactsScreen(),
      1 => HistoryScreen(onNavigateToAddExpense: _openAddExpense),
      2 => const ProfileScreen(showAppBar: false),
      _ => const AddExpenseScreen(),
    };
  }

  void _openAddExpense() {
    _selectTab(3);
  }

  Future<void> _logout() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Logout',
      message:
          'Are you sure you want to logout?\nAll local data will be cleared.',
      icon: Icons.logout_rounded,
      variant: DialogVariant.danger,
      confirmLabel: 'Logout',
    );

    if (confirmed == true && mounted) {
      ContactsScreen.resetPersistedState();
      setState(() {
        _selectedIndex = 0;
        _resetScreenCache();
      });

      // Clear Isar database
      final isar = context.read<IsarService>();
      await isar.isar.writeTxn(() async {
        await isar.isar.clear();
      });

      // Logout from auth service
      await context.read<NotificationService>().unregisterDevice();
      await context.read<AppPreferencesService>().resetForLogout();
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
    final titles = ['Contacts', 'History', 'Profile', 'Add Expense'];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: GradientAppBar(
          title: titles[_selectedIndex],
          actions: [
            IconButton(
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, color: Colors.white),
              onPressed: _refreshing ? null : _refreshCurrentData,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: _logout,
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            for (var index = 0; index < _screens.length; index++)
              TickerMode(
                enabled: _selectedIndex == index,
                child: _screenFor(index),
              ),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: AppShellNavigation(
          selectedIndex: _selectedIndex,
          onSelected: _selectTab,
          onAddPressed: _openAddExpense,
        ),
      ),
    );
  }
}
