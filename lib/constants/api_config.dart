class ApiConfig {
  // Environment-based configuration
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  // Production URL - UPDATE THIS WITH YOUR ACTUAL PRODUCTION URL
  static const String productionUrl =
      'https://flatsync-backend.onrender.com/api';

  // Development URL - Use your computer's IP address
  static const String developmentUrl = 'http://192.168.0.51:5000/api';

  // Auto-select based on build mode
  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

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

  // Contact endpoints
  static const String matchContacts = '/contacts/match';

  // Expense endpoints
  static const String expenses = '/expenses';

  // Transaction endpoints
  static const String transactions = '/transactions';

  // Balance endpoints
  static const String balances = '/balances';

  // Conversation endpoints
  static const String conversations = '/conversations';

  // Unified timeline endpoints (used for chat + history)
  static const String timeline = '/timeline';
}

