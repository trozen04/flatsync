import 'dart:developer' as developer;
import 'dart:io';
import 'package:flatsync/models/expense_model.dart';
import 'package:flatsync/models/settlement_entity.dart';
import 'package:flatsync/utils/date_utils.dart';

/// Utility class for exporting data to CSV
class CSVExporter {
  /// Export expenses to CSV format
  static String exportExpensesToCSV(List<ExpenseModel> expenses) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Date,User,Amount,Description,Device,UUID');

    // Data rows
    for (final expense in expenses) {
      final amount = expense.amount / 100;
      final date = AppDateUtils.formatDateTime(expense.createdAt);
      final user = expense.paidBy;
      final description = expense.description ?? '';

      // Escape quotes in description
      final escapedDescription = description.replaceAll('"', '""');

      buffer.writeln(
        '"$date","$user","$amount","$escapedDescription","${expense.deviceId}","${expense.uuid}"',
      );
    }

    return buffer.toString();
  }

  /// Export settlements to CSV format
  static String exportSettlementsToCSV(List<Settlement> settlements) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('From,To,Amount');

    // Data rows
    for (final settlement in settlements) {
      final amount = settlement.amount / 100;
      buffer.writeln('"${settlement.from}","${settlement.to}","$amount"');
    }

    return buffer.toString();
  }

  /// Export balances to CSV format
  static String exportBalancesToCSV(List<UserBalance> balances) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('User,Total Paid,Per Person Share,Net Balance');

    // Data rows
    for (final balance in balances) {
      final totalPaid = balance.totalPaid / 100;
      final perShare = balance.perPersonShare / 100;
      final netBalance = balance.netBalance / 100;

      buffer.writeln(
        '"${balance.user}","$totalPaid","$perShare","$netBalance"',
      );
    }

    return buffer.toString();
  }

  /// Export as readable text format for sharing on mobile
  static String exportToReadableText(
    List<ExpenseModel> expenses,
    List<UserBalance> balances,
    List<Settlement> settlements,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('SplitEasy Expense Report');
    buffer.writeln(AppDateUtils.formatDateTime(DateTime.now()));
    buffer.writeln('═' * 50);
    
    // Expenses section
    buffer.writeln('\n📊 EXPENSES (${expenses.length})');
    buffer.writeln('─' * 50);
    for (final expense in expenses) {
      final date = AppDateUtils.formatDateTime(expense.createdAt);
      final amount = (expense.amount / 100).toStringAsFixed(2);
      buffer.writeln('$date | ${expense.paidBy}');
      buffer.writeln('  ₹$amount${expense.description != null ? ' - ${expense.description}' : ''}');
    }
    
    // Balances section
    buffer.writeln('\n💰 BALANCES');
    buffer.writeln('─' * 50);
    int totalAmount = 0;
    for (final balance in balances) {
      final totalPaid = (balance.totalPaid / 100).toStringAsFixed(2);
      final netBalance = (balance.netBalance / 100).toStringAsFixed(2);
      totalAmount += balance.totalPaid;
      
      final status = balance.netBalance > 0 ? '✓ Gets' : balance.netBalance < 0 ? '✗ Pays' : '= Even';
      buffer.writeln('${balance.user}');
      buffer.writeln('  Paid: ₹$totalPaid | Balance: ₹$netBalance ($status)');
    }
    
    buffer.writeln('\nTotal Expenses: ₹${(totalAmount / 100).toStringAsFixed(2)}');
    
    // Settlements section
    if (settlements.isNotEmpty) {
      buffer.writeln('\n🔄 WHO PAYS WHOM');
      buffer.writeln('─' * 50);
      for (final settlement in settlements) {
        final amount = (settlement.amount / 100).toStringAsFixed(2);
        buffer.writeln('${settlement.from} → ${settlement.to}: ₹$amount');
      }
    } else {
      buffer.writeln('\n🔄 WHO PAYS WHOM');
      buffer.writeln('─' * 50);
      buffer.writeln('Everyone is settled!');
    }
    
    buffer.writeln('\n' + '═' * 50);
    buffer.writeln('Exported from SplitEasy');
    
    return buffer.toString();
  }
}

/// Utility class for other export formats
class ExportUtils {
  /// Validate that settlements are correct
  static bool validateSettlements(
    List<UserBalance> balances,
    List<Settlement> settlements,
  ) {
    // Sum of all balances should be zero
    final totalBalance = balances.fold<int>(0, (sum, b) => sum + b.netBalance);
    if (totalBalance != 0) {
      developer.log('ERROR: Total balance is not zero: $totalBalance');
      return false;
    }

    // After settlements, all balances should be zero
    final balanceMap = <String, int>{};
    for (final balance in balances) {
      balanceMap[balance.user] = balance.netBalance;
    }

    for (final settlement in settlements) {
      balanceMap[settlement.from] =
          (balanceMap[settlement.from] ?? 0) + settlement.amount;
      balanceMap[settlement.to] =
          (balanceMap[settlement.to] ?? 0) - settlement.amount;
    }

    for (final entry in balanceMap.entries) {
      if (entry.value != 0) {
        developer.log('ERROR: ${entry.key} balance is not zero after settlements: ${entry.value}');
        return false;
      }
    }

    return true;
  }

  /// developer.log a summary for debugging
  static void printSummary(
    List<ExpenseModel> expenses,
    List<UserBalance> balances,
    List<Settlement> settlements,
  ) {
    developer.log('\n=== FlatSync Summary ===');
    developer.log('Total Expenses: ${expenses.length}');
    developer.log('Total Amount: ₹${(expenses.fold<int>(0, (sum, e) => sum + e.amount) / 100).toStringAsFixed(2)}');
    developer.log('\nBalances:');
    for (final balance in balances) {
      developer.log('  ${balance.user}: ₹${(balance.netBalance / 100).toStringAsFixed(2)}');
    }
    developer.log('\nSettlements:');
    for (final settlement in settlements) {
      developer.log('  ${settlement.from} → ${settlement.to}: ₹${(settlement.amount / 100).toStringAsFixed(2)}');
    }
    developer.log('======================\n');
  }
}

