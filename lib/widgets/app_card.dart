import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

enum AppCardType { elevated, outlined, filled }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardType type;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.type = AppCardType.elevated,
    this.onTap,
    this.padding,
    this.margin,
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? AppSpacing.cardPadding(context);
    final effectiveMargin = margin ?? EdgeInsets.only(
      bottom: AppSpacing.responsive(context, AppSpacing.sm),
    );
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(
      AppSpacing.responsive(context, 12),
    );

    Widget card = Container(
      margin: effectiveMargin,
      decoration: _getDecoration(context, effectiveBorderRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: Padding(
            padding: effectivePadding,
            child: child,
          ),
        ),
      ),
    );

    if (type == AppCardType.elevated && elevation != null) {
      card = Card(
        margin: effectiveMargin,
        elevation: elevation!,
        shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
        color: backgroundColor ?? AppColors.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: Padding(
            padding: effectivePadding,
            child: child,
          ),
        ),
      );
    }

    return card;
  }

  BoxDecoration _getDecoration(BuildContext context, BorderRadius borderRadius) {
    switch (type) {
      case AppCardType.elevated:
        return BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: AppSpacing.responsive(context, 8),
              offset: Offset(0, AppSpacing.responsive(context, 2)),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: AppSpacing.responsive(context, 4),
              offset: Offset(0, AppSpacing.responsive(context, 1)),
            ),
          ],
        );
      case AppCardType.outlined:
        return BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        );
      case AppCardType.filled:
        return BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceVariant,
          borderRadius: borderRadius,
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
    final effectivePadding = padding ?? AppSpacing.listItemPadding(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: effectivePadding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              AppSpacing.horizontalSpace(context, AppSpacing.md),
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
              AppSpacing.horizontalSpace(context, AppSpacing.md),
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
