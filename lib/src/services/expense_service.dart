import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_config.dart';
import '../data/models/expense_model.dart';
import '../data/models/transaction_model.dart';
import '../data/models/contact_model.dart';
import '../data/repositories/isar_service.dart';
import 'api_service.dart';

class ExpenseService {
  final ApiService _api;
  final IsarService _isarService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const Duration _cacheTtl = Duration(seconds: 20);
  static const String _balancesStorageKey = 'offline_cached_balances_v1';
  static const String _recentAmountsStorageKey = 'recent_amounts_paise_v1';
  static const String _transactionsStorageKey = 'offline_cached_transactions_v1';
  static const int _maxRecentAmounts = 8;

  final StreamController<int> _updatesController = StreamController<int>.broadcast();
  int _revision = 0;

  List<ExpenseModel>? _expensesCache;
  DateTime? _expensesCacheAt;

  List<TransactionModel>? _transactionsCache;
  DateTime? _transactionsCacheAt;

  Map<String, dynamic>? _balancesCache;
  DateTime? _balancesCacheAt;

  List<ContactModel>? _balanceContactsCache;
  DateTime? _balanceContactsCacheAt;

  final Map<String, List<dynamic>> _conversationCache = {};
  final Map<String, DateTime> _conversationCacheAt = {};
  final Map<String, List<Map<String, dynamic>>> _timelineCache = {};
  final Map<String, DateTime> _timelineCacheAt = {};

  SharedPreferences? _prefs;

  ExpenseService(this._api, this._isarService);

  Stream<int> get updates => _updatesController.stream;

  void _logBalanceUser(String source, Map<String, dynamic> user, num amount, {int? index}) {
    final id = user['_id'] ?? user['id'];
    final phone = user['phoneNumber'];
    final name = user['name'];
    final suffix = index == null ? '' : '[$index]';
    developer.log('$source$suffix user -> id=$id, phone=$phone, name=$name, amount=$amount');
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String?> _currentUserId() async {
    return _secureStorage.read(key: 'user_id');
  }

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
    _transactionsCache = null;
    _transactionsCacheAt = null;
    _balancesCache = null;
    _balancesCacheAt = null;
    _balanceContactsCache = null;
    _balanceContactsCacheAt = null;
    _conversationCache.clear();
    _conversationCacheAt.clear();
    _timelineCache.clear();
    _timelineCacheAt.clear();
  }

  List<ContactModel> getCachedBalanceContacts() {
    if (_balanceContactsCache == null) return const [];
    return List<ContactModel>.unmodifiable(_balanceContactsCache!);
  }

  Future<void> _persistBalances(Map<String, dynamic> balances) async {
    try {
      final prefs = await _ensurePrefs();
      await prefs.setString(_balancesStorageKey, jsonEncode(balances));
    } catch (e) {
      developer.log('Persist balances cache error: $e');
    }
  }

