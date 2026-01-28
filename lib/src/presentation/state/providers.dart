import 'package:flutter/foundation.dart';
import 'package:flatsync/src/data/models/expense_model.dart';
import 'package:flatsync/src/data/repositories/expense_repository.dart';
import 'package:flatsync/src/domain/entities/settlement_entity.dart';
import 'package:flatsync/src/services/settlement/settlement_service.dart';
import 'package:uuid/uuid.dart';

/// State provider for expense management
/// Handles adding expenses and notifying listeners
class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _repository;
  late String _deviceId;
  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> _allExpenses = [];

  ExpenseProvider(this._repository);

  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  List<ExpenseModel> get expenses => _expenses;
  List<ExpenseModel> get allExpenses => _allExpenses;

  Future<void> loadExpenses() async {
    _expenses = await _repository.getActiveExpenses();
    _allExpenses = await _repository.getAllExpensesIncludingDeleted();
    notifyListeners();
  }

  Future<void> addExpense({
    required int amount,
    required String paidBy,
    String? description,
  }) async {
    // Generate UUID with device ID and timestamp for guaranteed uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = '${_deviceId}_${timestamp}_${const Uuid().v4().substring(0, 8)}';
    
    final expense = ExpenseModel(
      uuid: uuid,
      amount: amount,
      paidBy: paidBy,
      createdAt: DateTime.now().toUtc(),
      lastModifiedAt: DateTime.now().toUtc(),
      deviceId: _deviceId,
      description: description,
    );

    await _repository.addExpense(expense);
    _expenses.add(expense);
    notifyListeners();
  }

  Future<void> deleteExpense(String uuid) async {
    await _repository.deleteExpense(uuid);
    await loadExpenses(); // Reload both active and all expenses
    notifyListeners();
  }

  Future<void> syncExpenses(List<ExpenseModel> remoteExpenses) async {
    await _repository.batchUpsertExpenses(remoteExpenses);
    await loadExpenses();
  }

  int getTotalAmount() {
    return _expenses.fold<int>(0, (sum, e) => sum + e.amount);
  }
}

/// State provider for balance calculations
class BalanceProvider extends ChangeNotifier {
  final ExpenseProvider _expenseProvider;
  List<UserBalance> _balances = [];
  List<Settlement> _settlements = [];

  BalanceProvider(this._expenseProvider) {
    _expenseProvider.addListener(_recalculate);
  }

  List<UserBalance> get balances => _balances;
  List<Settlement> get settlements => _settlements;

  void _recalculate() {
    _updateBalances();
  }

  void _updateBalances() {
    final result = SettlementService.calculateFull(_expenseProvider.expenses);
    _balances = result.balances;
    _settlements = result.settlements;
    notifyListeners();
  }

  @override
  void dispose() {
    _expenseProvider.removeListener(_recalculate);
    super.dispose();
  }
}

/// State provider for sync status
class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncStatus;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncStatus => _syncStatus;

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  void setLastSyncTime(DateTime time) {
    _lastSyncTime = time;
    notifyListeners();
  }

  void setSyncStatus(String? status) {
    _syncStatus = status;
    notifyListeners();
  }
}
