int? parseRupeesToPaise(String input) {
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

  final paise = (whole * 100) + frac;
  if (paise <= 0) return null;
  return paise;
}

String formatPaise(int paise) {
  final rupees = paise.abs() / 100.0;
  return rupees.toStringAsFixed(2);
}