  Future<Map<String, dynamic>> _readPersistedBalances() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs.getString(_balancesStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final normalized = <String, int>{};
      decoded.forEach((key, value) {
        normalized[key.toString()] = (value as num?)?.round() ?? 0;
      });
      normalized.removeWhere((_, v) => v == 0);
      return normalized;
    } catch (e) {
      developer.log('Read balances cache error: $e');
      return {};
    }
  }

  Future<void> _storeRecentAmount(int amountInPaise) async {
    if (amountInPaise <= 0) return;
    try {
      final prefs = await _ensurePrefs();
      final existing = prefs.getStringList(_recentAmountsStorageKey) ?? <String>[];
      final filtered = existing.where((v) => v != amountInPaise.toString()).toList();
      final updated = <String>[amountInPaise.toString(), ...filtered];
      final limited = updated.take(_maxRecentAmounts).toList();
      await prefs.setStringList(_recentAmountsStorageKey, limited);
    } catch (e) {
      developer.log('Persist recent amount error: $e');
    }
  }

  Future<void> _persistTransactions(List<TransactionModel> transactions) async {
    try {
      final prefs = await _ensurePrefs();
      final rows = _dedupeTransactions(transactions).map((t) => t.toJson()).toList();
      await prefs.setString(_transactionsStorageKey, jsonEncode(rows));
    } catch (e) {
      developer.log('Persist transactions cache error: $e');
    }
  }

  Future<List<TransactionModel>> _readPersistedTransactions() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs.getString(_transactionsStorageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => TransactionModel(
                transactionId: (e['transactionId'] as String?) ?? '',
                fromUserId: (e['fromUserId'] as String?) ?? '',
                toUserId: (e['toUserId'] as String?) ?? '',
                amount: (e['amount'] as num?)?.toInt() ?? 0,
                createdAt: DateTime.tryParse((e['createdAt'] as String?) ?? '') ?? DateTime.now().toUtc(),
                updatedAt: DateTime.tryParse((e['updatedAt'] as String?) ?? '') ?? DateTime.now().toUtc(),
                relatedExpenseId: e['relatedExpenseId'] as String?,
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      developer.log('Read transactions cache error: $e');
      return [];
    }
  }

  List<TransactionModel> _dedupeTransactions(List<TransactionModel> rows) {
    final map = <String, TransactionModel>{};
    for (final tx in rows) {
      final key = tx.transactionId.trim();
      if (key.isEmpty) continue;
      final existing = map[key];
      if (existing == null || !tx.updatedAt.isBefore(existing.updatedAt)) {
        map[key] = tx;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<int>> getRecentAmounts() async {
    try {
      final prefs = await _ensurePrefs();
      final stored = prefs.getStringList(_recentAmountsStorageKey) ?? <String>[];
      return stored
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e > 0)
          .toList();
    } catch (_) {
      return [];
    }
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
    await _isarService.upsertExpense(model);
    await _storeRecentAmount(totalAmount);

    _invalidateCaches();
    _emitUpdate();
    return model;
  }

  Future<List<ExpenseModel>> getExpenses({bool forceRefresh = false}) async {
    if (!forceRefresh && _expensesCache != null && _isFresh(_expensesCacheAt)) {
      return _expensesCache!;
    }

    if (!forceRefresh) {
      try {
        final local = await _isarService.getActiveExpenses();
        if (local.isNotEmpty) {
          local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _expensesCache = local;
          _expensesCacheAt = DateTime.now();
          return local;
        }
      } catch (dbError) {
        developer.log('Read local expenses (pre-network) error: $dbError');
      }
    }

    try {
      final response = await _api.get(ApiConfig.expenses);
      final expenses = response.data['data'] as List;
      final parsed = expenses
          .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
          .toList();

      await _isarService.batchUpsertExpenses(parsed);
      _expensesCache = parsed;
      _expensesCacheAt = DateTime.now();
      return parsed;
    } catch (e) {
      try {
        final local = await _isarService.getActiveExpenses();
        if (local.isNotEmpty) {
          local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _expensesCache = local;
          _expensesCacheAt = DateTime.now();
          return local;
        }
      } catch (dbError) {
        developer.log('Read local expenses cache error: $dbError');
      }

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
    final response = await _api.post(
      ApiConfig.transactions,
      data: {
        'toUser': toUserId,
        'amount': amount,
      },
    );

    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      final transaction = TransactionModel.fromJson(data);
      final existing = List<TransactionModel>.from(_transactionsCache ?? const []);
      existing.removeWhere((t) => t.transactionId == transaction.transactionId);
      existing.insert(0, transaction);
      _transactionsCache = existing;
      _transactionsCacheAt = DateTime.now();
      unawaited(_persistTransactions(existing));
    }

    await _storeRecentAmount(amount);
    _invalidateCaches();
    _emitUpdate();
  }

  Future<List<TransactionModel>> getTransactions({bool forceRefresh = false}) async {
    if (!forceRefresh && _transactionsCache != null && _isFresh(_transactionsCacheAt)) {
      return _transactionsCache!;
    }

    if (!forceRefresh) {
      final local = await _readPersistedTransactions();
      local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (local.isNotEmpty) {
        _transactionsCache = local;
        _transactionsCacheAt = DateTime.now();
        return local;
      }
    }

    try {
      final response = await _api.get(ApiConfig.transactions);
      final rows = response.data['data'] as List;
      final parsed = rows
          .whereType<Map<String, dynamic>>()
          .map(TransactionModel.fromJson)
          .toList();

      final deduped = _dedupeTransactions(parsed);
      unawaited(_persistTransactions(deduped));
      _transactionsCache = deduped;
      _transactionsCacheAt = DateTime.now();
      return deduped;
    } catch (e) {
      final local = _dedupeTransactions(await _readPersistedTransactions());
      if (local.isNotEmpty) {
        _transactionsCache = local;
        _transactionsCacheAt = DateTime.now();
        return local;
      }

      if (_transactionsCache != null) return _transactionsCache!;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBalances({bool forceRefresh = false}) async {
    if (!forceRefresh && _balancesCache != null && _isFresh(_balancesCacheAt)) {
      return _balancesCache!;
    }

    // Prefer server truth; keep persisted balances only as an offline fallback.
    final localFallback = (!forceRefresh) ? await _readPersistedBalances() : <String, dynamic>{};

    try {
      final response = await _api.get(ApiConfig.balances);
      final data = response.data['data'];

      if (data is Map<String, dynamic>) {
        if (data['owesMe'] is List || data['iOwe'] is List) {
          final normalized = <String, int>{};
          final contacts = <ContactModel>[];

          final owesMe = (data['owesMe'] as List?) ?? const [];
          for (var i = 0; i < owesMe.length; i++) {
            final item = owesMe[i];
            if (item is! Map<String, dynamic>) continue;
            final user = item['user'];
            final amount = (item['amount'] as num?) ?? 0;
            if (user is Map<String, dynamic>) {
              _logBalanceUser('balances.owesMe', user, amount, index: i);
              try {
                contacts.add(ContactModel.fromJson(user));
              } catch (_) {}
              final key = (user['_id'] as String?) ?? (user['phoneNumber'] as String?);
              if (key != null && key.isNotEmpty) {
                normalized[key] = (normalized[key] ?? 0) + amount.round();
              }
            }
          }

          final iOwe = (data['iOwe'] as List?) ?? const [];
          for (var i = 0; i < iOwe.length; i++) {
            final item = iOwe[i];
            if (item is! Map<String, dynamic>) continue;
            final user = item['user'];
            final amount = (item['amount'] as num?) ?? 0;
            if (user is Map<String, dynamic>) {
              _logBalanceUser('balances.iOwe', user, amount, index: i);
              try {
                contacts.add(ContactModel.fromJson(user));
              } catch (_) {}
              final key = (user['_id'] as String?) ?? (user['phoneNumber'] as String?);
              if (key != null && key.isNotEmpty) {
                normalized[key] = (normalized[key] ?? 0) - amount.round();
              }
            }
          }

          normalized.removeWhere((_, v) => v == 0);
          _balancesCache = normalized;
          _balancesCacheAt = DateTime.now();
          unawaited(_persistBalances(normalized));

          // Cache enriched contacts extracted from the same response so callers can sync without an extra API hit.
          _balanceContactsCache = contacts;
          _balanceContactsCacheAt = DateTime.now();

          return normalized;
        }

        _balancesCache = data;
        _balancesCacheAt = DateTime.now();
        unawaited(_persistBalances(data));
        return data;
      }

      _balancesCache = {};
      _balancesCacheAt = DateTime.now();
      unawaited(_persistBalances({}));
      return {};
    } catch (e) {
      if (_balancesCache != null) return _balancesCache!;

      if (localFallback.isNotEmpty) {
        _balancesCache = localFallback;
        _balancesCacheAt = DateTime.now();
        return localFallback;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> _localConversationById(
    String userId, {
    required int page,
    required int limit,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final currentUserId = await _currentUserId();

    final expenses = await getExpenses(forceRefresh: false);
    final transactions = await getTransactions(forceRefresh: false);

    final timeline = <Map<String, dynamic>>[];

    for (final expense in expenses) {
      final participantMatch = expense.participants.any((p) => p == userId || _canonicalPhone(p) == _canonicalPhone(userId));
      final paidByMatch = expense.paidBy == userId || _canonicalPhone(expense.paidBy) == _canonicalPhone(userId);
      if (!participantMatch && !paidByMatch) continue;

      final youPaid = !paidByMatch;
      final splitCount = expense.participants.length + 1;
      final amount = splitCount > 0 ? (expense.amount ~/ splitCount) : expense.amount;

      timeline.add({
        'type': 'expense',
        'amount': amount,
        'signedAmount': youPaid ? amount : -amount,
        'direction': youPaid ? 'you_paid' : 'they_paid',
        'description': expense.description ?? 'Expense',
        'createdAt': expense.createdAt.toUtc().toIso8601String(),
      });
    }

    for (final tx in transactions) {
      final isWithUser = tx.fromUserId == userId || tx.toUserId == userId;
      if (!isWithUser) continue;

      final sentByMe = currentUserId != null && tx.fromUserId == currentUserId;
      final direction = sentByMe ? 'sent' : 'received';
      final signedAmount = sentByMe ? tx.amount : -tx.amount;

      timeline.add({
        'type': 'transaction',
        'amount': tx.amount,
        'signedAmount': signedAmount,
        'direction': direction,
        'description': sentByMe ? 'Sent payment' : 'Received payment',
        'createdAt': tx.createdAt.toUtc().toIso8601String(),
      });
    }

    timeline.sort(
      (a, b) => DateTime.parse(b['createdAt'] as String)
          .compareTo(DateTime.parse(a['createdAt'] as String)),
    );

    final start = (safePage - 1) * safeLimit;
    if (start >= timeline.length) return [];
    final end = (start + safeLimit) > timeline.length ? timeline.length : (start + safeLimit);
    return timeline.sublist(start, end);
  }

  Future<List<dynamic>> getConversation(
    String userId, {
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final cacheKey = 'id:$userId:p$safePage:l$safeLimit';
    if (!forceRefresh &&
        _conversationCache.containsKey(cacheKey) &&
        _isFresh(_conversationCacheAt[cacheKey])) {
      return _conversationCache[cacheKey]!;
    }

    try {
      final response = await _api.get(
        '${ApiConfig.conversations}/$userId?page=$safePage&limit=$safeLimit',
      );
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) {
        final local = await _localConversationById(userId, page: safePage, limit: safeLimit);
        _conversationCache[cacheKey] = local;
        _conversationCacheAt[cacheKey] = DateTime.now();
        return local;
      }

      final items = data['items'] as List? ?? [];
      final txToPersist = <TransactionModel>[];

      final timeline = items.map((item) {
        if (item is! Map<String, dynamic>) return <String, dynamic>{};

        final type = item['type'] as String? ?? '';
        final payload = item['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
        final createdAt = (item['createdAt'] as String?) ??
            (payload['createdAt'] as String?) ??
            DateTime.now().toUtc().toIso8601String();

        final amount = type == 'expense'
            ? (item['amount'] as num?)?.round() ??
                (payload['totalAmount'] as num?)?.round() ??
                0
            : (payload['amount'] as num?)?.round() ?? 0;

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

        if (type == 'transaction') {
          txToPersist.add(TransactionModel.fromJson(payload));
        }

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
          'createdBy':
              type == 'expense' && expenseCreator is Map<String, dynamic> ? expenseCreatorId : null,
        };
      }).where((e) => e.isNotEmpty).toList();

      if (txToPersist.isNotEmpty) {
        final existing = await getTransactions(forceRefresh: false);
        final merged = <String, TransactionModel>{
          for (final t in existing) t.transactionId: t,
        };
        for (final t in txToPersist) {
          merged[t.transactionId] = t;
        }
        final updated = _dedupeTransactions(merged.values.toList());
        _transactionsCache = updated;
        _transactionsCacheAt = DateTime.now();
        unawaited(_persistTransactions(updated));
      }

      _conversationCache[cacheKey] = timeline;
      _conversationCacheAt[cacheKey] = DateTime.now();
      return timeline;
    } catch (e) {
      if (_conversationCache.containsKey(cacheKey)) {
        return _conversationCache[cacheKey]!;
      }
      final local = await _localConversationById(userId, page: safePage, limit: safeLimit);
      _conversationCache[cacheKey] = local;
      _conversationCacheAt[cacheKey] = DateTime.now();
      return local;
    }
  }

  Future<TimelinePage> getTimeline({
    String? withUserId,
    bool forceRefresh = false,
    int limit = 20,
    String? cursor,
  }) async {
    final safeLimit = limit < 1 ? 20 : limit;
    final keyUser = (withUserId ?? 'all').trim();
    final keyCursor = (cursor ?? '').trim();
    final cacheKey = 'with:$keyUser:c:$keyCursor:l$safeLimit';

    if (!forceRefresh &&
        _timelineCache.containsKey(cacheKey) &&
        _isFresh(_timelineCacheAt[cacheKey])) {
      final cached = _timelineCache[cacheKey]!;
      return TimelinePage(items: cached, nextCursor: null, hasMore: cached.length >= safeLimit);
    }

    try {
      final qp = <String, dynamic>{
        'limit': safeLimit,
      };
      if (withUserId != null && withUserId.trim().isNotEmpty) {
        qp['withUserId'] = withUserId.trim();
      }
      if (cursor != null && cursor.trim().isNotEmpty) {
        qp['cursor'] = cursor.trim();
      }

      final response = await _api.get(ApiConfig.timeline, queryParameters: qp);
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) {
        return const TimelinePage(items: [], nextCursor: null, hasMore: false);
      }

      final items = (data['items'] as List?) ?? const [];
      final parsed = items
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
          .cast<Map<String, dynamic>>();

      final nextCursor = data['cursor']?.toString();
      final hasMore = (data['hasMore'] is bool) ? (data['hasMore'] as bool) : parsed.length >= safeLimit;

      _timelineCache[cacheKey] = parsed;
      _timelineCacheAt[cacheKey] = DateTime.now();
      return TimelinePage(items: parsed, nextCursor: nextCursor, hasMore: hasMore);
    } catch (e) {
      if (_timelineCache.containsKey(cacheKey)) {
        final cached = _timelineCache[cacheKey]!;
        return TimelinePage(items: cached, nextCursor: null, hasMore: cached.length >= safeLimit);
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
      final amount = splitCount > 0 ? (expense.amount ~/ splitCount) : expense.amount;

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

  Future<List<Map<String, dynamic>>> getHistoryItems({bool forceRefresh = false}) async {
    final currentUserId = await _currentUserId();
    final expenses = await getExpenses(forceRefresh: forceRefresh);
    final transactions = await getTransactions(forceRefresh: forceRefresh);

    final history = <Map<String, dynamic>>[];

    for (final expense in expenses) {
      history.add({
        'type': 'expense',
        'description': expense.description ?? 'Expense',
        'amount': expense.amount,
        'paidBy': expense.paidBy,
        'createdAt': expense.createdAt,
      });
    }

    for (final tx in transactions) {
      final sentByMe = currentUserId != null && tx.fromUserId == currentUserId;
      final counterparty = sentByMe ? tx.toUserId : tx.fromUserId;
      history.add({
        'type': 'transaction',
        'description': sentByMe ? 'Sent payment' : 'Received payment',
        'amount': tx.amount,
        'direction': sentByMe ? 'sent' : 'received',
        'counterparty': counterparty,
        'createdAt': tx.createdAt,
      });
    }

    history.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
    return history;
  }

  Future<void> refreshAll() async {
    await Future.wait([
      getExpenses(forceRefresh: true),
      getTransactions(forceRefresh: true),
      getBalances(forceRefresh: true),
    ]);
    _emitUpdate();
  }
}

class TimelinePage {
  final List<Map<String, dynamic>> items;
  final String? nextCursor;
  final bool hasMore;

  const TimelinePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}
