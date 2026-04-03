import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flatsync/bloc/contact_provider.dart';
import 'package:flatsync/constants/app_colors.dart';
import 'package:flatsync/constants/app_currencies.dart';
import 'package:flatsync/constants/app_spacing.dart';
import 'package:flatsync/constants/app_text_styles.dart';
import 'package:flatsync/services/app_preferences_service.dart';
import 'package:flatsync/utils/date_utils.dart';
import 'package:flatsync/utils/money_utils.dart';
import 'package:flatsync/widgets/app_card.dart';
import 'package:flatsync/widgets/app_input.dart';

/// User dropdown widget for selecting who paid
class UserDropdown extends StatefulWidget {
  final String? selectedUser;
  final Function(String) onChanged;
  final List<String> availableUsers;

  const UserDropdown({
    super.key,
    required this.selectedUser,
    required this.onChanged,
    required this.availableUsers,
  });

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

/// Input field for expense amount (in smallest currency unit)
class AmountInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const AmountInput({
    super.key,
    required this.controller,
    this.label = 'Amount',
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  @override
  Widget build(BuildContext context) {
    final currencyCode =
        context.watch<AppPreferencesService>().preferredCurrencyCode;
    final currency = AppCurrencies.byCode(currencyCode);

    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: 'Enter amount in ${currency.code}',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      maxLength: 5,
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = newValue.text;

          if (text.isEmpty) return newValue;
          if (!RegExp(r'^[0-9.]*$').hasMatch(text)) {
            return oldValue;
          }
          if ('.'.allMatches(text).length > 1) {
            return oldValue;
          }

          return newValue;
        }),
      ],
      prefixIcon: Padding(
        padding: EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.md)),
        child: Text(
          currency.symbol.trim(),
          style: AppTextStyles.bodyLarge(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Balance card widget showing per-user balance
class BalanceCard extends StatelessWidget {
  final String userName;
  final int totalPaid;
  final int netBalance;

  const BalanceCard({
    super.key,
    required this.userName,
    required this.totalPaid,
    required this.netBalance,
  });

  @override
  Widget build(BuildContext context) {
    final currencyCode =
        context.watch<AppPreferencesService>().preferredCurrencyCode;
    final balanceColor = netBalance > 0
        ? AppColors.success
        : (netBalance < 0 ? AppColors.error : AppColors.textSecondary);
    final isPositive = netBalance >= 0;
    final contactProvider = context.watch<ContactProvider>();
    final displayName = contactProvider.getDisplayName(userName);

    return AppCard(
      type: AppCardType.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  displayName[0].toUpperCase(),
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              AppSpacing.horizontalSpace(context, AppSpacing.md),
              Expanded(
                child: Text(
                  displayName,
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
                    formatMinorUnits(totalPaid, currencyCode: currencyCode),
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
                    formatMinorUnits(
                      netBalance,
                      currencyCode: currencyCode,
                      absolute: true,
                    ),
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
    super.key,
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyCode =
        context.watch<AppPreferencesService>().preferredCurrencyCode;
    final contactProvider = context.watch<ContactProvider>();
    final fromName = contactProvider.getDisplayName(from);
    final toName = contactProvider.getDisplayName(to);

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
                    fromName,
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
                const Icon(Icons.arrow_forward, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(
                  formatMinorUnits(amount, currencyCode: currencyCode),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.success,
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
                    toName,
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
    super.key,
    required this.isSyncing,
    required this.lastSyncTime,
    required this.onSyncPressed,
  });

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
              color: lastSyncTime != null ? AppColors.success : AppColors.textTertiary,
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
              icon: const Icon(
                Icons.sync,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Sync Now',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return AppDateUtils.formatRelativeTime(time);
  }
}
