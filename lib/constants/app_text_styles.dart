import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'app_colors.dart';

class AppTextStyles {
  static final TextStyle _baseStyle = GoogleFonts.inter();

  static TextStyle _style(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
    List<FontFeature>? features,
  }) {
    return _baseStyle.copyWith(
      fontSize: _responsiveSize(context, size),
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: features,
    );
  }

  static TextStyle _numericStyle(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
  }) {
    return _style(
      context,
      size: size,
      weight: weight,
      color: color,
      features: [const FontFeature.tabularFigures()],
    );
  }

  // Display styles
  static TextStyle displayLarge(BuildContext context) => _style(
        context,
        size: 57,
        weight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: -0.25,
      );

  static TextStyle displayMedium(BuildContext context) => _style(
        context,
        size: 45,
        weight: FontWeight.w400,
      );

  static TextStyle displaySmall(BuildContext context) => _style(
        context,
        size: 36,
        weight: FontWeight.w400,
      );

  // Headline styles
  static TextStyle headlineLarge(BuildContext context) => _style(
        context,
        size: 32,
        weight: FontWeight.w600,
      );

  static TextStyle headlineMedium(BuildContext context) => _style(
        context,
        size: 28,
        weight: FontWeight.w600,
      );

  static TextStyle headlineSmall(BuildContext context) => _style(
        context,
        size: 18,
        weight: FontWeight.w600,
      );

  // Title styles
  static TextStyle titleLarge(BuildContext context) => _style(
        context,
        size: 22,
        weight: FontWeight.w500,
      );

  static TextStyle titleMedium(BuildContext context) => _style(
        context,
        size: 16,
        weight: FontWeight.w800,
        letterSpacing: 0.15,
      );

  static TextStyle buttonText(BuildContext context) => _style(
        context,
        size: 16,
        weight: FontWeight.w500,
        color: Colors.white,
        letterSpacing: 0.15,
      );

  static TextStyle titleSmall(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
      );

  // Body styles
  static TextStyle bodyLarge(BuildContext context) => _style(
        context,
        size: 16,
        weight: FontWeight.w400,
        letterSpacing: 0.5,
      );

  static TextStyle bodyMedium(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.25,
      );

  static TextStyle bodySmall(BuildContext context) => _style(
        context,
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      );

  // Label styles
  static TextStyle labelLarge(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
      );

  static TextStyle labelMedium(BuildContext context) => _style(
        context,
        size: 12,
        weight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      );

  static TextStyle labelSmall(BuildContext context) => _style(
        context,
        size: 11,
        weight: FontWeight.w500,
        color: AppColors.textTertiary,
        letterSpacing: 0.5,
      );

  // Special styles
  static TextStyle button(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
      );

  static TextStyle caption(BuildContext context) => _style(
        context,
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textTertiary,
        letterSpacing: 0.4,
      );

  static TextStyle overline(BuildContext context) => _style(
        context,
        size: 10,
        weight: FontWeight.w500,
        color: AppColors.textTertiary,
        letterSpacing: 1.5,
      );

  // Currency/Number styles
  static TextStyle currency(BuildContext context) => _numericStyle(
        context,
        size: 18,
        weight: FontWeight.w600,
      );

  static TextStyle currencyLarge(BuildContext context) => _numericStyle(
        context,
        size: 24,
        weight: FontWeight.w700,
      );

  // Helper method for responsive font sizes
  static double _responsiveSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth < 360 ? 0.9 : screenWidth > 600 ? 1.1 : 1.0;
    return baseSize * scaleFactor;
  }
}
