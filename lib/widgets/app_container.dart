import 'package:flutter/material.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';
import '../constants/app_dimensions.dart';

class AppContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? radius;
  final List<BoxShadow>? shadows;
  final Border? border;
  final VoidCallback? onTap;

  const AppContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.radius,
    this.shadows,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin ?? AppDimensions.compactCardMargin(context),
      padding: padding ?? AppDimensions.containerPadding(context),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
          radius ?? AppSpacing.responsive(context, 16),
        ),
        border: border ?? Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: shadows ?? AppShadows.card,
      ),
      child: child,
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              radius ?? AppSpacing.responsive(context, 16),
            ),
            child: container,
          )
        : container;
  }
}
