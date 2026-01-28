import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    // Request notification permission first (only in main app context)
    try {
      await Permission.notification.request();
    } catch (e) {
      developer.log('Could not request notification permission: $e');
    }
    
    if (!_initialized) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap - this will bring app to foreground
        },
      );
      _initialized = true;
    }
  }

  static Future<void> showExpenseNotification({
    required String userName,
    required double amount,
    String? description,
  }) async {
    try {
      await initialize();

      const androidDetails = AndroidNotificationDetails(
        'expense_channel',
        'Expense Notifications',
        channelDescription: 'Notifications for new expenses',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final title = 'New Expense Added';
      final body = '$userName added ₹${amount.toStringAsFixed(2)}${description != null ? ' - $description' : ''}';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      developer.log('Failed to show expense notification: $e');
    }
  }

  static Future<void> showSyncNotification(String message) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'Sync Status',
      channelDescription: 'Background sync status notifications',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      999, // Fixed ID for sync notification
      'FlatSync Running',
      message,
      details,
    );
  }

  static Future<void> cancelSyncNotification() async {
    await _notifications.cancel(999);
  }
}