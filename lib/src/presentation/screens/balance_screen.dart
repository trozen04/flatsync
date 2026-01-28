import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/presentation/widgets/common_widgets.dart';
import 'package:flatsync/src/core/constants/app_constants.dart';
import 'package:flatsync/src/core/theme/app_colors.dart';
import 'package:flatsync/src/core/theme/app_text_styles.dart';
import 'package:flatsync/src/core/theme/app_spacing.dart';
import 'package:flatsync/src/domain/entities/settlement_entity.dart';

import '../../data/models/expense_model.dart';

/// Balance screen showing per-user balances
class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Balances',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Show who paid what and how much each person owes or receives',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),

          // Balances list
          Consumer<BalanceProvider>(
            builder: (context, provider, _) {
              // Show all 4 users, even if no expenses
              final balances = provider.balances.isNotEmpty 
                ? provider.balances 
                : AppConstants.users.map((user) => UserBalance(
                    user: user,
                    totalPaid: 0,
                    perPersonShare: 0,
                    netBalance: 0,
                  )).toList();

              return Column(
                children: balances.map((balance) {
                  return BalanceCard(
                    userName: balance.user,
                    totalPaid: balance.totalPaid,
                    netBalance: balance.netBalance,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),

          // Summary
          Consumer<BalanceProvider>(
            builder: (context, provider, _) {
              if (provider.balances.isEmpty) {
                return const SizedBox.shrink();
              }

              // Calculate totals
              int totalPaid = 0;
              int totalPerShare = 0;

              for (final balance in provider.balances) {
                totalPaid += balance.totalPaid;
                totalPerShare += balance.perPersonShare;
              }

              final totalExpense = totalPaid / 100;
              final perShare = totalPerShare / 100 / 4;

              return Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Expenses:'),
                          Text(
                            '₹${totalExpense.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Per Person Share:'),
                          Text(
                            '₹${perShare.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
