import 'dart:developer' as developer;

import 'package:flatsync/src/presentation/screens/user_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/services/sync/sync_service.dart';
import 'package:flatsync/src/services/sync/background_sync_manager.dart';
import 'package:flatsync/src/services/background_service.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/presentation/screens/home_screen.dart';
import 'package:flatsync/src/presentation/screens/balance_screen.dart';
import 'package:flatsync/src/presentation/screens/settlement_screen.dart';
import 'package:flatsync/src/presentation/screens/export_screen.dart';
import 'package:flatsync/src/presentation/screens/history_screen.dart';
import 'package:flatsync/src/core/theme/app_colors.dart';
import 'package:flatsync/src/core/theme/app_text_styles.dart';
import 'package:flatsync/src/core/theme/app_spacing.dart';
import 'package:flatsync/src/core/user/user_profile.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    // Notify service that app is in foreground
    BackgroundService.notifyAppState(true);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Notify background service about app state
    final isInForeground = state == AppLifecycleState.resumed;
    BackgroundService.notifyAppState(isInForeground);
  }

  Future<void> _initializeApp() async {
    try {
      developer.log('🔧 Starting app initialization...');
      
      // Initialize sync service
      final syncService = context.read<SyncService>();
      developer.log('📡 Initializing sync service...');
      await syncService.initialize();
      developer.log('✅ Sync service initialized');

      // Load initial expenses
      final expenseProvider = context.read<ExpenseProvider>();
      expenseProvider.setDeviceId(syncService.deviceId);
      developer.log('📂 Loading expenses from Isar...');
      await expenseProvider.loadExpenses();
      developer.log('✅ Expenses loaded: ${expenseProvider.expenses.length}');

      // Start sync server
      developer.log('🚀 Starting sync server...');
      await syncService.startSyncServer();
      developer.log('✅ Sync server started');
      
      // Initialize background sync manager
      developer.log('⏰ Initializing background sync manager...');
      await BackgroundSyncManager.instance.initialize(syncService);
      developer.log('✅ Background sync manager initialized');

      // Set initial sync time
      context.read<SyncProvider>().setLastSyncTime(DateTime.now());
      developer.log('✅ App initialization complete!');
    } catch (e, stackTrace) {
      developer.log('❌ Error initializing app: $e');
      developer.log('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> performSync() async {
    final syncProvider = context.read<SyncProvider>();
    final syncService = context.read<SyncService>();
    final expenseProvider = context.read<ExpenseProvider>();

    try {
      syncProvider.setSyncing(true);
      syncProvider.setSyncStatus('Checking WiFi connection...');

      // Small delay to show the status
      await Future.delayed(const Duration(milliseconds: 500));
      
      syncProvider.setSyncStatus('Discovering peers on network...');
      
      // Perform sync
      await syncService.performFullSync();

      syncProvider.setSyncStatus('Updating local data...');
      
      // Reload expenses after sync
      await expenseProvider.loadExpenses();

      syncProvider.setLastSyncTime(DateTime.now());
      syncProvider.setSyncStatus('Sync completed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync completed successfully',
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Clear status after a delay
      await Future.delayed(const Duration(seconds: 2));
      syncProvider.setSyncStatus(null);
    } catch (e) {
      syncProvider.setSyncStatus('Sync failed: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync error: $e',
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // Clear error status after a delay
      await Future.delayed(const Duration(seconds: 3));
      syncProvider.setSyncStatus(null);
    } finally {
      syncProvider.setSyncing(false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.only(top: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.all(16),

          title: Column(
            children: const [
              Icon(
                Icons.logout_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              SizedBox(height: 12),
              Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          content: const Text(
            'Are you sure you want to logout?\nAll user data will be cleared from this device.',
            textAlign: TextAlign.center,
          ),

          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await UserProfile.clearAllData();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserSetupScreen()),
            (route) => false,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    const screens = [
      HomeScreen(),
      BalanceScreen(),
      SettlementScreen(),
      HistoryScreen(),
      ExportScreen(),
    ];

    const screenTitles = [
      'Slice',
      'Balances',
      'Settlement',
      'History',
      'Export',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          screenTitles[_selectedIndex],
          style: AppTextStyles.titleLarge(context).copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: AppColors.surface,
        height: AppSpacing.responsive(context, 80),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Balances',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Settlement',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Export',
          ),
        ],
      ),
    );
  }
}
