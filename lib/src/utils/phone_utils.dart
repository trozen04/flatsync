class PhoneUtils {
  static String normalize(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    String digits = cleaned.replaceAll('+', '').replaceAll(RegExp(r'^91'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  static String canonical(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  static bool looksLikePhoneName(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }
}
