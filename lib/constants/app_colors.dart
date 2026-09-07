import 'package:flutter/material.dart';

class AppColors {
  // 1. Primary / Brand Red
  static const Color primary = Color(0xFFE11D48);
  static const Color primaryDark = Color(0xFFBE123C);
  static const Color primaryLight = Color(0xFFFB7185);

  // Secondary colors
  static const Color secondary = Color(0xFFE11D48);
  static const Color secondaryLight = Color(0xFFFDA4AF);
  static const Color secondaryDark = Color(0xFF9F1239);

  // Accent Gold / Amber
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color warning = Color(0xFFF59E0B);

  // Success / Veg Green
  static const Color success = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF15803D);
  static const Color primaryGreen = Color(0xFF16A34A);

  // App Background & Surface
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F4);
  static const Color surfaceVariant = Color(0xFFF5F5F4);
  static const Color cardPeach = Color(0xFFFFF5EE);

  // Input Field
  static const Color inputBackground = Color(0xFFFAF7F5);
  static const Color inputBorder = Color(0xFFE7E5E4);
  static const Color border = Color(0xFFE7E5E4);
  static const Color borderColor = Color(0xFFE7E5E4);
  static const Color borderLight = Color(0xFFE7E5E4);

  // Text Colors
  static const Color textPrimary = Color(0xFF1C1917);
  static const Color textSecondary = Color(0xFF78716C);
  static const Color textTertiary = Color(0xFFA8A29E);

  // Indicators & Status
  static const Color indicatorInactive = Color(0xFFFED7AA);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFFE11D48);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0C0A09);
  static const Color darkSurface = Color(0xFF1C1917);
  static const Color darkSurfaceVariant = Color(0xFF292524);
  static const Color darkTextPrimary = Color(0xFFFAFAF9);
  static const Color darkTextSecondary = Color(0xFFA8A29E);
  static const Color darkBorder = Color(0xFF44403C);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // App Bar Colors
  static const Color appBarStart = Color(0xFFFFFFFF);
  static const Color appBarEnd = Color(0xFFFFFFFF);
  static const Color appBarAccent = primary;

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [appBarStart, appBarEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
