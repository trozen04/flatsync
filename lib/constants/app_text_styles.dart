import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle _baseStyle = GoogleFonts.inter();

  // Display styles
  static TextStyle displayLarge(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 57),
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
  );

  static TextStyle displayMedium(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 45),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static TextStyle displaySmall(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 36),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // Headline styles
  static TextStyle headlineLarge(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 32),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static TextStyle headlineMedium(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 28),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static TextStyle headlineSmall(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 18),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // Title styles
  static TextStyle titleLarge(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 22),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static TextStyle titleMedium(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 16),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    color: AppColors.textPrimary,
  );
  static TextStyle buttonText(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 16),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    color: Colors.white,
  );

  static TextStyle titleSmall(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 14),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  // Body styles
  static TextStyle bodyLarge(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 16),
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 14),
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 12),
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
  );

  // Label styles
  static TextStyle labelLarge(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 14),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static TextStyle labelMedium(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 12),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSmall(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 11),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textTertiary,
  );

  // Special styles
  static TextStyle button(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 14),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle caption(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 12),
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: AppColors.textTertiary,
  );

  static TextStyle overline(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 10),
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.textTertiary,
  );

  // Currency/Number styles
  static TextStyle currency(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 18),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  static TextStyle currencyLarge(BuildContext context) => _baseStyle.copyWith(
    fontSize: _responsiveSize(context, 24),
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textPrimary,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  // Helper method for responsive font sizes
  static double _responsiveSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth < 360 ? 0.9 : screenWidth > 600 ? 1.1 : 1.0;
    return baseSize * scaleFactor;
  }
}
