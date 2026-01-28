import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flatsync/src/services/notification_service.dart';
import 'package:flatsync/src/data/repositories/isar_service.dart';
import 'package:flatsync/src/data/repositories/expense_repository.dart';
import 'package:flatsync/src/services/sync/sync_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    // Create notification channel for background service
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const channel = AndroidNotificationChannel(
      'flatsync_bg',
      'FlatSync Background Service',
      description: 'Background service for expense syncing',
      importance: Importance.low,
      enableLights: false,
      enableVibration: false,
      showBadge: false,
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'flatsync_bg',
        initialNotificationTitle: 'FlatSync',
        initialNotificationContent: 'Ready',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
        autoStartOnBoot: true,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }
  
  @pragma('vm:entry-point')
  static Future<void> notifyAppState(bool isInForeground) async {
    try {
      final service = FlutterBackgroundService();
      if (isInForeground) {
        service.invoke('app_foreground');
      } else {
        service.invoke('app_background');
      }
    } catch (e) {
      developer.log('Error notifying app state: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    try {
      // Initialize services
      await IsarService.initialize();
      final repository = ExpenseRepository(IsarService());
      final syncService = SyncService(repository);
      await syncService.initialize();
      await syncService.startSyncServer();
      
      bool isAppInForeground = false;
      Timer? currentTimer;
      
      // Perform immediate sync on startup
      void performSync() async {
        if (service is AndroidServiceInstance) {
          try {
            if (await service.isForegroundService()) {
              final connectivity = await Connectivity().checkConnectivity();
              if (connectivity == ConnectivityResult.wifi) {
                final existingExpenses = await repository.getAllExpenses();
                final existingCount = existingExpenses.length;
                
                await syncService.performFullSync();
                
                // Check for new expenses after sync
                final newExpenses = await repository.getAllExpenses();
                final newCount = newExpenses.length;
                
                // Notification disabled - user doesn't want expense notifications
                // if (newCount > existingCount) {
                //   Get the newest expenses
                //   final newestExpenses = newExpenses.skip(existingCount).toList();
                //   final totalAmount = newestExpenses.fold<double>(0.0, (sum, expense) => sum + (expense.amount / 100.0));
                //   final userName = newestExpenses.isNotEmpty ? newestExpenses.first.paidBy : 'Flatmate';
                //   
                //   await NotificationService.showExpenseNotification(
                //     userName: userName,
                //     amount: totalAmount,
                //     description: newestExpenses.length == 1 
                //         ? newestExpenses.first.description 
                //         : '${newestExpenses.length} new expenses synced',
                //   );
                // }
                
                // Only show foreground notification when app is in background
                if (!isAppInForeground) {
                  final status = 'Background (60s)';
                  service.setForegroundNotificationInfo(
                    title: 'FlatSync $status',
                    content: 'Last sync: ${DateTime.now().toString().substring(11, 16)}',
                  );
                }
              } else {
                // Only show waiting notification when app is in background
                if (!isAppInForeground) {
                  service.setForegroundNotificationInfo(
                    title: 'FlatSync Waiting',
                    content: 'Waiting for WiFi connection',
                  );
                }
              }
            }
          } catch (e) {
            service.setForegroundNotificationInfo(
              title: 'FlatSync Error',
              content: 'Sync failed: ${e.toString()}',
            );
          }
        }
      }
      
      void updateSyncInterval() {
        currentTimer?.cancel();
        
        // 5 seconds if app is open, 60 seconds if in background
        final interval = isAppInForeground 
            ? const Duration(seconds: 5) 
            : const Duration(seconds: 60);
            
        developer.log('Setting sync interval to ${interval.inSeconds}s (foreground: $isAppInForeground)');
            
        currentTimer = Timer.periodic(interval, (timer) async {
          performSync();
        });
      }
      
      // Start with background interval initially
      updateSyncInterval();
      
      // Listen for app state changes
      service.on('app_foreground').listen((event) {
        developer.log('App moved to foreground - switching to 5s sync');
        isAppInForeground = true;
        updateSyncInterval();
      });
      
      service.on('app_background').listen((event) {
        developer.log('App moved to background - switching to 60s sync');
        isAppInForeground = false;
        updateSyncInterval();
      });

      service.on('stop').listen((event) {
        currentTimer?.cancel();
        service.stopSelf();
      });
    } catch (e) {
      // Fallback notification if service fails to initialize
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'FlatSync Error',
          content: 'Service failed to start: ${e.toString()}',
        );
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}