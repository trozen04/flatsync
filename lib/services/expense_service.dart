import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_config.dart';
import '../models/expense_model.dart';
import '../models/transaction_model.dart';
import '../models/contact_model.dart';
import '../services/isar_service.dart';
import 'api_service.dart';
import '../utils/phone_utils.dart';

class ExpenseService {
  final ApiService _api;
  final IsarService _isarService;

  static const Duration _cacheTtl = Duration(seconds: 20);
  static const String _balancesStorageKey = 'offline_cached_balances_v1';
  static const String _recentAmountsStorageKey = 'recent_amounts_paise_v1';
  static const String _transactionsStorageKey =
      'offline_cached_transactions_v1';
  static const int _maxRecentAmounts = 8;
  static const int _maxConversationCacheEntries = 24;
  static const int _maxTimelineCacheEntries = 24;

  final StreamController<int> _updatesController =
      StreamController<int>.broadcast();
  int _revision = 0;

  List<ExpenseModel>? _expensesCache;
  DateTime? _expensesCacheAt;

  List<TransactionModel>? _transactionsCache;
  DateTime? _transactionsCacheAt;

  Map<String, dynamic>? _balancesCache;
  DateTime? _balancesCacheAt;

  List<ContactModel>? _balanceContactsCache;

  final Map<String, List<dynamic>> _conversationCache = {};
  final Map<String, DateTime> _conversationCacheAt = {};
  final Map<String, TimelinePage> _timelineCache = {};
  final Map<String, DateTime> _timelineCacheAt = {};
  Future<Map<String, dynamic>>? _balancesInFlight;
  Future<Map<String, dynamic>>? _forceRefreshBalancesInFlight;

  SharedPreferences? _prefs;

  ExpenseService(this._api, this._isarService);

