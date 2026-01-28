import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flatsync/src/data/models/expense_model.dart';

/// Queue system for offline sync
/// Stores pending changes when offline and syncs when connected
class SyncQueue {
  static const String _queueKey = 'sync_queue';
  static const String _lastSyncKey = 'last_sync_time';
  
  /// Add expense to sync queue for later sync
  static Future<void> addToQueue(ExpenseModel expense) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(queueJson);
    
    queue.add(expense.toJson());
    await prefs.setString(_queueKey, jsonEncode(queue));
  }
  
  /// Get all pending expenses from queue
  static Future<List<ExpenseModel>> getPendingExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(queueJson);
    
    return queue.map((json) => ExpenseModel.fromJson(json)).toList();
  }
  
  /// Clear sync queue after successful sync
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
  
  /// Update last sync time
  static Future<void> updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }
  
  /// Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastSyncKey);
    return timeStr != null ? DateTime.parse(timeStr) : null;
  }
  
  /// Check if there are pending changes
  static Future<bool> hasPendingChanges() async {
    final pending = await getPendingExpenses();
    return pending.isNotEmpty;
  }
}