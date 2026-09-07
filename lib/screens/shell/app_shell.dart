import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_shell_navigation.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../constants/app_colors.dart';
import '../../services/app_preferences_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/network_error_handler.dart';
import '../contacts/contacts_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/history_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_inquiry_dialog.dart';
import 'package:in_app_update/in_app_update.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _refreshing = false;

  final GlobalKey<ContactsScreenState> _contactsScreenKey =
      GlobalKey<ContactsScreenState>();

  // 0 = Contacts, 1 = History, 2 = Profile, 3 = Add.
  final List<Widget?> _screens = List<Widget?>.filled(4, null, growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
      _showInquiryDialogOnce();
    });
  }

  void _showInquiryDialogOnce() {
    final preferences = context.read<AppPreferencesService>();
    if (preferences.appInquirySeen) return;

    // Mark as seen persistently so it is never shown again
    preferences.setAppInquirySeen(true);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        AppInquiryDialog.show(context);
      }
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {}
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _screenFor(int index) {
    return _screens[index] ??= switch (index) {
      0 => ContactsScreen(key: _contactsScreenKey),
      1 => HistoryScreen(onNavigateToAddExpense: _openAddExpense),
      2 => const ProfileScreen(showAppBar: false),
      _ => const AddExpenseScreen(),
    };
  }

  void _openAddExpense() {
    _selectTab(3);
  }

  Future<void> _refreshCurrentData() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      final expenseService = context.read<ExpenseService>();
      final contactService = context.read<ContactService>();
      final isar = context.read<IsarService>();

      final refreshResult = await expenseService.refreshAll();
      final balances = refreshResult.balances;
      if (balances.isNotEmpty) {
        final contacts = expenseService.getCachedBalanceContacts();
        if (contacts.isNotEmpty) {
          await contactService.upsertContactsByCanonical(isar, contacts);
          contactService.notifyUpdate();
        }
      }

      if (!mounted) return;
      if (refreshResult.hasFailures) {
        final message = refreshResult.allFailed
            ? 'Unable to reach the server. Showing cached data if available.'
            : 'Some sections could not refresh: ${refreshResult.failedSections.join(', ')}.';
        CustomSnackBar.show(
          context,
          message: message,
          isError: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: NetworkErrorHandler.message(
          error,
          fallback: 'Unable to refresh data right now.',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openBalanceOverview() {
    if (_contactsScreenKey.currentState != null) {
      _contactsScreenKey.currentState!.showBalanceSummary();
    } else {
      _selectTab(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contactsScreenKey.currentState?.showBalanceSummary();
      });
    }
  }

  void _openAddContact() {
    if (_contactsScreenKey.currentState != null) {
      _contactsScreenKey.currentState!.showAddContactSheet();
    } else {
      _selectTab(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contactsScreenKey.currentState?.showAddContactSheet();
      });
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
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(38, 38),
              ),
              icon: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Balance Overview',
              onPressed: _openBalanceOverview,
            ),
            const SizedBox(width: 4),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(38, 38),
              ),
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Add Contact',
              onPressed: _openAddContact,
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(38, 38),
                ),
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.sync_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                tooltip: 'Refresh',
                onPressed: _refreshing ? null : _refreshCurrentData,
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
                child: _selectedIndex == index || _screens[index] != null
                    ? _screenFor(index)
                    : const SizedBox.shrink(),
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
