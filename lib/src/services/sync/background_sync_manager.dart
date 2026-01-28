import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flatsync/src/services/sync/sync_service.dart';
import 'package:flatsync/src/services/sync/sync_queue.dart';

/// Background sync manager
/// Handles automatic sync when WiFi connects
class BackgroundSyncManager {
  static BackgroundSyncManager? _instance;
  static BackgroundSyncManager get instance => _instance ??= BackgroundSyncManager._();
  
  BackgroundSyncManager._();
  
  SyncService? _syncService;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _isAppInForeground = true;
  
  /// Initialize background sync
  Future<void> initialize(SyncService syncService) async {
    _syncService = syncService;
    
    // Perform initial sync on app start
    _attemptPeriodicSync();
    
    // Listen for WiFi connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi) {
        _onWiFiConnected();
      }
    });
    
    // Listen for app lifecycle changes
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == 'AppLifecycleState.resumed') {
        _isAppInForeground = true;
        _startPeriodicSync();
      } else if (message == 'AppLifecycleState.paused') {
        _isAppInForeground = false;
        _startPeriodicSync();
      }
      return null;
    });
    
    // Start periodic sync
    _startPeriodicSync();
  }
  
  /// Called when WiFi connects
  void _onWiFiConnected() async {
    if (_syncService == null) return;
    
    // Check if there are pending changes
    final hasPending = await SyncQueue.hasPendingChanges();
    if (hasPending) {
      developer.log('WiFi connected - attempting background sync...');
      try {
        await _syncService!.performFullSync();
      } catch (e) {
        developer.log('Background sync failed: $e');
      }
    }
  }
  
  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    
    // 5 seconds if app is open, 30 seconds if in background
    final interval = _isAppInForeground 
        ? const Duration(seconds: 5) 
        : const Duration(seconds: 30);
        
    _periodicSyncTimer = Timer.periodic(interval, (timer) {
      _attemptPeriodicSync();
    });
  }
  
  /// Attempt periodic sync if connected to WiFi
  void _attemptPeriodicSync() async {
    if (_syncService == null) return;
    
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.wifi) {
        await _syncService!.performFullSync();
      }
    } catch (e) {
      developer.log('Periodic sync failed: $e');
    }
  }
  
  /// Stop background sync
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }
}