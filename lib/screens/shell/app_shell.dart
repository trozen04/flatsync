import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_shell_navigation.dart';
import '../../widgets/shadowed_app_bar.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../contacts/contacts_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/balances_screen.dart';
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
  final Set<int> _loadedTabIndexes = <int>{0};

  // 0 = Add, 1 = Contacts, 2 = Balances, 3 = History, 4 = Profile
  final List<Widget?> _screens = List<Widget?>.filled(5, null, growable: false);

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
    _loadedTabIndexes
      ..clear()
      ..add(0);
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _selectedIndex = index;
      _loadedTabIndexes.add(index);
    });
  }

  Widget _screenFor(int index) {
    return _screens[index] ??= switch (index) {
      0 => const AddExpenseScreen(),
      1 => const ContactsScreen(),
      2 => BalancesScreen(onNavigateToAddExpense: () => _selectTab(0)),
      3 => HistoryScreen(onNavigateToAddExpense: () => _selectTab(0)),
      _ => const ProfileScreen(showAppBar: false),
    };
  }

  Future<void> _logout() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?\nAll local data will be cleared.',
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
    final titles = [
      'Add Expense',
      'Contacts',
      'Balances',
      'History',
      'Profile'
    ];
    final navReserved = AppShellNavigation.barHeight +
        MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        appBar: ShadowedAppBar(
          child: AppBar(
            elevation: 8,
            scrolledUnderElevation: 0,
            title: Text(
              titles[_selectedIndex],
              style: AppTextStyles.headlineSmall(context)
                  .copyWith(color: Colors.white),
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
          child: Stack(
            children: [
              for (var index = 0; index < _screens.length; index++)
                if (_loadedTabIndexes.contains(index))
                  Offstage(
                    offstage: _selectedIndex != index,
                    child: TickerMode(
                      enabled: _selectedIndex == index,
                      child: _screenFor(index),
                    ),
                  ),
            ],
          ),
        ),
        bottomNavigationBar: AppShellNavigation(
          selectedIndex: _selectedIndex,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}
