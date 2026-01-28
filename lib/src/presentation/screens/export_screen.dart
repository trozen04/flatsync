import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flatsync/src/presentation/state/providers.dart';
import 'package:flatsync/src/utils/export_utils.dart';
import 'package:flatsync/src/utils/custom_snackbar.dart';

import '../../data/models/expense_model.dart';

/// Export screen for exporting expenses and settlements to CSV/JSON
class ExportScreen extends StatefulWidget {
  const ExportScreen({Key? key}) : super(key: key);

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isExporting = false;

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final balanceProvider = context.read<BalanceProvider>();

      // Create CSV for expenses
      final expensesCSV = _generateExpensesCSV(expenseProvider);
      final settlementsCSV = _generateSettlementsCSV(balanceProvider);

      // Get app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Write files
      final expensesFile = File('${dir.path}/flatsync_expenses_$timestamp.csv');
      final settlementsFile = File('${dir.path}/flatsync_settlements_$timestamp.csv');

      await expensesFile.writeAsString(expensesCSV);
      await settlementsFile.writeAsString(settlementsCSV);

      // Share files
      await Share.shareXFiles(
        [XFile(expensesFile.path), XFile(settlementsFile.path)],
        subject: 'Slice Expenses Export',
        text: 'Exported expenses and settlements from Slice',
      );

      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Exported to CSV successfully',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Error saving CSV: $e',
        isError: true,
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToJSON() async {
    setState(() => _isExporting = true);

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final balanceProvider = context.read<BalanceProvider>();

      final jsonData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'expenses': expenseProvider.expenses.map((e) => e.toJson()).toList(),
        'balances': balanceProvider.balances
            .map((b) => {
                  'user': b.user,
                  'totalPaid': b.totalPaid / 100,
                  'perShare': b.perPersonShare / 100,
                  'netBalance': b.netBalance / 100,
                })
            .toList(),
        'settlements': balanceProvider.settlements
            .map((s) => {
                  'from': s.from,
                  'to': s.to,
                  'amount': s.amount / 100,
                })
            .toList(),
      };

      // Get app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonFile = File('${dir.path}/flatsync_export_$timestamp.json');

      await jsonFile.writeAsString(jsonEncode(jsonData));

      // Share file
      await Share.shareXFiles(
        [XFile(jsonFile.path)],
        subject: 'Slice Export',
        text: 'Complete export from Slice app',
      );

      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Exported to JSON successfully',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Error saving JSON: $e',
        isError: true,
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToText() async {
    setState(() => _isExporting = true);

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final balanceProvider = context.read<BalanceProvider>();

      // Generate readable text export
      final textContent = CSVExporter.exportToReadableText(
        expenseProvider.expenses,
        balanceProvider.balances,
        balanceProvider.settlements,
      );

      // Get app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final textFile = File('${dir.path}/flatsync_report_$timestamp.txt');

      await textFile.writeAsString(textContent);

      // Share file
      await Share.shareXFiles(
        [XFile(textFile.path)],
        subject: 'Slice Expense Report',
        text: 'Expense report from Slice app',
      );

      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Exported to Text successfully',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Error saving Text: $e',
        isError: true,
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _generateExpensesCSV(ExpenseProvider provider) {
    final buffer = StringBuffer();
    buffer.writeln('Date,User,Amount,Description');

    for (final expense in provider.expenses) {
      final amount = expense.amount / 100;
      final description = expense.description ?? '';
      final date = expense.createdAt.toString();

      buffer.writeln('"$date","${expense.paidBy}","$amount","$description"');
    }

    return buffer.toString();
  }

  String _generateSettlementsCSV(BalanceProvider provider) {
    final buffer = StringBuffer();
    buffer.writeln('From,To,Amount');

    for (final settlement in provider.settlements) {
      final amount = settlement.amount / 100;
      buffer.writeln('"${settlement.from}","${settlement.to}","$amount"');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Export Data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Export all expenses and settlements for backup or external analysis',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 32),

          // Export options
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Format',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 16),

                  // CSV Export
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportToCSV,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export as CSV'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // JSON Export
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportToJSON,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export as JSON'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Text Export
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportToText,
                    icon: const Icon(Icons.description),
                    label: const Text('Export as Text Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info
          Card(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What will be exported?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoBullet('All expenses with date, amount, and description'),
                  _buildInfoBullet('User balances (total paid and net balance)'),
                  _buildInfoBullet('Settlements (who pays whom)'),
                  const SizedBox(height: 12),
                  Text(
                    'The exported file will be shared through your device\'s share menu.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
