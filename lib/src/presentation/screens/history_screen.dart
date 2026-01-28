import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/core/constants/app_constants.dart';
import 'package:flatsync/src/core/theme/app_colors.dart';
import 'package:flatsync/src/core/theme/app_text_styles.dart';
import 'package:flatsync/src/core/theme/app_spacing.dart';
import 'package:flatsync/src/core/widgets/app_card.dart';
import 'package:flatsync/src/core/widgets/app_input.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedUser;
  bool _showDeleted = true;
  List<String> _availableUsers = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Filters
          Container(
            padding: AppSpacing.screenPadding(context),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Filter by User',
                        hint: 'All Users',
                        value: _selectedUser,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Users'),
                          ),
                          ...AppConstants.users.map((user) => DropdownMenuItem<String>(
                            value: user,
                            child: Text(user),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedUser = value);
                        },
                      ),
                    ),
                    AppSpacing.horizontalSpace(context, AppSpacing.lg),
                    Column(
                      children: [
                        Text(
                          'Show Deleted',
                          style: AppTextStyles.labelMedium(context),
                        ),
                        AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
                        Switch(
                          value: _showDeleted,
                          onChanged: (value) {
                            setState(() => _showDeleted = value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // History List
          Expanded(
            child: Consumer<ExpenseProvider>(
              builder: (context, provider, _) {
                // Always use fixed 4 users for filtering
                final fixedUsers = AppConstants.users;
                
                // Filter expenses
                var filteredExpenses = provider.allExpenses.where((expense) {
                  // User filter - compare base usernames
                  if (_selectedUser != null) {
                    final baseUsername = AppConstants.getBaseUsername(expense.paidBy);
                    if (baseUsername != _selectedUser) {
                      return false;
                    }
                  }
                  
                  // Deleted filter
                  if (!_showDeleted && expense.isDeleted) {
                    return false;
                  }
                  
                  return true;
                }).toList();
                
                // Sort by date (newest first)
                filteredExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                
                if (filteredExpenses.isEmpty) {
                  return Center(
                    child: AppCard(
                      type: AppCardType.outlined,
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.xxxl)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: AppSpacing.responsive(context, 48),
                              color: AppColors.textTertiary,
                            ),
                            AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),
                            Text(
                              'No expenses found',
                              style: AppTextStyles.titleMedium(context).copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            AppSpacing.responsiveVerticalSpace(context, AppSpacing.sm),
                            Text(
                              'Try adjusting your filters',
                              style: AppTextStyles.bodyMedium(context),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                
                return ListView.separated(
                  padding: AppSpacing.screenPadding(context),
                  itemCount: filteredExpenses.length,
                  separatorBuilder: (context, index) => 
                      AppSpacing.responsiveVerticalSpace(context, AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final expense = filteredExpenses[index];
                    return _HistoryExpenseItem(expense: expense);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryExpenseItem extends StatelessWidget {
  final ExpenseModel expense;

  const _HistoryExpenseItem({required this.expense});

  @override
  Widget build(BuildContext context) {
    final amount = expense.amount / 100;
    
    return AppCard(
      type: AppCardType.outlined,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: expense.isDeleted ? BoxDecoration(
          color: AppColors.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 12)),
        ) : null,
        child: AppListTile(
          leading: CircleAvatar(
            backgroundColor: expense.isDeleted 
                ? AppColors.error.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            child: expense.isDeleted 
                ? Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: AppSpacing.responsive(context, 20),
                  )
                : Text(
                    expense.paidBy[0].toUpperCase(),
                    style: AppTextStyles.labelLarge(context).copyWith(
                      color: AppColors.primary,
                    ),
                  ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${expense.paidBy} paid ₹${amount.toStringAsFixed(2)}',
                  style: AppTextStyles.titleSmall(context).copyWith(
                    decoration: expense.isDeleted ? TextDecoration.lineThrough : null,
                    color: expense.isDeleted ? AppColors.textTertiary : null,
                  ),
                ),
              ),
              if (expense.isDeleted)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.responsive(context, AppSpacing.sm),
                    vertical: AppSpacing.responsive(context, AppSpacing.xs),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 4)),
                  ),
                  child: Text(
                    'DELETED',
                    style: AppTextStyles.labelSmall(context).copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expense.description != null && expense.description!.isNotEmpty) ...[
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
                Text(
                  expense.description!,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    decoration: expense.isDeleted ? TextDecoration.lineThrough : null,
                    color: expense.isDeleted ? AppColors.textTertiary : null,
                  ),
                ),
              ],
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
              Text(
                'Created: ${_formatDate(expense.createdAt)}',
                style: AppTextStyles.bodySmall(context),
              ),
              if (expense.isDeleted && expense.deletedAt != null)
                Text(
                  'Deleted: ${_formatDate(expense.deletedAt!)}',
                  style: AppTextStyles.bodySmall(context).copyWith(
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}