class AppConstants {
  static const List<String> users = ['Bhoopendra', 'Anand', 'Naman', 'Varun'];
  
  /// Extract base username from "Username (DeviceName)" format
  static String getBaseUsername(String fullUsername) {
    final match = RegExp(r'^([^(]+)').firstMatch(fullUsername);
    return match?.group(1)?.trim() ?? fullUsername;
  }
  
  /// Check if a username belongs to one of the predefined users
  static bool isValidUser(String username) {
    final baseUsername = getBaseUsername(username);
    return users.contains(baseUsername);
  }
}