import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle _style(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
    double? height,
    List<FontFeature>? features,
  }) {
    return GoogleFonts.montserrat(
      fontSize: _responsiveSize(context, size),
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: features,
    );
  }

  static TextStyle _numericStyle(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
  }) {
    return _style(
      context,
      size: size,
      weight: weight,
      color: color,
      letterSpacing: letterSpacing,
      features: [const FontFeature.tabularFigures()],
    );
  }

  // Heading 1 - Size 22px | Bold (700) | Color #1C1917
  static TextStyle heading1(BuildContext context, {Color color = AppColors.textPrimary}) => _style(
        context,
        size: 22,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
      );

  // Heading 2 - Size 18px | Bold (700) | Color #1C1917
  static TextStyle heading2(BuildContext context, {Color color = AppColors.textPrimary}) => _style(
        context,
        size: 18,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: -0.1,
      );

  // Card Title - Size 15px | SemiBold (600) | Color #1C1917
  static TextStyle cardTitle(BuildContext context, {Color color = AppColors.textPrimary}) => _style(
        context,
        size: 15,
        weight: FontWeight.w600,
        color: color,
      );

  // Body Text - Size 13px | Regular (400) | Color #78716C
  static TextStyle body(BuildContext context, {Color color = AppColors.textSecondary}) => _style(
        context,
        size: 13,
        weight: FontWeight.w400,
        color: color,
        letterSpacing: 0.1,
      );

  // Body Bold - Size 13px | SemiBold (600) | Color #1C1917
  static TextStyle bodyBold(BuildContext context, {Color color = AppColors.textPrimary}) => _style(
        context,
        size: 13,
        weight: FontWeight.w600,
        color: color,
      );

  // Price Text - Size 14px | Bold (700) | Color #E11D48
  static TextStyle priceText(BuildContext context, {Color color = AppColors.primary}) => _numericStyle(
        context,
        size: 14,
        weight: FontWeight.w700,
        color: color,
      );

  // Small Badge - Size 11px | SemiBold (600) | Color #78716C / #FFFFFF
  static TextStyle smallBadge(BuildContext context, {Color color = AppColors.textSecondary}) => _style(
        context,
        size: 11,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: 0.2,
      );

  // Standard Material typography mappings
  static TextStyle displayLarge(BuildContext context) => _style(
        context,
        size: 32,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle displayMedium(BuildContext context) => _style(
        context,
        size: 28,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle displaySmall(BuildContext context) => _style(
        context,
        size: 24,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle headlineLarge(BuildContext context) => _style(
        context,
        size: 22,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle headlineMedium(BuildContext context) => _style(
        context,
        size: 18,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle headlineSmall(BuildContext context) => _style(
        context,
        size: 16,
        weight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle titleLarge(BuildContext context) => _style(
        context,
        size: 18,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle titleMedium(BuildContext context) => _style(
        context,
        size: 15,
        weight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle titleSmall(BuildContext context) => _style(
        context,
        size: 13,
        weight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle bodyLarge(BuildContext context) => _style(
        context,
        size: 15,
        weight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle bodyMedium(BuildContext context) => _style(
        context,
        size: 13,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle bodySmall(BuildContext context) => _style(
        context,
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle labelLarge(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle labelMedium(BuildContext context) => _style(
        context,
        size: 12,
        weight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle labelSmall(BuildContext context) => _style(
        context,
        size: 11,
        weight: FontWeight.w600,
        color: AppColors.textTertiary,
      );

  static TextStyle button(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle buttonText(BuildContext context) => _style(
        context,
        size: 14,
        weight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle caption(BuildContext context) => _style(
        context,
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle overline(BuildContext context) => _style(
        context,
        size: 10,
        weight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 1.0,
      );

  // Currency/Number styles
  static TextStyle currency(BuildContext context, {Color color = AppColors.textPrimary}) => _numericStyle(
        context,
        size: 16,
        weight: FontWeight.w700,
        color: color,
      );

  static TextStyle currencyLarge(BuildContext context, {Color color = AppColors.textPrimary}) => _numericStyle(
        context,
        size: 22,
        weight: FontWeight.w700,
        color: color,
      );

  // Responsive scale helper
  static double _responsiveSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth < 360 ? 0.92 : screenWidth > 600 ? 1.08 : 1.0;
    return baseSize * scaleFactor;
  }
}
