import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static List<BoxShadow> get appBar => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.20),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Standard card — soft lift with a tinted base
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Elevated card — deeper, more dramatic
  static List<BoxShadow> get cardElevated => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.28),
      blurRadius: 32,
      offset: const Offset(0, 14),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // Subtle — barely-there lift for outlined cards
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  // Colored shadow — pass any accent color
  static List<BoxShadow> colored(Color color, {double intensity = 0.30}) => [
    BoxShadow(
      color: color.withValues(alpha: intensity),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get navigation => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.22),
      blurRadius: 24,
      offset: const Offset(0, -6),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];
}

