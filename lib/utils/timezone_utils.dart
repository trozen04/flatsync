import 'package:timezone/timezone.dart' as tz;

/// Utility to determine timezone from phone number and convert times
class TimezoneUtils {
  /// Get timezone location from phone number (country code)
  /// Currently supports common countries:
  /// +91 = India (IST)
  /// +1 = USA/Canada
  /// +44 = UK
  /// +86 = China
  /// +81 = Japan
  /// etc.
  static tz.Location getTimezoneFromPhone(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return tz.getLocation('Asia/Kolkata'); // Default to IST
    }

    // Extract country code
    String countryCode = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (countryCode.startsWith('+')) {
      countryCode = countryCode.substring(1);
    }

    // Map country codes to timezone
    final Map<String, String> countryCodeToTimezone = {
      '91': 'Asia/Kolkata', // India
      '1': 'America/New_York', // USA/Canada (default)
      '44': 'Europe/London', // UK
      '86': 'Asia/Shanghai', // China
      '81': 'Asia/Tokyo', // Japan
      '61': 'Australia/Sydney', // Australia
      '33': 'Europe/Paris', // France
      '49': 'Europe/Berlin', // Germany
      '39': 'Europe/Rome', // Italy
      '34': 'Europe/Madrid', // Spain
      '31': 'Europe/Amsterdam', // Netherlands
      '41': 'Europe/Zurich', // Switzerland
      '46': 'Europe/Stockholm', // Sweden
      '47': 'Europe/Oslo', // Norway
      '45': 'Europe/Copenhagen', // Denmark
      '358': 'Europe/Helsinki', // Finland
      '43': 'Europe/Vienna', // Austria
      '32': 'Europe/Brussels', // Belgium
      '353': 'Europe/Dublin', // Ireland
      '30': 'Europe/Athens', // Greece
      '36': 'Europe/Budapest', // Hungary
      '48': 'Europe/Warsaw', // Poland
      '55': 'America/Sao_Paulo', // Brazil
      '52': 'America/Mexico_City', // Mexico
      '56': 'America/Santiago', // Chile
      '54': 'America/Argentina/Buenos_Aires', // Argentina
      '27': 'Africa/Johannesburg', // South Africa
      '234': 'Africa/Lagos', // Nigeria
      '254': 'Africa/Nairobi', // Kenya
      '20': 'Africa/Cairo', // Egypt
      '966': 'Asia/Riyadh', // Saudi Arabia
      '971': 'Asia/Dubai', // UAE
      '36': 'Asia/Bangkok', // Thailand
      '62': 'Asia/Jakarta', // Indonesia
      '60': 'Asia/Kuala_Lumpur', // Malaysia
      '65': 'Asia/Singapore', // Singapore
    };

    final timezone = countryCodeToTimezone[countryCode] ?? 'Asia/Kolkata';
    try {
      return tz.getLocation(timezone);
    } catch (e) {
      return tz.getLocation('Asia/Kolkata'); // Fallback to IST
    }
  }

  /// Convert UTC datetime to user's timezone (based on phone number)
  static DateTime convertToUserTimezone(DateTime utcDateTime, String? phoneNumber) {
    try {
      final location = getTimezoneFromPhone(phoneNumber);
      // Assume utcDateTime is in UTC
      final utcTime = tz.TZDateTime.from(utcDateTime, tz.UTC);
      final convertedTime = utcTime.toLocal();
      // Create a new TZDateTime in the user's timezone
      final userTime = tz.TZDateTime(location, utcDateTime.year, utcDateTime.month,
          utcDateTime.day, utcDateTime.hour, utcDateTime.minute, utcDateTime.second);
      return DateTime(userTime.year, userTime.month, userTime.day, userTime.hour,
          userTime.minute, userTime.second);
    } catch (e) {
      // Fallback to original datetime if conversion fails
      return utcDateTime;
    }
  }

  /// Get country name from phone number
  static String getCountryFromPhone(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'India';
    }

    String countryCode = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (countryCode.startsWith('+')) {
      countryCode = countryCode.substring(1);
    }

    final Map<String, String> countryCodeToName = {
      '91': 'India',
      '1': 'USA/Canada',
      '44': 'UK',
      '86': 'China',
      '81': 'Japan',
      '61': 'Australia',
      '33': 'France',
      '49': 'Germany',
      '39': 'Italy',
      '34': 'Spain',
      '31': 'Netherlands',
      '41': 'Switzerland',
      '46': 'Sweden',
      '47': 'Norway',
      '45': 'Denmark',
      '358': 'Finland',
      '43': 'Austria',
      '32': 'Belgium',
      '353': 'Ireland',
      '30': 'Greece',
      '36': 'Hungary',
      '48': 'Poland',
      '55': 'Brazil',
      '52': 'Mexico',
      '56': 'Chile',
      '54': 'Argentina',
      '27': 'South Africa',
      '234': 'Nigeria',
      '254': 'Kenya',
      '20': 'Egypt',
      '966': 'Saudi Arabia',
      '971': 'UAE',
      '66': 'Thailand',
      '62': 'Indonesia',
      '60': 'Malaysia',
      '65': 'Singapore',
    };

    return countryCodeToName[countryCode] ?? 'India';
  }
}
