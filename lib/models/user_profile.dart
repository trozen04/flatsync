import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  static const String _userNameKey = 'user_name';
  static String? _currentUserName;
  
  static String? get currentUserName => _currentUserName;
  
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserName = prefs.getString(_userNameKey);
  }
  
  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    _currentUserName = name;
  }

  static Future<void> clearUserName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userNameKey);
    _currentUserName = null;
  }

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUserName = null;
  }
  
  static bool get isSetupComplete => _currentUserName != null;
}
