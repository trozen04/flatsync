import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

enum AppCardType { elevated, outlined, filled, glass }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardType type;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  // Optional accent shadow color (e.g. pass AppColors.success for green-tinted shadow)
  final Color? shadowColor;

  const AppCard({
    super.key,
    required this.child,
    this.type = AppCardType.elevated,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? AppDimensions.compactCardPadding(context);
    final effectiveMargin = margin ?? AppDimensions.compactCardMargin(context);
    final effectiveBorderRadius = borderRadius ??
        BorderRadius.circular(AppSpacing.responsive(context, 14));

    return Container(
      margin: effectiveMargin,
      decoration: _getDecoration(context, effectiveBorderRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: Padding(
            padding: effectivePadding,
            child: child,
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(BuildContext context, BorderRadius borderRadius) {
    final surface = Theme.of(context).colorScheme.surface;
    switch (type) {
      case AppCardType.elevated:
        return BoxDecoration(
          color: backgroundColor ?? surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: (backgroundColor != null && backgroundColor != surface)
                ? backgroundColor!.withValues(alpha: 0.25)
                : AppColors.borderLight,
            width: 1.0,
          ),
          boxShadow: shadowColor != null
              ? AppShadows.colored(shadowColor!)
              : AppShadows.card,
        );
      case AppCardType.outlined:
        return BoxDecoration(
          color: backgroundColor ?? surface,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: shadowColor != null
              ? AppShadows.colored(shadowColor!, intensity: 0.10)
              : AppShadows.subtle,
        );
      case AppCardType.filled:
        return BoxDecoration(
          color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.borderLight, width: 1.0),
          boxShadow: AppShadows.subtle,
        );
      case AppCardType.glass:
        return BoxDecoration(
          color: (backgroundColor ?? surface).withValues(alpha: 0.85),
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.60),
            width: 1.2,
          ),
          boxShadow: AppShadows.card,
        );
    }
  }
}

class AppListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool dense;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        (dense
            ? AppSpacing.listItemPadding(context).copyWith(
                top: AppSpacing.responsive(context, AppSpacing.xs),
                bottom: AppSpacing.responsive(context, AppSpacing.xs),
              )
            : AppSpacing.listItemPadding(context));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: effectivePadding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              AppSpacing.horizontalSpace(context, AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (subtitle != null) ...[
                    AppSpacing.verticalSpace(context, AppSpacing.xs),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              AppSpacing.horizontalSpace(context, AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppExpansionTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsets? padding;

  const AppExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.children,
    this.initiallyExpanded = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: AppCardType.outlined,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        initiallyExpanded: initiallyExpanded,
        tilePadding: padding ?? AppSpacing.listItemPadding(context),
        childrenPadding: EdgeInsets.only(
          left: AppSpacing.responsiveHorizontal(context),
          right: AppSpacing.responsiveHorizontal(context),
          bottom: AppSpacing.responsive(context, AppSpacing.md),
        ),
        children: children,
      ),
    );
  }
}
