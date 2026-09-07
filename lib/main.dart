import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flatsync/constants/app_colors.dart';
import 'package:flatsync/models/contact_model.dart';
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
import 'package:flatsync/screens/auth/login_screen.dart';
import 'package:flatsync/screens/contacts/conversation_screen.dart';
import 'package:flatsync/constants/app_theme.dart';
import 'package:flatsync/routes/app_routes.dart';
import 'package:flatsync/widgets/app_dialog.dart';
import 'package:flatsync/utils/money_utils.dart';
import 'package:flatsync/utils/phone_utils.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

// Background message handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void _handleNotificationPayloadNavigation(Map<String, dynamic> data) async {
  final senderPhone = (data['senderPhone'] as String?)?.trim() ?? '';
  final senderId = (data['senderId'] as String?)?.trim() ?? '';
  final senderName = (data['senderName'] as String?)?.trim() ?? '';

  if (senderPhone.isEmpty && senderId.isEmpty) return;

  final navigator = _rootNavigatorKey.currentState;
  if (navigator == null) return;

  ContactModel? contact;
  try {
    final isar = navigator.context.read<IsarService>();
    final all =
        await isar.isar.contactModels.filter().idGreaterThan(-1).findAll();
    for (final c in all) {
      if (senderPhone.isNotEmpty &&
          PhoneUtils.canonical(c.phoneNumber ?? '') ==
              PhoneUtils.canonical(senderPhone)) {
        contact = c;
        break;
      }
      if (senderId.isNotEmpty && c.contactId == senderId) {
        contact = c;
        break;
      }
    }
  } catch (_) {}

  contact ??= ContactModel(
    contactId: senderId.isNotEmpty ? senderId : null,
    phoneNumber: senderPhone.isNotEmpty ? senderPhone : null,
    name: senderName.isNotEmpty
        ? senderName
        : (senderPhone.isNotEmpty ? senderPhone : 'Contact'),
    isRegistered: true,
  );

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ConversationScreen(contact: contact!),
    ),
  );
}

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _localNotifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleNotificationPayloadNavigation(data);
        } catch (_) {}
      }
    },
  );

  // Create high importance notification channel for Android heads-up popup
  const channel = AndroidNotificationChannel(
    'flatsync_channel',
    'FairChop Notifications',
    description: 'Expense and transaction alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  // Format amount with user's preferred currency if available
  String? body = notification.body;
  final amountStr = message.data['amount'];
  if (amountStr != null) {
    final amountInt = int.tryParse(amountStr);
    if (amountInt != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currencyCode =
            prefs.getString('preferred_currency_code_v1') ?? 'INR';
        final formatted =
            formatMinorUnits(amountInt, currencyCode: currencyCode);
        body = body?.replaceFirst(RegExp(r'\d+\.\d+'), formatted) ?? body;
      } catch (_) {}
    }
  }

  await _localNotifications.show(
    notification.hashCode,
    notification.title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'flatsync_channel',
        'FairChop Notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

Future<void> _showSessionInvalidatedPopup(
  NavigatorState navigator,
  String message,
) {
  return AppSessionExpiredDialog.show(
    navigator.context,
    message: message,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
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

  // When notification is clicked from background state
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationPayloadNavigation(message.data);
  });

  // When notification is clicked from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null && message.data.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 700), () {
          _handleNotificationPayloadNavigation(message.data);
        });
      });
    }
  });

  final isarService = IsarService();
  await isarService.openDB();

  final apiService = ApiService();
  // Ping health check early to wake up server
  unawaited(apiService.pingHealth());

  final authService = AuthService(apiService);
  final appPreferencesService = AppPreferencesService();
  await appPreferencesService.init();
  final biometricAuthService = BiometricAuthService();
  final contactService = ContactService(apiService);
  final expenseService = ExpenseService(apiService, isarService);
  final notificationService = NotificationService(apiService);
  final interstitialAdService = InterstitialAdService();

  await notificationService.preloadToken();
  if (await authService.isLoggedIn()) {
    await notificationService.syncTokenToServer();
  }

  apiService.sessionInvalidated.listen((message) async {
    final navigator = _rootNavigatorKey.currentState;
    if (navigator == null) return;
    await _showSessionInvalidatedPopup(navigator, message);

    await authService.logout(
      expenseService: expenseService,
      isar: isarService,
    );

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  });

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
      title: 'FairChop',
      navigatorKey: _rootNavigatorKey,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routes: AppRoutes.routes,
      home: const SplashScreen(),
    );
  }
}
