import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flatsync/services/isar_service.dart';
import 'package:flatsync/services/api_service.dart';
import 'package:flatsync/services/auth_service.dart';
import 'package:flatsync/services/app_preferences_service.dart';
import 'package:flatsync/services/biometric_auth_service.dart';
import 'package:flatsync/services/contact_service.dart';
import 'package:flatsync/services/expense_service.dart';
import 'package:flatsync/services/notification_service.dart';
import 'package:flatsync/services/interstitial_ad_service.dart';
import 'package:flatsync/bloc/contact_provider.dart';
import 'package:flatsync/screens/splash/splash_screen.dart';
import 'package:flatsync/constants/app_theme.dart';
import 'package:flatsync/routes/app_routes.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

// Background message handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _localNotifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

  // Create notification channel for Android
  const channel = AndroidNotificationChannel(
    'flatsync_channel',
    'FlatSync Notifications',
    description: 'Expense and transaction alerts',
    importance: Importance.high,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'flatsync_channel',
        'FlatSync Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Local notifications setup
  await _initLocalNotifications();

  // Foreground notification — show local notification when app is open
  FirebaseMessaging.onMessage.listen(_showLocalNotification);

  // Allow foreground notifications on iOS
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  final isarService = IsarService();
  await isarService.openDB();

  final apiService = ApiService();
  final authService = AuthService(apiService);
  final appPreferencesService = AppPreferencesService();
  await appPreferencesService.init();
  final biometricAuthService = BiometricAuthService();
  final contactService = ContactService(apiService);
  final expenseService = ExpenseService(apiService, isarService);
  final notificationService = NotificationService(apiService);
  final interstitialAdService = InterstitialAdService();

  await notificationService.preloadToken();
  if (appPreferencesService.notificationsEnabled && await authService.isLoggedIn()) {
    await notificationService.syncTokenToServer();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: isarService),
        Provider.value(value: apiService),
        Provider.value(value: authService),
        Provider.value(value: biometricAuthService),
        Provider.value(value: contactService),
        Provider.value(value: expenseService),
        Provider.value(value: notificationService),
        Provider.value(value: interstitialAdService),
        ChangeNotifierProvider.value(value: appPreferencesService),
        ChangeNotifierProvider(
          create: (_) => ContactProvider(isarService, contactService),
        ),
      ],
      child: const FlatSyncApp(),
    ),
  );
}

class FlatSyncApp extends StatelessWidget {
  const FlatSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitEasy',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routes: AppRoutes.routes,
      home: const SplashScreen(),
    );
  }
}

