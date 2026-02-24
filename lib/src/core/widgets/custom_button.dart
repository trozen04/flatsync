import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isOutlined;
  final bool isLoading;
  final double? width;
  final double height;
  final Widget? child;
  final bool isDisabled;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.isOutlined = false,
    this.isLoading = false,
    this.width,
    this.height = 50,
    this.child,
    this.isDisabled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = isDisabled || isLoading || onPressed == null;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onPressed,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOutlined
                  ? Colors.transparent
                  : disabled
                      ? AppColors.borderColor.withOpacity(0.5)
                      : (backgroundColor ?? AppColors.primary),
              borderRadius: BorderRadius.circular(12),
              border: isOutlined
                  ? Border.all(
                      color: disabled
                          ? AppColors.borderColor
                          : (backgroundColor ?? AppColors.primary),
                      width: 2,
                    )
                  : null,
              boxShadow: isOutlined || disabled
                  ? []
                  : [
                      BoxShadow(
                        color: (backgroundColor ?? AppColors.primary).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : child ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            color: isOutlined
                                ? (textColor ?? AppColors.primary)
                                : (textColor ?? Colors.white),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: AppTextStyles.buttonText(context).copyWith(
                            color: isOutlined
                                ? (textColor ?? AppColors.primary)
                                : (textColor ?? Colors.white),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
