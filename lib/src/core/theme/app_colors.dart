import 'package:flutter/material.dart';

class AppColors {
  // Primary brownish colors
  static const Color primary = Color(0xFF6B4423);
  static const Color primaryLight = Color(0xFF8B5A3C);
  static const Color primaryDark = Color(0xFF4A2C1A);
  
  // Secondary warm colors
  static const Color secondary = Color(0xFF9C6644);
  static const Color secondaryLight = Color(0xFFB8835A);
  static const Color secondaryDark = Color(0xFF7A4F35);
  
  // Background colors - warm tones
  static const Color background = Color(0xFFFAF8F5);
  static const Color surface = Color(0xFFFFFBF7);
  static const Color surfaceVariant = Color(0xFFF5EFE7);
  
  // Text colors - darker browns
  static const Color textPrimary = Color(0xFF2D1810);
  static const Color textSecondary = Color(0xFF6B4423);
  static const Color textTertiary = Color(0xFF9C6644);
  
  // Status colors - earthy tones
  static const Color success = Color(0xFF2D5016);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFF991B1B);
  static const Color info = Color(0xFF6B4423);
  
  // Border colors
  static const Color border = Color(0xFFE5D5C3);
  static const Color borderLight = Color(0xFFF0E6D8);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF1A0F08);
  static const Color darkSurface = Color(0xFF2D1810);
  static const Color darkSurfaceVariant = Color(0xFF3D2418);
  static const Color darkTextPrimary = Color(0xFFFAF8F5);
  static const Color darkTextSecondary = Color(0xFFD4C4B0);
  static const Color darkBorder = Color(0xFF4A2C1A);
  
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