import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static List<BoxShadow> get appBar => [
    BoxShadow(
      color: Colors.black.withOpacity(0.18),
      blurRadius: 14,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get cardElevated => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.25),
      blurRadius: 24,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 14,
      offset: const Offset(0, 5),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get navigation => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, -4),
      spreadRadius: 0,
    ),
  ];
}
