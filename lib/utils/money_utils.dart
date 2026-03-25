import 'package:intl/intl.dart';

import '../constants/app_currencies.dart';

int? parseAmountToMinorUnits(
  String input, {
  String? currencyCode,
}) {
  var text = input.trim();
  if (text.isEmpty) return null;

  // Normalize common variants (commas, leading dot).
  text = text.replaceAll(',', '');
  if (text.startsWith('.')) text = '0$text';

  final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(text);
  if (match == null) return null;

  final wholePart = match.group(1) ?? '';
  final fracPart = match.group(2) ?? '';

  if (wholePart.isEmpty) return null;
  if (wholePart.length > 12) return null; // sanity limit

  final whole = int.tryParse(wholePart);
  if (whole == null) return null;

  int frac;
  if (fracPart.isEmpty) {
    frac = 0;
  } else if (fracPart.length == 1) {
    frac = int.parse(fracPart) * 10;
  } else if (fracPart.length == 2) {
    frac = int.parse(fracPart);
  } else {
    return null;
  }

  final minorUnits = (whole * 100) + frac;
  if (minorUnits <= 0) return null;
  return minorUnits;
}

int? parseRupeesToPaise(String input) {
  return parseAmountToMinorUnits(input, currencyCode: AppCurrencies.defaultCode);
}

String formatMinorUnits(
  int minorUnits, {
  String? currencyCode,
  bool absolute = false,
}) {
  final currency = AppCurrencies.byCode(currencyCode);
  final amount = (absolute ? minorUnits.abs() : minorUnits) / 100.0;
  final formatter = NumberFormat.currency(
    locale: currency.locale,
    symbol: currency.symbol,
    decimalDigits: currency.decimalDigits,
  );
  return formatter.format(amount);
}

String formatMinorUnitsValue(
  int minorUnits, {
  String? currencyCode,
  bool absolute = false,
}) {
  final currency = AppCurrencies.byCode(currencyCode);
  final amount = (absolute ? minorUnits.abs() : minorUnits) / 100.0;
  return amount.toStringAsFixed(currency.decimalDigits);
}

String formatPaise(int paise) {
  return formatMinorUnitsValue(paise, currencyCode: AppCurrencies.defaultCode);
}

