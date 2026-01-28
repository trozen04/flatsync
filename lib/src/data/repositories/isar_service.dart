import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Database service for local persistence using Isar
/// Handles all CRUD operations for expenses
/// Thread-safe and optimized for offline-first operation
class IsarService {
  static final IsarService _instance = IsarService._internal();
  static late Isar _isar;

  factory IsarService() {
    return _instance;
  }

  IsarService._internal();

  /// Initialize Isar database - call once at app startup
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ExpenseModelSchema],
      directory: dir.path,
      maxSizeMiB: 256,
    );
  }

  /// Get singleton instance of Isar
  static Isar get instance => _isar;

  /// Add a new expense to the database
  Future<void> addExpense(ExpenseModel expense) async {
    await _isar.writeTxn(() async {
      await _isar.expenseModels.put(expense);
    });
  }

  /// Get all expenses
  Future<List<ExpenseModel>> getAllExpenses() async {
    return await _isar.expenseModels.where().findAll();
  }

  /// Get expense by UUID
  Future<ExpenseModel?> getExpenseByUuid(String uuid) async {
    return await _isar.expenseModels.where().uuidEqualTo(uuid).findFirst();
  }

  /// Update an existing expense
  Future<void> updateExpense(ExpenseModel expense) async {
    await _isar.writeTxn(() async {
      await _isar.expenseModels.put(expense);
    });
  }

  /// Soft delete an expense (mark as deleted instead of removing)
  Future<void> softDeleteExpense(String uuid) async {
    await _isar.writeTxn(() async {
      final expense = await _isar.expenseModels.where().uuidEqualTo(uuid).findFirst();
      if (expense != null) {
        expense.isDeleted = true;
        expense.deletedAt = DateTime.now().toUtc();
        expense.lastModifiedAt = DateTime.now().toUtc();
        await _isar.expenseModels.put(expense);
      }
    });
  }

  /// Get only active (non-deleted) expenses
  Future<List<ExpenseModel>> getActiveExpenses() async {
    return await _isar.expenseModels.filter().isDeletedEqualTo(false).findAll();
  }

  /// Get expenses created after a certain timestamp (for sync)
  Future<List<ExpenseModel>> getExpensesModifiedAfter(DateTime timestamp) async {
    return await _isar.expenseModels
      .filter()
      .lastModifiedAtGreaterThan(timestamp)
      .findAll();
  }

  /// Upsert expense - insert if not exists, update if exists
  /// Uses UUID as the unique identifier
  Future<void> upsertExpense(ExpenseModel expense) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.expenseModels.where().uuidEqualTo(expense.uuid).findFirst();
      
      if (existing != null) {
        // Conflict resolution: latest modification wins
        if (expense.lastModifiedAt.isAfter(existing.lastModifiedAt)) {
          // Update the Isar ID to maintain referential integrity
          expense.id = existing.id;
          await _isar.expenseModels.put(expense);
        }
        // If existing is newer, keep it (no update)
      } else {
        // New expense, insert it
        await _isar.expenseModels.put(expense);
      }
    });
  }

  /// Batch upsert multiple expenses (efficient for sync)
  Future<void> batchUpsertExpenses(List<ExpenseModel> expenses) async {
    await _isar.writeTxn(() async {
      for (final expense in expenses) {
        final existing = await _isar.expenseModels.where().uuidEqualTo(expense.uuid).findFirst();
        
        if (existing != null) {
          if (expense.lastModifiedAt.isAfter(existing.lastModifiedAt)) {
            expense.id = existing.id;
            await _isar.expenseModels.put(expense);
          }
        } else {
          await _isar.expenseModels.put(expense);
        }
      }
    });
  }

  /// Clear all expenses (use with caution)
  Future<void> clearAllExpenses() async {
    await _isar.writeTxn(() async {
      await _isar.expenseModels.clear();
    });
  }

  /// Get count of expenses
  Future<int> getExpenseCount() async {
    return await _isar.expenseModels.count();
  }

  /// Close database connection
  Future<void> close() async {
    await _isar.close();
  }
}
