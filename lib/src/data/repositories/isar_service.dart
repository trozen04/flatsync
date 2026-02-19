import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/data/models/user_model.dart';
import 'package:flatsync/src/data/models/contact_model.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  late Isar isar;

  Future<void> openDB() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        ExpenseModelSchema,
        UserModelSchema,
        ContactModelSchema,
      ],
      directory: dir.path,
      maxSizeMiB: 256,
    );
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await isar.writeTxn(() async {
      await isar.expenseModels.put(expense);
    });
  }

  Future<List<ExpenseModel>> getAllExpenses() async {
    return await isar.expenseModels.where().findAll();
  }

  Future<ExpenseModel?> getExpenseByUuid(String uuid) async {
    return await isar.expenseModels.where().uuidEqualTo(uuid).findFirst();
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await isar.writeTxn(() async {
      await isar.expenseModels.put(expense);
    });
  }

  Future<void> softDeleteExpense(String uuid) async {
    await isar.writeTxn(() async {
      final expense = await isar.expenseModels.where().uuidEqualTo(uuid).findFirst();
      if (expense != null) {
        expense.isDeleted = true;
        expense.deletedAt = DateTime.now().toUtc();
        expense.lastModifiedAt = DateTime.now().toUtc();
        await isar.expenseModels.put(expense);
      }
    });
  }

  Future<List<ExpenseModel>> getActiveExpenses() async {
    return await isar.expenseModels.filter().isDeletedEqualTo(false).findAll();
  }

  Future<List<ExpenseModel>> getExpensesModifiedAfter(DateTime timestamp) async {
    return await isar.expenseModels
      .filter()
      .lastModifiedAtGreaterThan(timestamp)
      .findAll();
  }

  Future<void> upsertExpense(ExpenseModel expense) async {
    await isar.writeTxn(() async {
      final existing = await isar.expenseModels.where().uuidEqualTo(expense.uuid).findFirst();
      
      if (existing != null) {
        if (!expense.lastModifiedAt.isBefore(existing.lastModifiedAt)) {
          expense.id = existing.id;
          await isar.expenseModels.put(expense);
        }
      } else {
        await isar.expenseModels.put(expense);
      }
    });
  }

  Future<void> batchUpsertExpenses(List<ExpenseModel> expenses) async {
    await isar.writeTxn(() async {
      for (final expense in expenses) {
        final existing = await isar.expenseModels.where().uuidEqualTo(expense.uuid).findFirst();
        
        if (existing != null) {
          if (!expense.lastModifiedAt.isBefore(existing.lastModifiedAt)) {
            expense.id = existing.id;
            await isar.expenseModels.put(expense);
          }
        } else {
          await isar.expenseModels.put(expense);
        }
      }
    });
  }

  Future<void> clearAllExpenses() async {
    await isar.writeTxn(() async {
      await isar.expenseModels.clear();
    });
  }

  Future<void> replaceCurrentUser(UserModel user) async {
    await isar.writeTxn(() async {
      await isar.userModels.clear();
      await isar.userModels.put(user);
    });
  }

  Future<int> getExpenseCount() async {
    return await isar.expenseModels.count();
  }

  Future<void> close() async {
    await isar.close();
  }
}
