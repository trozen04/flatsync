import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/presentation/widgets/common_widgets.dart';

import '../../data/models/expense_model.dart';

/// Settlement screen showing who pays whom
/// Most important screen - displays minimal transaction settlements
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({Key? key}) : super(key: key);

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Settlement',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Shows who should pay whom with minimum transactions',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),

          // Settlements
          Consumer<BalanceProvider>(
            builder: (context, provider, _) {
              if (provider.settlements.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text('All settled! Everyone is even.'),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: provider.settlements.map((settlement) {
                  return SettlementItem(
                    from: settlement.from,
                    to: settlement.to,
                    amount: settlement.amount,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),

          // How it works
          ExpansionTile(
            title: Text(
              'How Settlement Works',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      context,
                      '1. Calculate Total',
                      'Sum of all expenses is divided equally among all 4 people',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      '2. Find Imbalances',
                      'Each person\'s balance = (what they paid) - (their share)',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      '3. Optimize Transfers',
                      'Match debtors with creditors to minimize number of transactions',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      '4. Settle',
                      'Each required transfer is shown above',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
