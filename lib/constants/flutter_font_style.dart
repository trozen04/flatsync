import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class FlutterFontStyle {
  static const String family = 'Montserrat';

  static TextStyle textStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
    double? height,
    List<FontFeature>? fontFeatures,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.montserrat(
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
