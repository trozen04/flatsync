import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing values
  static const double _baseUnit = 4.0;
  
  // Fixed spacing values
  static const double xs = _baseUnit * 1; // 4
  static const double sm = _baseUnit * 2; // 8
  static const double md = _baseUnit * 3; // 12
  static const double lg = _baseUnit * 4; // 16
  static const double xl = _baseUnit * 5; // 20
  static const double xxl = _baseUnit * 6; // 24
  static const double xxxl = _baseUnit * 8; // 32
  static const double huge = _baseUnit * 12; // 48
  
  // Responsive spacing methods
  static double responsive(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return baseSize * 0.8;
    if (screenWidth > 600) return baseSize * 1.2;
    return baseSize;
  }
  
  static double responsiveHorizontal(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return lg;
    if (screenWidth > 600) return xxxl;
    return xl;
  }
  
  static double responsiveVertical(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return md;
    if (screenHeight > 800) return xl;
    return lg;
  }
  
  // Screen-aware padding
  static EdgeInsets screenPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: responsiveHorizontal(context),
      vertical: responsiveVertical(context),
    );
  }
  
  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.all(responsive(context, lg));
  }
  
  static EdgeInsets listItemPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: responsiveHorizontal(context),
      vertical: responsive(context, md),
    );
  }
  
  static EdgeInsets buttonPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: responsive(context, xxl),
      vertical: responsive(context, md),
    );
  }
  
  static EdgeInsets inputPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: responsive(context, lg),
      vertical: responsive(context, md),
    );
  }
  
  // SizedBox helpers
  static Widget verticalSpace(BuildContext context, double size) {
    return SizedBox(height: responsive(context, size));
  }
  
  static Widget horizontalSpace(BuildContext context, double size) {
    return SizedBox(width: responsive(context, size));
  }
  
  // Common spacing widgets
  static Widget get verticalSpaceXS => const SizedBox(height: xs);
  static Widget get verticalSpaceSM => const SizedBox(height: sm);
  static Widget get verticalSpaceMD => const SizedBox(height: md);
  static Widget get verticalSpaceLG => const SizedBox(height: lg);
  static Widget get verticalSpaceXL => const SizedBox(height: xl);
  static Widget get verticalSpaceXXL => const SizedBox(height: xxl);
  static Widget get verticalSpaceXXXL => const SizedBox(height: xxxl);
  
  static Widget get horizontalSpaceXS => const SizedBox(width: xs);
  static Widget get horizontalSpaceSM => const SizedBox(width: sm);
  static Widget get horizontalSpaceMD => const SizedBox(width: md);
  static Widget get horizontalSpaceLG => const SizedBox(width: lg);
  static Widget get horizontalSpaceXL => const SizedBox(width: xl);
  static Widget get horizontalSpaceXXL => const SizedBox(width: xxl);
  static Widget get horizontalSpaceXXXL => const SizedBox(width: xxxl);
  
  // Responsive spacing widgets
  static Widget responsiveVerticalSpace(BuildContext context, double size) {
    return SizedBox(height: responsive(context, size));
  }
  
  static Widget responsiveHorizontalSpace(BuildContext context, double size) {
    return SizedBox(width: responsive(context, size));
  }
}
