import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/domain/entities/settlement_entity.dart';
import 'package:flatsync/src/core/theme/app_colors.dart';
import 'package:flatsync/src/core/theme/app_text_styles.dart';
import 'package:flatsync/src/core/theme/app_spacing.dart';
import 'package:flatsync/src/core/widgets/app_button.dart';
import 'package:flatsync/src/core/widgets/app_card.dart';
import 'package:flatsync/src/core/widgets/app_input.dart';
import 'package:flatsync/src/core/user/user_profile.dart';
import 'package:flatsync/src/core/constants/app_constants.dart';

/// User dropdown widget for selecting who paid
class UserDropdown extends StatefulWidget {
  final String? selectedUser;
  final Function(String) onChanged;
  final List<String> availableUsers;

  const UserDropdown({
    Key? key,
    required this.selectedUser,
    required this.onChanged,
    required this.availableUsers,
  }) : super(key: key);

  @override
  State<UserDropdown> createState() => _UserDropdownState();
}

class _UserDropdownState extends State<UserDropdown> {
  @override
  Widget build(BuildContext context) {
    return AppDropdownField<String>(
      label: 'Who paid?',
      hint: 'Select user',
      value: widget.selectedUser,
      items: widget.availableUsers.map((String user) {
        return DropdownMenuItem<String>(
          value: user,
          child: Text(
            user,
            style: AppTextStyles.bodyLarge(context),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          widget.onChanged(newValue);
        }
      },
    );
  }
}

/// Input field for expense amount (in paise, smallest currency unit)
class AmountInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const AmountInput({
    Key? key,
    required this.controller,
    this.label = 'Amount',
  }) : super(key: key);

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: 'Enter amount in rupees',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      maxLength: 5,
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = newValue.text;

          // allow empty
          if (text.isEmpty) return newValue;

          // allow only digits and dot
          if (!RegExp(r'^[0-9.]*$').hasMatch(text)) {
            return oldValue;
          }

          // allow only ONE dot
          if ('.'.allMatches(text).length > 1) {
            return oldValue;
          }

          return newValue;
        }),
      ],
      prefixIcon: Padding(
        padding: EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.md)),
        child: Text(
          '₹',
          style: AppTextStyles.bodyLarge(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Expense list item widget
class ExpenseListItem extends StatelessWidget {
  final ExpenseModel expense;
  final Function()? onDelete;

  const ExpenseListItem({
    Key? key,
    required this.expense,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final amount = expense.amount / 100;
    
    return AppCard(
      type: AppCardType.outlined,
      padding: EdgeInsets.zero,
      child: AppListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            expense.paidBy[0].toUpperCase(),
            style: AppTextStyles.labelLarge(context).copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(
          '${expense.paidBy} paid ₹${amount.toStringAsFixed(2)}',
          style: AppTextStyles.titleSmall(context),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expense.description != null && expense.description!.isNotEmpty) ...[
              AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
              Text(
                expense.description!,
                style: AppTextStyles.bodyMedium(context),
              ),
            ],
            AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
            Text(
              'Created: ${_formatDate(expense.createdAt)}',
              style: AppTextStyles.bodySmall(context),
            ),
          ],
        ),
        trailing: AppIconButton(
          icon: Icons.more_vert,
          type: AppButtonType.text,
          size: AppButtonSize.small,
          onPressed: () => _showOptionsMenu(context),
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    // Check if current user is the one who added this expense
    final currentUser = UserProfile.currentUserName;
    final expenseUser = expense.paidBy;
    final baseCurrentUser = AppConstants.getBaseUsername(currentUser ?? '');
    final baseExpenseUser = AppConstants.getBaseUsername(expenseUser);
    final canDelete = baseCurrentUser == baseExpenseUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.responsive(context, 16)),
        ),
      ),
      builder: (context) => Container(
        padding: AppSpacing.screenPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpacing.responsive(context, 40),
              height: AppSpacing.responsive(context, 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),
            if (canDelete)
              AppButton(
                text: 'Delete Expense',
                icon: Icons.delete_outline,
                onPressed: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
                type: AppButtonType.danger,
                fullWidth: true,
              )
            else
              Text(
                'Only $baseExpenseUser can delete this expense',
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: AppColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
            AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Balance card widget showing per-user balance
class BalanceCard extends StatelessWidget {
  final String userName;
  final int totalPaid;
  final int netBalance;

  const BalanceCard({
    Key? key,
    required this.userName,
    required this.totalPaid,
    required this.netBalance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final paid = totalPaid / 100;
    final balance = netBalance / 100;
    final balanceColor = netBalance > 0 
        ? AppColors.success 
        : (netBalance < 0 ? AppColors.error : AppColors.textSecondary);
    final isPositive = netBalance >= 0;

    return AppCard(
      type: AppCardType.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  userName[0].toUpperCase(),
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              AppSpacing.horizontalSpace(context, AppSpacing.md),
              Expanded(
                child: Text(
                  userName,
                  style: AppTextStyles.titleMedium(context),
                ),
              ),
            ],
          ),
          AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Paid',
                    style: AppTextStyles.bodySmall(context),
                  ),
                  AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
                  Text(
                    '₹${paid.toStringAsFixed(2)}',
                    style: AppTextStyles.currency(context),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPositive ? 'Gets Back' : 'Owes',
                    style: AppTextStyles.bodySmall(context),
                  ),
                  AppSpacing.responsiveVerticalSpace(context, AppSpacing.xs),
                  Text(
                    '₹${balance.abs().toStringAsFixed(2)}',
                    style: AppTextStyles.currency(context).copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settlement widget showing who pays whom
class SettlementItem extends StatelessWidget {
  final String from;
  final String to;
  final int amount;

  const SettlementItem({
    Key? key,
    required this.from,
    required this.to,
    required this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settleAmount = amount / 100;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    from,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'pays',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_forward, color: Colors.blue),
                const SizedBox(height: 4),
                Text(
                  '₹${settleAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    to,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync status indicator widget
class SyncStatusWidget extends StatelessWidget {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final VoidCallback onSyncPressed;

  const SyncStatusWidget({
    Key? key,
    required this.isSyncing,
    required this.lastSyncTime,
    required this.onSyncPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lastSyncText = lastSyncTime != null
        ? 'Last sync: ${_formatTime(lastSyncTime!)}'
        : 'Never synced';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.cloud_done,
              size: 16,
              color: lastSyncTime != null ? Colors.green : Colors.grey,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSyncing ? 'Syncing...' : 'Sync Status',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  lastSyncText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!isSyncing)
            ElevatedButton.icon(
              onPressed: onSyncPressed,
              icon: const Icon(Icons.sync, size: 16, color: Colors.white,),
              label: const Text('Sync Now', style: TextStyle(color: Colors.white),),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