  Stream<int> get updates => _updatesController.stream;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String _canonicalPhone(String value) => PhoneUtils.canonical(value);

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
    _conversationCache.clear();
    _conversationCacheAt.clear();
    _timelineCache.clear();
    _timelineCacheAt.clear();
  }

  void _evictTimedCacheEntries<T>(
    Map<String, T> cache,
    Map<String, DateTime> timestamps,
    int maxEntries,
  ) {
    final staleKeys = timestamps.entries
        .where((entry) => !_isFresh(entry.value))
        .map((entry) => entry.key)
        .toList();
    for (final key in staleKeys) {
      cache.remove(key);
      timestamps.remove(key);
    }

    if (timestamps.length <= maxEntries) return;

    final sortedKeys = timestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final overflow = sortedKeys.length - maxEntries;
    for (final entry in sortedKeys.take(overflow)) {
      cache.remove(entry.key);
      timestamps.remove(entry.key);
    }
  }

  void _storeConversationCache(String key, List<dynamic> items) {
    _conversationCache[key] = List<dynamic>.unmodifiable(items);
    _conversationCacheAt[key] = DateTime.now();
    _evictTimedCacheEntries(
        _conversationCache, _conversationCacheAt, _maxConversationCacheEntries);
  }

  void _storeTimelineCache(String key, TimelinePage page) {
    _timelineCache[key] = TimelinePage(
      items: List<Map<String, dynamic>>.unmodifiable(page.items),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
    _timelineCacheAt[key] = DateTime.now();
    _evictTimedCacheEntries(
        _timelineCache, _timelineCacheAt, _maxTimelineCacheEntries);
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
      final existing =
          prefs.getStringList(_recentAmountsStorageKey) ?? <String>[];
      final filtered =
          existing.where((v) => v != amountInPaise.toString()).toList();
      final updated = <String>[amountInPaise.toString(), ...filtered];
      await prefs.setStringList(
          _recentAmountsStorageKey, updated.take(_maxRecentAmounts).toList());
    } catch (e) {
      developer.log('Persist recent amount error: $e');
    }
  }

  Future<void> _persistTransactions(List<TransactionModel> transactions) async {
    try {
      final prefs = await _ensurePrefs();
      final rows =
          _dedupeTransactions(transactions).map((t) => t.toJson()).toList();
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
                toPhone: (e['toPhone'] as String?)?.trim(),
                amount: (e['amount'] as num?)?.toInt() ?? 0,
                createdAt:
                    DateTime.tryParse((e['createdAt'] as String?) ?? '') ??
                        DateTime.now().toUtc(),
                updatedAt:
                    DateTime.tryParse((e['updatedAt'] as String?) ?? '') ??
                        DateTime.now().toUtc(),
                relatedExpenseId: e['relatedExpenseId'] as String?,
                isDeleted: e['isDeleted'] as bool? ?? false,
                deletedBy: (e['deletedBy'] as String?)?.trim(),
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
    return map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<int>> getRecentAmounts() async {
    try {
      final prefs = await _ensurePrefs();
      final stored =
          prefs.getStringList(_recentAmountsStorageKey) ?? <String>[];
      return stored
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void clearAllCaches() => _invalidateCaches();

  Future<void> clearPersistedCaches() async {
    try {
      final prefs = await _ensurePrefs();
      await prefs.remove(_balancesStorageKey);
      await prefs.remove(_transactionsStorageKey);
      await prefs.remove(_recentAmountsStorageKey);
    } catch (_) {}
  }

  Future<ExpenseModel> createExpense({
    required String description,
    required int totalAmount,
    required List<String> participants,
    String category = 'other',
  }) async {
    final resolvedParticipants = participants
        .map((p) => PhoneUtils.normalizeRaw(p))
        .where((p) => p.isNotEmpty)
        .toList();
    developer.log(
        'ExpenseService: creating expense "$description" amount=$totalAmount participants=${resolvedParticipants.length}');
    final response = await _api.post(
      ApiConfig.expenses,
      data: {
        'description': description,
        'totalAmount': totalAmount,
        'participants': resolvedParticipants,
        'category': category,
      },
    );
    final model =
        ExpenseModel.fromJson(response.data['data'] as Map<String, dynamic>);
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
        final local = await _isarService.getAllExpenses();
        if (local.isNotEmpty) {
          local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _expensesCache = local;
          _expensesCacheAt = DateTime.now();
          return local;
        }
      } catch (e) {
        developer.log('Read local expenses error: $e');
      }
    }

    try {
      final response = await _api.get(ApiConfig.expenses);
      final expenses = response.data['data'] as List;
      developer.log(
        '[ExpenseService] /expenses raw data: ${jsonEncode(expenses)}',
        name: 'ExpenseService',
      );
      final parsed = expenses
          .map((json) => ExpenseModel.fromJson(json as Map<String, dynamic>))
          .toList();
      developer.log(
          '[ExpenseService] /expenses response: ${parsed.length} expenses',
          name: 'ExpenseService');
      developer.log('[ExpenseService] /expenses parsed data: $parsed',
          name: 'ExpenseService');
      await _isarService.batchUpsertExpenses(parsed);
      _expensesCache = parsed;
      _expensesCacheAt = DateTime.now();
      return parsed;
    } catch (e) {
      try {
        final local = await _isarService.getAllExpenses();
        if (local.isNotEmpty) {
          local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _expensesCache = local;
          _expensesCacheAt = DateTime.now();
          return local;
        }
      } catch (_) {}
      if (_expensesCache != null) return _expensesCache!;
      rethrow;
    }
  }

  Future<ExpenseModel> updateExpense({
    required String expenseId,
    String? description,
    int? totalAmount,
    String? category,
  }) async {
    final response = await _api.patch(
      ApiConfig.expenseById(expenseId),
      data: {
        if (description != null) 'description': description,
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (category != null) 'category': category,
      },
    );
    final model =
        ExpenseModel.fromJson(response.data['data'] as Map<String, dynamic>);
    await _isarService.upsertExpense(model);
    _invalidateCaches();
    _emitUpdate();
    return model;
  }

  Future<void> deleteExpense(String expenseId) async {
    final response = await _api.delete('${ApiConfig.expenses}/$expenseId');
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      await _isarService.upsertExpense(ExpenseModel.fromJson(data));
    }
    _invalidateCaches();
    _emitUpdate();
  }

  Future<void> createTransaction({
    String? toUserId,
    String? toPhone,
    required int amount,
  }) async {
    assert(toUserId != null || toPhone != null,
        'Either toUserId or toPhone required');
    final response = await _api.post(
      ApiConfig.transactions,
      data: {
        if (toUserId != null) 'toUser': toUserId,
        if (toPhone != null) 'toPhone': toPhone,
        'amount': amount,
      },
    );
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      final transaction = TransactionModel.fromJson(data);
      final existing =
          List<TransactionModel>.from(_transactionsCache ?? const []);
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

  Future<void> deleteTransaction(String transactionId) async {
    final response =
        await _api.delete(ApiConfig.transactionById(transactionId));
    final data = response.data['data'];
    final existing =
        List<TransactionModel>.from(_transactionsCache ?? const []);
    if (data is Map<String, dynamic>) {
      final updated = TransactionModel.fromJson(data);
      existing.removeWhere((t) => t.transactionId == updated.transactionId);
      existing.insert(0, updated);
    } else {
      final index =
          existing.indexWhere((t) => t.transactionId == transactionId);
      if (index != -1) {
        final prev = existing[index];
        existing[index] = TransactionModel(
          transactionId: prev.transactionId,
          fromUserId: prev.fromUserId,
          toUserId: prev.toUserId,
          toPhone: prev.toPhone,
          amount: prev.amount,
          createdAt: prev.createdAt,
          updatedAt: DateTime.now().toUtc(),
          relatedExpenseId: prev.relatedExpenseId,
          isDeleted: true,
          deletedBy: prev.deletedBy,
        );
      }
    }
    _transactionsCache = _dedupeTransactions(existing);
    _transactionsCacheAt = DateTime.now();
    unawaited(_persistTransactions(_transactionsCache!));
    _invalidateCaches();
    _emitUpdate();
  }

  Future<List<TransactionModel>> getTransactions(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _transactionsCache != null &&
        _isFresh(_transactionsCacheAt)) {
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
      developer.log(
          '[ExpenseService] /transactions response: ${parsed.length} transactions',
          name: 'ExpenseService');
      developer.log('[ExpenseService] /transactions data: $parsed',
          name: 'ExpenseService');
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

    if (forceRefresh) {
      if (_forceRefreshBalancesInFlight != null)
        return _forceRefreshBalancesInFlight!;
      final future = _fetchBalances(forceRefresh: true);
      _forceRefreshBalancesInFlight = future;
      try {
        return await future;
      } finally {
        if (identical(_forceRefreshBalancesInFlight, future))
          _forceRefreshBalancesInFlight = null;
      }
    }

    if (_forceRefreshBalancesInFlight != null)
      return _forceRefreshBalancesInFlight!;
    if (_balancesInFlight != null) return _balancesInFlight!;

    final future = _fetchBalances(forceRefresh: false);
    _balancesInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_balancesInFlight, future)) _balancesInFlight = null;
    }
  }

  Future<Map<String, dynamic>> _fetchBalances(
      {required bool forceRefresh}) async {
    final localFallback =
        (!forceRefresh) ? await _readPersistedBalances() : <String, dynamic>{};

    try {
      final response = await _api.get(ApiConfig.balances);
      final data = response.data['data'];

      if (data is Map<String, dynamic>) {
        if (data['owesMe'] is List || data['iOwe'] is List) {
          final normalized = <String, int>{};
          final contacts = <ContactModel>[];

          final owesMe = (data['owesMe'] as List?) ?? const [];
          for (final item in owesMe) {
            if (item is! Map<String, dynamic>) continue;
            final user = item['user'];
            final amount = (item['amount'] as num?) ?? 0;
            if (user is Map<String, dynamic>) {
              try {
                contacts.add(ContactModel.fromJson(user));
              } catch (_) {}
              final key =
                  (user['_id'] as String?) ?? (user['phoneNumber'] as String?);
              if (key != null && key.isNotEmpty) {
                normalized[key] = (normalized[key] ?? 0) + amount.round();
              }
            }
          }

          final iOwe = (data['iOwe'] as List?) ?? const [];
          for (final item in iOwe) {
            if (item is! Map<String, dynamic>) continue;
            final user = item['user'];
            final amount = (item['amount'] as num?) ?? 0;
            if (user is Map<String, dynamic>) {
              try {
                contacts.add(ContactModel.fromJson(user));
              } catch (_) {}
              final key =
                  (user['_id'] as String?) ?? (user['phoneNumber'] as String?);
              if (key != null && key.isNotEmpty) {
                normalized[key] = (normalized[key] ?? 0) - amount.round();
              }
            }
          }

          normalized.removeWhere((_, v) => v == 0);
          _balancesCache = normalized;
          _balancesCacheAt = DateTime.now();
          unawaited(_persistBalances(normalized));
          _balanceContactsCache = contacts;

          // Upsert balance contacts into Isar so they appear in contacts list
          if (contacts.isNotEmpty) {
            await _isarService.upsertBalanceContacts(contacts);
          }

          developer.log(
              '[ExpenseService] /balances response: owesMe=${owesMe.length}, iOwe=${iOwe.length}, contacts=${contacts.length}, normalized=${normalized.length} entries',
              name: 'ExpenseService');
          developer.log(
              '[ExpenseService] /balances data: owesMe=$owesMe, iOwe=$iOwe',
              name: 'ExpenseService');
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

  Future<RefreshResult> refreshAll() async {
    final failedSections = <String>[];
    Map<String, dynamic> balances = {};

    try {
      await getExpenses(forceRefresh: true);
    } catch (e) {
      failedSections.add('expenses');
      developer.log('Refresh expenses failed: $e');
    }

    try {
      await getTransactions(forceRefresh: true);
    } catch (e) {
      failedSections.add('transactions');
      developer.log('Refresh transactions failed: $e');
    }

    try {
      balances = await getBalances(forceRefresh: true);
    } catch (e) {
      failedSections.add('balances');
      developer.log('Refresh balances failed: $e');
    }

    _emitUpdate();
    return RefreshResult(
      failedSections: List.unmodifiable(failedSections),
      balances: balances,
    );
  }

  Future<TimelinePage> getTimeline({
    String? withUserId,
    String? withUserPhone,
    bool forceRefresh = false,
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    final safeLimit = limit < 1 ? 20 : limit;
    final cacheKey =
        'with:${(withUserId ?? 'all').trim()}:p:${(withUserPhone ?? '').trim()}:c:${(cursor ?? '').trim()}:l$safeLimit:s:${(search ?? '').trim()}';
    _evictTimedCacheEntries(
        _timelineCache, _timelineCacheAt, _maxTimelineCacheEntries);

    if (!forceRefresh &&
        _timelineCache.containsKey(cacheKey) &&
        _isFresh(_timelineCacheAt[cacheKey])) {
      return _timelineCache[cacheKey]!;
    }

    try {
      final qp = <String, dynamic>{'limit': safeLimit};
      if (withUserId != null && withUserId.trim().isNotEmpty)
        qp['withUserId'] = withUserId.trim();
      if (withUserPhone != null && withUserPhone.trim().isNotEmpty)
        qp['withUserPhone'] = withUserPhone.trim();
      if (cursor != null && cursor.trim().isNotEmpty)
        qp['cursor'] = cursor.trim();
      if (search != null && search.trim().isNotEmpty)
        qp['search'] = search.trim();

      developer.log(
        '[ExpenseService] GET ${ApiConfig.timeline} query=$qp',
        name: 'ExpenseService',
      );
      final response = await _api.get(ApiConfig.timeline, queryParameters: qp);
      developer.log(
        '[ExpenseService] timeline raw response=${response.data}',
        name: 'ExpenseService',
      );
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) {
        developer.log(
          '[ExpenseService] timeline response shape unexpected: ${data.runtimeType}',
          name: 'ExpenseService',
        );
        return const TimelinePage(items: [], nextCursor: null, hasMore: false);
      }

      final items = (data['items'] as List?) ?? const [];
      final parsed = items
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
          .cast<Map<String, dynamic>>();

      try {
        final transactionLookup = {
          for (final tx in await getTransactions(forceRefresh: false))
            tx.transactionId: tx,
        };
        for (final item in parsed) {
          if ((item['type'] as String?) != 'transaction') continue;
          if (item['counterparty'] != null) continue;

          final itemId =
              (item['id'] ?? item['transactionId'])?.toString() ?? '';
          final tx = transactionLookup[itemId];
          if (tx == null) continue;

          final counterparty = <String, dynamic>{};
          if (tx.toUserId.trim().isNotEmpty) {
            counterparty['_id'] = tx.toUserId;
          }
          if ((tx.toPhone ?? '').trim().isNotEmpty) {
            counterparty['phoneNumber'] = tx.toPhone!.trim();
          }
          if (counterparty.isNotEmpty) {
            item['counterparty'] = counterparty;
          }
        }
      } catch (e) {
        developer.log(
          '[ExpenseService] timeline enrichment skipped: $e',
          name: 'ExpenseService',
        );
      }

      try {
        final expenseLookup = {
          for (final expense in await getExpenses(forceRefresh: false))
            expense.uuid: expense,
        };
        for (final item in parsed) {
          if ((item['type'] as String?) != 'expense') continue;

          final itemId =
              (item['expenseId'] ?? item['id'] ?? item['uuid'])?.toString() ??
                  '';
          final expense = expenseLookup[itemId];
          if (expense == null) continue;

          if (expense.participants.isNotEmpty) {
            item['participantPhones'] = List<String>.from(expense.participants);
          }
          if (expense.paidBy.trim().isNotEmpty) {
            item['paidBy'] = expense.paidBy;
          }
        }
      } catch (e) {
        developer.log(
          '[ExpenseService] expense enrichment skipped: $e',
          name: 'ExpenseService',
        );
      }

      final nextCursor = (data['nextCursor'] ?? data['cursor'])?.toString();
      final hasMoreValue = data['hasMore'];
      final hasMore = hasMoreValue is bool
          ? hasMoreValue
          : (nextCursor != null && nextCursor.isNotEmpty)
              ? true
              : parsed.length >= safeLimit;

      developer.log(
        '[ExpenseService] timeline response items=${parsed.length} nextCursor=$nextCursor hasMore=$hasMore firstKeys=${parsed.isNotEmpty ? parsed.first.keys.take(12).toList() : const []}',
        name: 'ExpenseService',
      );

      final page = TimelinePage(
        items: parsed,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
      _storeTimelineCache(cacheKey, page);
      return page;
    } catch (e) {
      if (_timelineCache.containsKey(cacheKey)) {
        return _timelineCache[cacheKey]!;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getConversationByPhone(String phoneNumber,
      {bool forceRefresh = false}) async {
    final target = _canonicalPhone(phoneNumber);
    if (target.isEmpty) return [];
    final cacheKey = 'phone:$target';
    _evictTimedCacheEntries(
        _conversationCache, _conversationCacheAt, _maxConversationCacheEntries);

    if (!forceRefresh &&
        _conversationCache.containsKey(cacheKey) &&
        _isFresh(_conversationCacheAt[cacheKey])) {
      return _conversationCache[cacheKey]!;
    }

    final expenses = await getExpenses(forceRefresh: forceRefresh);
    final transactions = await getTransactions(forceRefresh: forceRefresh);
    final timeline = <Map<String, dynamic>>[];

    for (final expense in expenses) {
      final participantMatch =
          expense.participants.any((p) => _canonicalPhone(p) == target);
      final paidByMatch = _canonicalPhone(expense.paidBy) == target;
      if (!participantMatch && !paidByMatch) continue;

      final direction = paidByMatch ? 'they_paid' : 'you_paid';
      final splitCount = expense.participants.length + 1;
      final amount =
          splitCount > 0 ? (expense.amount ~/ splitCount) : expense.amount;

      timeline.add({
        'type': 'expense',
        'amount': amount,
        'signedAmount': direction == 'you_paid' ? amount : -amount,
        'direction': direction,
        'description': expense.description ?? 'Expense',
        'createdAt': expense.createdAt.toUtc().toIso8601String(),
      });
    }

    for (final tx in transactions) {
      if (_canonicalPhone(tx.toPhone ?? '') != target) continue;
      timeline.add({
        'type': 'transaction',
        'amount': tx.amount,
        'signedAmount': tx.amount,
        'direction': 'sent',
        'description': 'Sent payment',
        'createdAt': tx.createdAt.toUtc().toIso8601String(),
        'isDeleted': tx.isDeleted,
        'deletedBy': tx.deletedBy,
      });
    }

    timeline.sort((a, b) => DateTime.parse(b['createdAt'] as String)
        .compareTo(DateTime.parse(a['createdAt'] as String)));

    _storeConversationCache(cacheKey, timeline);
    return timeline;
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

class RefreshResult {
  final List<String> failedSections;
  final Map<String, dynamic> balances;

  const RefreshResult({
    required this.failedSections,
    this.balances = const {},
  });

  bool get hasFailures => failedSections.isNotEmpty;
  bool get allFailed => failedSections.length == 3;
}
