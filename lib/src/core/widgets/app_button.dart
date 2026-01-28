import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';

enum AppButtonType { primary, secondary, outline, text, danger }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle(context);
    final textStyle = _getTextStyle(context);
    final padding = _getPadding(context);

    Widget child = isLoading
        ? SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                type == AppButtonType.primary ? Colors.white : AppColors.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !isLoading) ...[
                Icon(icon, size: _getIconSize()),
                AppSpacing.horizontalSpace(context, AppSpacing.sm),
              ],
              Text(text, style: textStyle),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    switch (type) {
      case AppButtonType.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.outline:
        return OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.text:
        return TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.error.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle = AppTextStyles.button(context);
    switch (type) {
      case AppButtonType.primary:
      case AppButtonType.secondary:
      case AppButtonType.danger:
        return baseStyle.copyWith(color: Colors.white);
      case AppButtonType.outline:
      case AppButtonType.text:
        return baseStyle.copyWith(color: AppColors.primary);
    }
  }

  EdgeInsets _getPadding(BuildContext context) {
    switch (size) {
      case AppButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.responsive(context, AppSpacing.md),
          vertical: AppSpacing.responsive(context, AppSpacing.sm),
        );
      case AppButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.responsive(context, AppSpacing.lg),
          vertical: AppSpacing.responsive(context, AppSpacing.md),
        );
      case AppButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.responsive(context, AppSpacing.xl),
          vertical: AppSpacing.responsive(context, AppSpacing.lg),
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.large:
        return 20;
    }
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = _getIconSize();
    final padding = _getPadding(context);

    Widget button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      style: _getButtonStyle(context),
      padding: padding,
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    switch (type) {
      case AppButtonType.primary:
        return IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.secondary:
        return IconButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.outline:
        return IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.text:
        return IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
      case AppButtonType.danger:
        return IconButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.responsive(context, 8)),
          ),
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 18;
      case AppButtonSize.medium:
        return 22;
      case AppButtonSize.large:
        return 26;
    }
  }

  EdgeInsets _getPadding(BuildContext context) {
    switch (size) {
      case AppButtonSize.small:
        return EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.sm));
      case AppButtonSize.medium:
        return EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.md));
      case AppButtonSize.large:
        return EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.lg));
    }
  }
}