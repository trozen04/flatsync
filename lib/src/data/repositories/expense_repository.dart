import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/data/repositories/isar_service.dart';

/// Repository for expense data access
/// Abstracts database implementation from business logic
class ExpenseRepository {
  final IsarService _isarService;

  ExpenseRepository(this._isarService);

  Future<void> addExpense(ExpenseModel expense) async {
    await _isarService.addExpense(expense);
  }

  Future<List<ExpenseModel>> getAllExpenses() async {
    return await _isarService.getAllExpenses();
  }

  Future<ExpenseModel?> getExpenseByUuid(String uuid) async {
    return await _isarService.getExpenseByUuid(uuid);
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _isarService.updateExpense(expense);
  }

  Future<void> deleteExpense(String uuid) async {
    await _isarService.softDeleteExpense(uuid);
  }

  Future<List<ExpenseModel>> getActiveExpenses() async {
    return await _isarService.getActiveExpenses();
  }

  Future<List<ExpenseModel>> getAllExpensesIncludingDeleted() async {
    return await _isarService.getAllExpenses();
  }

  Future<List<ExpenseModel>> getExpensesModifiedAfter(DateTime timestamp) async {
    return await _isarService.getExpensesModifiedAfter(timestamp);
  }

  Future<void> upsertExpense(ExpenseModel expense) async {
    await _isarService.upsertExpense(expense);
  }

  Future<void> batchUpsertExpenses(List<ExpenseModel> expenses) async {
    await _isarService.batchUpsertExpenses(expenses);
  }

  Future<int> getExpenseCount() async {
    return await _isarService.getExpenseCount();
  }
}
