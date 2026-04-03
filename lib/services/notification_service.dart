import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/api_config.dart';
import 'api_service.dart';

/// Handles FCM token registration and device permission requests.
class NotificationService {
  final ApiService _api;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _cachedToken;
  bool _syncToServerEnabled = false;

  NotificationService(this._api);

  /// Prime the local token cache as early as possible.
  /// This does not talk to the backend.
  Future<void> preloadToken() async {
    try {
      await _refreshCachedToken();
    } catch (e) {
      developer.log('NotificationService: preloadToken error: $e',
          name: 'NotificationService');
    }
  }

  /// Call after login / signup or when notifications are enabled in profile.
  /// This sends the cached token to the backend first, then optionally asks for permission.
  Future<void> registerDevice({bool requestPermission = false}) async {
    try {
      await syncTokenToServer();

      if (requestPermission) {
        final granted = await requestNotificationPermission();
        if (!granted) {
          developer.log(
            'NotificationService: notification permission denied',
            name: 'NotificationService',
          );
          return;
        }
      }
    } catch (e) {
      developer.log('NotificationService: registerDevice error: $e',
          name: 'NotificationService');
    }
  }

  /// Send the current token to the backend without prompting for permission.
  Future<void> syncTokenToServer() async {
    await _refreshCachedToken();
    _syncToServerEnabled = true;

    if (_cachedToken != null) {
      await _sendToken(_cachedToken!);
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidPermission = await Permission.notification.request();
      return androidPermission.isGranted;
    }

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> hasNotificationPermission() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      developer.log('NotificationService: permission check error: $e',
          name: 'NotificationService');
      return false;
    }
  }

  /// Call on logout to stop receiving notifications on this device.
  Future<void> unregisterDevice() async {
    try {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _cachedToken = null;
      _syncToServerEnabled = false;
      await _api.patch(ApiConfig.usersFcmToken, data: {'fcmToken': null});
      await _fcm.deleteToken();
    } catch (e) {
      developer.log('NotificationService: unregisterDevice error: $e',
          name: 'NotificationService');
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
      developer.log('NotificationService: token registered',
          name: 'NotificationService');
    } catch (e) {
      developer.log('NotificationService: token send error: $e',
          name: 'NotificationService');
    }
  }

  Future<void> _refreshCachedToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      _cachedToken = token;
    }

    await _ensureTokenRefreshListener();
  }

  Future<void> _ensureTokenRefreshListener() async {
    if (_tokenRefreshSubscription != null) return;

    _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((token) {
      _cachedToken = token;
      if (_syncToServerEnabled) {
        _sendToken(token);
      }
    });
  }
}
