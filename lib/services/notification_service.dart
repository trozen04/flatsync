import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/api_config.dart';
import 'api_service.dart';

/// Handles FCM token registration and device permission requests.
class NotificationService {
  final ApiService _api;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  NotificationService(this._api);

  /// Call once after login / signup to register the device token.
  Future<void> registerDevice() async {
    try {
      // Request notification permission (iOS + Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        developer.log('NotificationService: permission denied', name: 'NotificationService');
        return;
      }

      final token = await _fcm.getToken();
      if (token != null) {
        await _sendToken(token);
      }

      // Keep token fresh when FCM rotates it
      _fcm.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      developer.log('NotificationService: registerDevice error: $e', name: 'NotificationService');
    }
  }

  /// Call on logout to stop receiving notifications on this device.
  Future<void> unregisterDevice() async {
    try {
      await _api.patch(ApiConfig.usersFcmToken, data: {'fcmToken': null});
      await _fcm.deleteToken();
    } catch (e) {
      developer.log('NotificationService: unregisterDevice error: $e', name: 'NotificationService');
    }
  }

  /// Request location permission — call from any screen that needs it.
  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<void> _sendToken(String token) async {
    try {
      await _api.patch(ApiConfig.usersFcmToken, data: {'fcmToken': token});
      developer.log('NotificationService: token registered', name: 'NotificationService');
    } catch (e) {
      developer.log('NotificationService: token send error: $e', name: 'NotificationService');
    }
  }
}
