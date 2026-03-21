import 'package:intl/intl.dart';

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
}

