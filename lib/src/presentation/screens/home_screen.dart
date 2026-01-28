import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/presentation/widgets/common_widgets.dart';
import 'package:flatsync/src/core/theme/app_colors.dart';
import 'package:flatsync/src/core/theme/app_text_styles.dart';
import 'package:flatsync/src/core/theme/app_spacing.dart';
import 'package:flatsync/src/core/widgets/app_button.dart';
import 'package:flatsync/src/core/widgets/app_card.dart';
import 'package:flatsync/src/core/widgets/app_input.dart';
import 'package:flatsync/src/core/user/user_profile.dart';
import 'package:flatsync/src/core/constants/app_constants.dart';
import 'package:flatsync/src/utils/custom_snackbar.dart';
import 'package:flatsync/src/services/background_service.dart';

import '../../services/sync/sync_service.dart';

/// Home screen for adding expenses
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAddingExpense = false;
  String? _selectedUser;

  @override
  void initState() {
    super.initState();
    // Set initial selected user from current user (extract base name without device)
    final currentUserFull = UserProfile.currentUserName;
    if (currentUserFull != null) {
      _selectedUser = AppConstants.getBaseUsername(currentUserFull);
    }
    // Notify background service that app is in foreground
    BackgroundService.notifyAppState(true);

    // Periodically refresh expenses to sync with background updates
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<ExpenseProvider>().loadExpenses();
        _startPeriodicRefresh();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addExpense() async {
    final currentUser = UserProfile.currentUserName;
    if (currentUser == null || _amountController.text.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Please enter amount',
        isError: true,
      );
      return;
    }

    try {
      setState(() => _isAddingExpense = true);

      // Convert rupees to paise (multiply by 100)
      final amount = (double.parse(_amountController.text) * 100).toInt();

      await context.read<ExpenseProvider>().addExpense(
            amount: amount,
            paidBy: currentUser,
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );

      // Clear inputs
      setState(() {
        _amountController.clear();
        _descriptionController.clear();
      });

      CustomSnackBar.show(
        context,
        message: 'Expense added successfully',
      );
      FocusScope.of(context).unfocus();
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: 'Error: $e',
        isError: true,
      );
    } finally {
      setState(() => _isAddingExpense = false);
    }
  }

  void _performSync() async {
    // Access the sync functionality from providers
    final syncProvider = context.read<SyncProvider>();
    final syncService = context.read<SyncService>();
    final expenseProvider = context.read<ExpenseProvider>();

    if (syncProvider.isSyncing) return;

    try {
      syncProvider.setSyncing(true);
      syncProvider.setSyncStatus('Checking WiFi connection...');

      await Future.delayed(const Duration(milliseconds: 500));
      
      syncProvider.setSyncStatus('Discovering peers on network...');
      
      await syncService.performFullSync();

      syncProvider.setSyncStatus('Updating local data...');
      
      await expenseProvider.loadExpenses();

      syncProvider.setLastSyncTime(DateTime.now());
      syncProvider.setSyncStatus('Sync completed successfully');

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Sync completed successfully',
        );
      }
      
      await Future.delayed(const Duration(seconds: 2));
      syncProvider.setSyncStatus(null);
    } catch (e) {
      syncProvider.setSyncStatus('Sync failed: ${e.toString()}');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Sync error: $e',
          isError: true,
        );
      }
      
      await Future.delayed(const Duration(seconds: 3));
      syncProvider.setSyncStatus(null);
    } finally {
      syncProvider.setSyncing(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _performSync();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding(context),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sync Status Card
              Consumer<SyncProvider>(
                builder: (context, syncProvider, _) {
                  return AppCard(
                    type: AppCardType.filled,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.sm)),
                          decoration: BoxDecoration(
                            color: syncProvider.isSyncing
                                ? AppColors.info.withOpacity(0.2)
                                : AppColors.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.responsive(context, 8),
                            ),
                          ),
                          child: Icon(
                            syncProvider.isSyncing ? Icons.sync : Icons.wifi,
                            color: syncProvider.isSyncing ? AppColors.info : AppColors.success,
                            size: AppSpacing.responsive(context, 20),
                          ),
                        ),
                        AppSpacing.horizontalSpace(context, AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WiFi Sync',
                                style: AppTextStyles.titleSmall(context),
                              ),
                              AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
                              Text(
                                syncProvider.isSyncing
                                    ? (syncProvider.syncStatus ?? 'Syncing...')
                                    : 'Ready to sync with nearby devices',
                                style: AppTextStyles.bodySmall(context),
                              ),
                            ],
                          ),
                        ),
                        if (!syncProvider.isSyncing)
                          AppIconButton(
                            icon: Icons.sync,
                            type: AppButtonType.outline,
                            size: AppButtonSize.small,
                            onPressed: _performSync,
                            tooltip: 'Sync with nearby devices',
                          ),
                        if (syncProvider.isSyncing)
                          SizedBox(
                            width: AppSpacing.responsive(context, 24),
                            height: AppSpacing.responsive(context, 24),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),

              // Header
              Text(
                'Add Expense',
                style: AppTextStyles.headlineSmall(context),
              ),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.sm),

              // Current User Display
              AppCard(
                type: AppCardType.outlined,
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: AppSpacing.responsive(context, 20),
                    ),
                    AppSpacing.horizontalSpace(context, AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paid by:',
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
                          Text(
                            AppConstants.getBaseUsername(UserProfile.currentUserName ?? 'Unknown User'),
                            style: AppTextStyles.titleMedium(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AmountInput(controller: _amountController),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),

              // Description input
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Enter expense description (optional)',
                maxLines: 2,
                maxLength: 60,
              ),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.xxl),

              // Add button
              AppButton(
                text: 'Add Expense',
                icon: Icons.add,
                onPressed: _addExpense,
                isLoading: _isAddingExpense,
                type: AppButtonType.primary,
                size: AppButtonSize.large,
                fullWidth: true,
              ),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.xxxl),

              // Total amount
              Consumer<ExpenseProvider>(
                builder: (context, provider, _) {
                  final total = provider.getTotalAmount() / 100;
                  return AppCard(
                    type: AppCardType.elevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: AppTextStyles.titleSmall(context),
                        ),
                        AppSpacing.responsiveVerticalSpace(context, AppSpacing.sm),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: AppTextStyles.currencyLarge(context).copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.xxl),

              // Expenses list
              Text(
                'Recent Expenses',
                style: AppTextStyles.titleMedium(context),
              ),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.md),
              Consumer<ExpenseProvider>(
                builder: (context, provider, _) {
                  if (provider.expenses.isEmpty) {
                     return AppCard(
                      type: AppCardType.outlined,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.responsive(context, AppSpacing.xxxl)),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: AppSpacing.responsive(context, 48),
                              color: AppColors.textTertiary,
                            ),
                            AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),
                            Text(
                              'No expenses yet',
                              style: AppTextStyles.titleMedium(context).copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            AppSpacing.responsiveVerticalSpace(context, AppSpacing.sm),
                            Text(
                              'Add your first expense to get started!',
                              style: AppTextStyles.bodyMedium(context),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: provider.expenses.length > 10 ? 10 : provider.expenses.length,
                   separatorBuilder: (context, index) =>
                       AppSpacing.responsiveVerticalSpace(context, AppSpacing.sm),
                   itemBuilder: (context, index) {
                     final expense = provider.expenses[provider.expenses.length - 1 - index];
                     return ExpenseListItem(
                       expense: expense,
                       onDelete: () async {
                         await provider.deleteExpense(expense.uuid);
                         if (mounted) {
                           CustomSnackBar.show(
                             context,
                             message: 'Expense deleted',
                           );
                         }
                       },
                     );
                   },
                 );
                },
              ),
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.huge),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
