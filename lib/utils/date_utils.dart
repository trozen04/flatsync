import 'package:intl/intl.dart';
import 'timezone_utils.dart';

/// Centralized date formatting utility for consistent date display across the app
class AppDateUtils {
  /// Standard date format: "31 Dec, 2026"
  static final DateFormat _dateFormat = DateFormat('d MMM, yyyy');
  
  /// Standard time format: "2:30 PM"
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  
  /// Short date format for compact displays: "31/12"
  static final DateFormat _shortDateFormat = DateFormat('d/M');
  
  /// Format date as "31 Dec, 2026"
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
  
  /// Format time as "2:30 PM"
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }
  
  /// Format date and time as "31 Dec, 2026 at 2:30 PM"
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }
  
  /// Format short date as "31/12"
  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Format date and time with timezone conversion based on phone number
  /// If no phone number provided, uses the date as-is
  static String formatDateTimeWithTimezone(DateTime date, String? phoneNumber) {
    final convertedDate = TimezoneUtils.convertToUserTimezone(date, phoneNumber);
    return formatDateTime(convertedDate);
  }

  /// Format time with timezone conversion
  static String formatTimeWithTimezone(DateTime date, String? phoneNumber) {
    final convertedDate = TimezoneUtils.convertToUserTimezone(date, phoneNumber);
    return formatTime(convertedDate);
  }

  /// Get relative time string like "just now", "5 mins ago", "2 hours ago", etc.
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

  /// Get relative time with timezone conversion
  static String formatRelativeTimeWithTimezone(DateTime dateTime, String? phoneNumber) {
    final convertedDate = TimezoneUtils.convertToUserTimezone(dateTime, phoneNumber);
    return formatRelativeTime(convertedDate);
  }
}

