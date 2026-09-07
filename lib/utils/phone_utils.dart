class PhoneUtils {
  /// Strips non-digits and normalizes to standard +countrycode format (e.g. +91XXXXXXXXXX).
  static String normalizeRaw(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // Standard 10-digit Indian mobile number -> +91XXXXXXXXXX
    if (digits.length == 10) return '+91$digits';
    // 11-digit with leading 0 (e.g. 09876543210) -> +91XXXXXXXXXX
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    }
    // 12-digit starting with 91 -> +91XXXXXXXXXX
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    if (trimmed.startsWith('+')) return '+$digits';
    return '+$digits';
  }

  /// For matching/dedup only — returns last 10 digits (works for IN + most countries).
  /// Use this ONLY for comparing two numbers, never for storage or API calls.
  static String canonical(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Returns true if two phone numbers refer to the same subscriber.
  /// Compares last 10 digits — safe for international numbers.
  static bool isSameNumber(String? a, String? b) {
    if (a == null || b == null) return false;
    final ca = canonical(a);
    final cb = canonical(b);
    return ca.isNotEmpty && cb.isNotEmpty && ca == cb;
  }

  /// For display — returns as-is (backend already stores +countrycode format).
  static String display(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    return phone.trim();
  }

  /// Old normalize — kept for legacy callers, prefer normalizeRaw.
  static String normalize(String phone) => normalizeRaw(phone);

  static bool looksLikePhoneName(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }
}
