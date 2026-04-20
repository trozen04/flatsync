class ApiConfig {
  // Environment-based configuration
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const String baseUrlOverride =
      String.fromEnvironment('FLATSYNC_API_BASE_URL');

  /// Production URL - UPDATE THIS WITH YOUR ACTUAL PRODUCTION URL
  // static const String productionUrl =
  //     'https://flatsync-backend.onrender.com/api';

  static const String productionUrl =
      'https://flatsyncbackend-production.up.railway.app/api';

  /// Development URL - Use your computer's IP address
  static const String developmentUrl = 'http://192.168.1.42:5000/api';

  // Auto-select based on build mode
  static String get baseUrl => baseUrlOverride.isNotEmpty
      ? baseUrlOverride
      : (isProduction ? productionUrl : developmentUrl);
  // static String get baseUrl => productionUrl;

  static const Duration timeout = Duration(seconds: 30);

  // Auth endpoints
  static const String sendOtp = '/auth/send-signup-otp';
  static const String verifyOtp = '/auth/verify-signup-otp';
  static const String sendResetPinOtp = '/auth/send-reset-pin-otp';
  static const String verifyResetPinOtp = '/auth/verify-reset-pin-otp';
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String me = '/auth/me';

  // User profile endpoints
  static const String usersMe = '/users/me';
  static const String usersFcmToken = '/users/me/fcm-token';

  // Contact endpoints
  static const String matchContacts = '/contacts/match';
  static String blockContact(String userId) => '/contacts/block/$userId';

  static const String expenses = '/expenses';
  static String expenseById(String id) => '/expenses/$id';

  // Transaction endpoints
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';

  // Balance endpoints
  static const String balances = '/balances';

  // Unified timeline endpoints (used for chat + history)
  static const String timeline = '/timeline';
}
