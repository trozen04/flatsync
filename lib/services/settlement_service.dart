import 'package:flatsync/models/expense_model.dart';
import 'package:flatsync/models/settlement_entity.dart';
import 'package:flatsync/constants/app_constants.dart';

/// Settlement Calculation Service
/// Implements the minimal transaction settlement algorithm
class SettlementService {
  /// Calculate balances for all users
  static List<UserBalance> calculateBalances(List<ExpenseModel> expenses) {
    // Filter out deleted expenses for calculations
    final activeExpenses = expenses.where((e) => !e.isDeleted).toList();

    // Build the user set from the actual expense data so the calculation
    // matches the current dataset instead of a hardcoded demo roster.
    final users = <String>{};
    final totalPaidByUser = <String, int>{};
    final totalOwedByUser = <String, int>{};

    for (final expense in activeExpenses) {
      final baseUsername = AppConstants.getBaseUsername(expense.paidBy);
      if (baseUsername.isNotEmpty) {
        users.add(baseUsername);
        totalPaidByUser[baseUsername] =
            (totalPaidByUser[baseUsername] ?? 0) + expense.amount;
      }

      final participantUsers = expense.participants
          .map(AppConstants.getBaseUsername)
          .where((user) => user.trim().isNotEmpty)
          .toSet()
          .toList();

      if (participantUsers.isEmpty && baseUsername.isNotEmpty) {
        participantUsers.add(baseUsername);
      }

      users.addAll(participantUsers);

      if (participantUsers.isEmpty) {
        continue;
      }

      final baseShare = expense.amount ~/ participantUsers.length;
      final remainder = expense.amount % participantUsers.length;

      for (var i = 0; i < participantUsers.length; i++) {
        final user = participantUsers[i];
        final share = baseShare + (i < remainder ? 1 : 0);
        totalOwedByUser[user] = (totalOwedByUser[user] ?? 0) + share;
      }
    }

    final balances = users.toList()..sort();
    return balances
        .map(
          (user) => UserBalance(
            user: user,
            totalPaid: totalPaidByUser[user] ?? 0,
            perPersonShare: totalOwedByUser[user] ?? 0,
            netBalance: (totalPaidByUser[user] ?? 0) - (totalOwedByUser[user] ?? 0),
          ),
        )
        .toList();
  }

  /// Calculate minimal settlements needed
  static List<Settlement> calculateSettlements(List<UserBalance> balances) {
    final settlements = <Settlement>[];

    // Create mutable copies of balances for manipulation
    final debtors = <String, int>{};
    final creditors = <String, int>{};

    for (final balance in balances) {
      if (balance.netBalance < 0) {
        debtors[balance.user] = -balance.netBalance;
      } else if (balance.netBalance > 0) {
        creditors[balance.user] = balance.netBalance;
      }
    }

    // Process settlements
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      // Get the debtor with the highest debt and creditor with the highest credit
      final maxDebtorEntry = debtors.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final maxCreditorEntry = creditors.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      final debtor = maxDebtorEntry.key;
      final debtAmount = maxDebtorEntry.value;
      final creditor = maxCreditorEntry.key;
      final creditAmount = maxCreditorEntry.value;

      // Settle the minimum of debt and credit
      final settlementAmount = debtAmount < creditAmount ? debtAmount : creditAmount;

      settlements.add(
        Settlement(
          from: debtor,
          to: creditor,
          amount: settlementAmount,
        ),
      );

      // Update remaining amounts
      debtors[debtor] = debtAmount - settlementAmount;
      creditors[creditor] = creditAmount - settlementAmount;

      // Remove if settled completely
      if (debtors[debtor] == 0) {
        debtors.remove(debtor);
      }
      if (creditors[creditor] == 0) {
        creditors.remove(creditor);
      }
    }

    return settlements;
  }

  /// Get combined result: balances and settlements
  static ({List<UserBalance> balances, List<Settlement> settlements}) calculateFull(
    List<ExpenseModel> expenses,
  ) {
    final balances = calculateBalances(expenses);
    final settlements = calculateSettlements(balances);
    return (balances: balances, settlements: settlements);
  }

  /// Verify that settlements balance correctly (for testing/validation)
  static bool verifiesBalances(
    List<UserBalance> balances,
    List<Settlement> settlements,
  ) {
    final balanceMap = <String, int>{};
    for (final balance in balances) {
      balanceMap[balance.user] = balance.netBalance;
    }

    for (final settlement in settlements) {
      balanceMap[settlement.from] = balanceMap[settlement.from]! + settlement.amount;
      balanceMap[settlement.to] = balanceMap[settlement.to]! - settlement.amount;
    }

    // All balances should be zero after settlements
    return balanceMap.values.every((balance) => balance == 0);
  }
}

