import 'package:flutter/material.dart';

class AppColors {
  // Primary blue colors
  static const Color primary = Color(0xFF0E2B95);
  static const Color primaryLight = Color(0xFF1E3FBF);
  static const Color primaryDark = Color(0xFF0A1F6B);
  
  // Secondary colors
  static const Color secondary = Color(0xFF1A4FD6);
  static const Color secondaryLight = Color(0xFF2A5FE6);
  static const Color secondaryDark = Color(0xFF0D2F8A);
  
  // Background colors - cool tones
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8EBF0);
  
  // Text colors
  static const Color textPrimary = Color(0xFF0A1929);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);
  
  // Status colors
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0E2B95);
  
  // Border colors
  static const Color border = Color(0xFFD1D5DB);
  static const Color borderLight = Color(0xFFE5E7EB);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A1929);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkBorder = Color(0xFF475569);

  static const Color borderColor = Color(0xFFD1D5DB);
  static const Color primaryGreen = Color(0xFF059669);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceVariant],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}