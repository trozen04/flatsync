import 'package:intl/intl.dart';

/// Centralized date formatting utility for consistent date display across the app
class AppDateUtils {
  /// Standard date format: "31 Dec, 2026"
  static final DateFormat _dateFormat = DateFormat('d MMM, yyyy');
  
  /// Standard time format: "2:30 PM"
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  
  /// Short date format for compact displays: "31/12"
  static final DateFormat _shortDateFormat = DateFormat('d/M');

  /// Convert a stored timestamp into the device's current local timezone.
  static DateTime _localDateTime(DateTime date) {
    return date.isUtc ? date.toLocal() : date;
  }
  
  /// Format date as "31 Dec, 2026"
  static String formatDate(DateTime date) {
    return _dateFormat.format(_localDateTime(date));
  }
  
  /// Format time as "2:30 PM"
  static String formatTime(DateTime date) {
    return _timeFormat.format(_localDateTime(date));
  }
  
  /// Format date and time as "31 Dec, 2026 at 2:30 PM"
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }
  
  /// Format short date as "31/12"
  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(_localDateTime(date));
  }

  /// Format date and time in the device's local timezone.
  static String formatDateTimeWithTimezone(DateTime date, String? phoneNumber) {
    return formatDateTime(date);
  }

  /// Format time in the device's local timezone.
  static String formatTimeWithTimezone(DateTime date, String? phoneNumber) {
    return formatTime(date);
  }

  /// Get relative time string like "just now", "5 mins ago", "2 hours ago", etc.
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(_localDateTime(dateTime));

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes min${minutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Get relative time in the device's local timezone.
  static String formatRelativeTimeWithTimezone(DateTime dateTime, String? phoneNumber) {
    return formatRelativeTime(dateTime);
  }
}
