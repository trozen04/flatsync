class ApiConfig {
  // For mobile device: Use your computer's IP address
  // Find IP: Windows (ipconfig) | Mac/Linux (ifconfig)
  static const String baseUrl = 'http://192.168.1.48:5000/api'; // Change to your IP
  
  // For emulator: Use 10.0.2.2
  // static const String baseUrl = 'http://10.0.2.2:5000/api';
  
  static const Duration timeout = Duration(seconds: 30);
  
  // Auth endpoints
  static const String sendOtp = '/auth/send-signup-otp';
  static const String verifyOtp = '/auth/verify-signup-otp';
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String me = '/auth/me';
  
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
}
