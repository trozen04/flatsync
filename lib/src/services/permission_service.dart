import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request background service permissions
  /// Returns true if granted, false if denied
  static Future<bool> requestBackgroundPermissions() async {
    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    
    // For Android 12+ (API 31+), request exact alarm permission for background tasks
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    
    // Check if permissions are granted
    final notificationGranted = notificationStatus == PermissionStatus.granted;
    final alarmGranted = alarmStatus == PermissionStatus.granted || 
                        alarmStatus == PermissionStatus.permanentlyDenied; // Some devices don't need this
    
    return notificationGranted && alarmGranted;
  }
  
  /// Check if background permissions are already granted
  static Future<bool> hasBackgroundPermissions() async {
    final notificationStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    
    final notificationGranted = notificationStatus == PermissionStatus.granted;
    final alarmGranted = alarmStatus == PermissionStatus.granted || 
                        alarmStatus == PermissionStatus.permanentlyDenied;
    
    return notificationGranted && alarmGranted;
  }
}