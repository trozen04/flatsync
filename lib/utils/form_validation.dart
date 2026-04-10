import 'package:intl_phone_field/countries.dart';
import 'package:flutter/services.dart';

class AppFormValidation {
  static const int nameMaxLength = 60;
  static const int phoneMinDigits = 4;
  static const int phoneMaxDigits = 15;
  static const int otpLength = 6;
  static const int pinLength = 4;

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static List<TextInputFormatter> nameInputFormatters({
    int maxLength = nameMaxLength,
  }) {
    return [
      LengthLimitingTextInputFormatter(maxLength),
    ];
  }

  static List<TextInputFormatter> phoneInputFormatters({
    int maxLength = phoneMaxDigits,
  }) {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(maxLength),
    ];
  }

  static List<TextInputFormatter> phoneInputFormattersForCountry(
    String countryCode, {
    int fallbackMaxLength = phoneMaxDigits,
  }) {
    return phoneInputFormatters(
      maxLength: phoneMaxDigitsForCountry(
        countryCode,
        fallbackMaxLength: fallbackMaxLength,
      ),
    );
  }

  static List<TextInputFormatter> otpInputFormatters({
    int length = otpLength,
  }) {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(length),
    ];
  }

  static List<TextInputFormatter> pinInputFormatters({
    int length = pinLength,
  }) {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(length),
    ];
  }

  static String? validateName(
    String? value, {
    String fieldLabel = 'Name',
    bool required = true,
    int maxLength = nameMaxLength,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? '$fieldLabel is required' : null;
    }
    if (text.length > maxLength) {
      return '$fieldLabel must be at most $maxLength characters';
    }
    return null;
  }

  static bool isValidPhoneDigits(
    String? value, {
    int minDigits = phoneMinDigits,
    int maxDigits = phoneMaxDigits,
  }) {
    final digits = digitsOnly(value ?? '');
    return digits.length >= minDigits && digits.length <= maxDigits;
  }

  static String? validatePhoneDigits(
    String? value, {
    String fieldLabel = 'Phone number',
    int minDigits = phoneMinDigits,
    int maxDigits = phoneMaxDigits,
  }) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return '$fieldLabel is required';
    }
    if (digits.length < minDigits || digits.length > maxDigits) {
      return '$fieldLabel must be between $minDigits and $maxDigits digits';
    }
    return null;
  }

  static int phoneMinDigitsForCountry(
    String countryCode, {
    int fallbackMinLength = phoneMinDigits,
  }) {
    final country = _countryByCode(countryCode);
    return country?.minLength ?? fallbackMinLength;
  }

  static int phoneMaxDigitsForCountry(
    String countryCode, {
    int fallbackMaxLength = phoneMaxDigits,
  }) {
    final country = _countryByCode(countryCode);
    return country?.maxLength ?? fallbackMaxLength;
  }

  static String? validatePhoneForCountry(
    String? value, {
    required String countryCode,
    String fieldLabel = 'Phone number',
    int fallbackMinLength = phoneMinDigits,
    int fallbackMaxLength = phoneMaxDigits,
  }) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return '$fieldLabel is required';
    }

    final minDigits = phoneMinDigitsForCountry(
      countryCode,
      fallbackMinLength: fallbackMinLength,
    );
    final maxDigits = phoneMaxDigitsForCountry(
      countryCode,
      fallbackMaxLength: fallbackMaxLength,
    );

    if (digits.length < minDigits || digits.length > maxDigits) {
      return '$fieldLabel must be between $minDigits and $maxDigits digits';
    }
    return null;
  }

  static String? validateOtp(
    String? value, {
    String fieldLabel = 'Code',
    int length = otpLength,
  }) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return '$fieldLabel is required';
    }
    if (digits.length != length) {
      return '$fieldLabel must be exactly $length digits';
    }
    return null;
  }

  static String? validatePin(
    String? value, {
    String fieldLabel = 'PIN',
    int length = pinLength,
  }) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return '$fieldLabel is required';
    }
    if (digits.length != length) {
      return '$fieldLabel must be exactly $length digits';
    }
    return null;
  }

  static dynamic _countryByCode(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final country in countries) {
      if (country.code.toUpperCase() == normalized) {
        return country;
      }
    }
    return null;
  }
}
