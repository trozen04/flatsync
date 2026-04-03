import 'package:flutter/material.dart';

import 'app_colors.dart';

class FlutterFontStyle {
  static const String family = 'Poppins';

  static TextStyle textStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
    double? height,
    List<FontFeature>? fontFeatures,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
      fontStyle: fontStyle,
    );
  }
}
