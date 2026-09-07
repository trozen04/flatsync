import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_shadows.dart';
import '../constants/app_text_styles.dart';

/// Clean AppBar conforming to the app theme specification.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool showBackButton;
  final VoidCallback? onTitleTap;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.showBackButton = true,
    this.onTitleTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 1.0),
          ),
          boxShadow: AppShadows.appBar,
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.background,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          automaticallyImplyLeading: automaticallyImplyLeading,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: InkWell(
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: onTitleTap != null ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            highlightColor: onTitleTap != null ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.heading2(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (onTitleTap != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: actions,
        ),
      ),
    );
  }
}
