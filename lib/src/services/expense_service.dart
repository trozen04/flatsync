import 'dart:async';
import 'dart:developer' as developer;

import '../core/constants/api_config.dart';
import '../data/models/expense_model.dart';
import 'api_service.dart';

class ExpenseService {
  final ApiService _api;
  static const Duration _cacheTtl = Duration(seconds: 20);

  final StreamController<int> _updatesController = StreamController<int>.broadcast();
  int _revision = 0;

  List<ExpenseModel>? _expensesCache;
  DateTime? _expensesCacheAt;

  Map<String, dynamic>? _balancesCache;
  DateTime? _balancesCacheAt;

  final Map<String, List<dynamic>> _conversationCache = {};
  final Map<String, DateTime> _conversationCacheAt = {};

  ExpenseService(this._api);

  Stream<int> get updates => _updatesController.stream;

  String _canonicalPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  bool _isFresh(DateTime? timestamp) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheTtl;
  }

  void _emitUpdate() {
    _revision++;
    if (!_updatesController.isClosed) {
      _updatesController.add(_revision);
    }
  }

  void _invalidateCaches() {
    _expensesCache = null;
    _expensesCacheAt = null;
    _balancesCache = null;
    _balancesCacheAt = null;
    _conversationCache.clear();
    _conversationCacheAt.clear();
  }

  Future<ExpenseModel> createExpense({
    required String description,
    required int totalAmount,
    required List<String> participants,
  }) async {
    developer.log('Creating expense: desc=$description, amount=$totalAmount, participants=$participants');

    final response = await _api.post(
      ApiConfig.expenses,
      data: {
        'description': description,
        'totalAmount': totalAmount,
        'participants': participants,
      },
    );

    final model = ExpenseModel.fromJson(response.data['data'] as Map<String, dynamic>);
    _invalidateCaches();
    _emitUpdate();
    return model;
  }

  Future<List<ExpenseModel>> getExpenses({bool forceRefresh = false}) async {
    if (!forceRefresh && _expensesCache != null && _isFresh(_expensesCacheAt)) {
      return _expensesCache!;
    }

    try {
      final response = await _api.get(ApiConfig.expenses);
      final expenses = response.data['data'] as List;
      final parsed = expenses
          .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
          .toList();
      _expensesCache = parsed;
      _expensesCacheAt = DateTime.now();
      return parsed;
    } catch (e) {
      if (_expensesCache != null) return _expensesCache!;
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await _api.delete('${ApiConfig.expenses}/$expenseId');
    _invalidateCaches();
    _emitUpdate();
  }

  Future<void> createTransaction({
    required String toUserId,
    required int amount,
  }) async {
    await _api.post(
      ApiConfig.transactions,
      data: {
        'toUser': toUserId,
        'amount': amount,
      },
    );
    _invalidateCaches();
    _emitUpdate();
  }

  Future<Map<String, dynamic>> getBalances({bool forceRefresh = false}) async {
    if (!forceRefresh && _balancesCache != null && _isFresh(_balancesCacheAt)) {
      return _balancesCache!;
    }

    try {
      final response = await _api.get(ApiConfig.balances);
      final data = response.data['data'];

      if (data is Map<String, dynamic>) {
        if (data['owesMe'] is List || data['iOwe'] is List) {
          final normalized = <String, double>{};

          final owesMe = (data['owesMe'] as List?) ?? const [];
          for (final item in owesMe) {
            if (item is! Map<String, dynamic>) continue;
            final user = item['user'];
            final amount = (item['amount'] as num?)?.toDouble() ?? 0;
            if (user is Map<String, dynamic>) {
              final key = (user['_id'] as String?) ?? (user['phoneNumber'] as String?);
              if (key != null && key.isNotEmpty) {
                normalized[key] = (normalized[key] ?? 0) + amount;
              }
            }
          }

          final iOwe = (data['iOwe'] as List?) ?? const [];
          for (final item in iOwe) {
            if (item is! Map<String, dynamic>) continue;
            final user = item['user'];
            final amount = (item['amount'] as num?)?.toDouble() ?? 0;
            if (user is Map<String, dynamic>) {
              final key = (user['_id'] as String?) ?? (user['phoneNumber'] as String?);
              if (key != null && key.isNotEmpty) {
                normalized[key] = (normalized[key] ?? 0) - amount;
              }
            }
          }

          _balancesCache = normalized;
          _balancesCacheAt = DateTime.now();
          return normalized;
        }

        _balancesCache = data;
        _balancesCacheAt = DateTime.now();
        return data;
      }

      _balancesCache = {};
      _balancesCacheAt = DateTime.now();
      return {};
    } catch (e) {
      if (_balancesCache != null) return _balancesCache!;
      rethrow;
    }
  }

  Future<List<dynamic>> getConversation(String userId, {bool forceRefresh = false, int page = 1, int limit = 20}) async {
    final cacheKey = 'id:$userId:p$page';
    if (!forceRefresh &&
        _conversationCache.containsKey(cacheKey) &&
        _isFresh(_conversationCacheAt[cacheKey])) {
      return _conversationCache[cacheKey]!;
    }

    try {
      final response = await _api.get('${ApiConfig.conversations}/$userId?page=$page&limit=$limit');
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) return [];
      
      final items = data['items'] as List? ?? [];
      final hasMore = data['hasMore'] as bool? ?? false;

      final timeline = items.map((item) {
        if (item is! Map<String, dynamic>) return <String, dynamic>{};

        final type = item['type'] as String? ?? '';
        final payload = item['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
        final createdAt = (item['createdAt'] as String?) ??
            (payload['createdAt'] as String?) ??
            DateTime.now().toUtc().toIso8601String();

        final amount = type == 'expense'
            ? (item['amount'] as num?)?.toDouble() ??
                (payload['totalAmount'] as num?)?.toDouble() ??
                0
            : (payload['amount'] as num?)?.toDouble() ?? 0;

        final otherId = userId;
        final expenseCreator = payload['createdBy'];
        final expenseCreatorId =
            expenseCreator is Map<String, dynamic> ? expenseCreator['_id'] as String? : null;
        final fromUser = payload['fromUser'];
        final fromUserId = fromUser is Map<String, dynamic> ? fromUser['_id'] as String? : null;

        final isFromOther = fromUserId == otherId;
        final direction = type == 'transaction'
            ? (isFromOther ? 'received' : 'sent')
            : (expenseCreatorId == otherId ? 'they_paid' : 'you_paid');

        final signedAmount = type == 'transaction'
            ? (isFromOther ? -amount : amount)
            : (expenseCreatorId == otherId ? -amount : amount);

        String description;
        if (type == 'transaction') {
          description = isFromOther ? 'Received payment' : 'Sent payment';
        } else {
          description = (payload['description'] as String?) ?? 'Expense';
        }

        return <String, dynamic>{
          'type': type,
          'amount': amount,
          'signedAmount': signedAmount,
          'direction': direction,
          'description': description,
          'createdAt': createdAt,
          'expenseId': type == 'expense' ? (payload['_id'] as String?) : null,
          'createdBy': type == 'expense' && expenseCreator is Map<String, dynamic> ? expenseCreatorId : null,
        };
      }).where((e) => e.isNotEmpty).toList();

      _conversationCache[cacheKey] = timeline;
      _conversationCacheAt[cacheKey] = DateTime.now();
      return timeline;
    } catch (e) {
      if (_conversationCache.containsKey(cacheKey)) {
        return _conversationCache[cacheKey]!;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getConversationByPhone(String phoneNumber, {bool forceRefresh = false}) async {
    final target = _canonicalPhone(phoneNumber);
    if (target.isEmpty) return [];
    final cacheKey = 'phone:$target';

    if (!forceRefresh &&
        _conversationCache.containsKey(cacheKey) &&
        _isFresh(_conversationCacheAt[cacheKey])) {
      return _conversationCache[cacheKey]!;
    }

    final expenses = await getExpenses(forceRefresh: forceRefresh);
    final timeline = <Map<String, dynamic>>[];

    for (final expense in expenses) {
      final participantMatch = expense.participants.any((p) => _canonicalPhone(p) == target);
      final paidByMatch = _canonicalPhone(expense.paidBy) == target;

      if (!participantMatch && !paidByMatch) continue;

      final youPaid = !paidByMatch;
      final splitCount = expense.participants.length + 1;
      final amount = splitCount > 0
          ? (expense.amount / splitCount).toDouble()
          : expense.amount.toDouble();

      timeline.add({
        'type': 'expense',
        'amount': amount,
        'signedAmount': youPaid ? amount : -amount,
        'direction': youPaid ? 'you_paid' : 'they_paid',
        'description': expense.description ?? 'Expense',
        'createdAt': expense.createdAt.toUtc().toIso8601String(),
      });
    }

    timeline.sort(
      (a, b) => DateTime.parse(b['createdAt'] as String)
          .compareTo(DateTime.parse(a['createdAt'] as String)),
    );

    _conversationCache[cacheKey] = timeline;
    _conversationCacheAt[cacheKey] = DateTime.now();
    return timeline;
  }

  Future<void> refreshAll() async {
    await getExpenses(forceRefresh: true);
    await getBalances(forceRefresh: true);
    _emitUpdate();
  }
}
