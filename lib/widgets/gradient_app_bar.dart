import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_shadows.dart';
import '../constants/app_text_styles.dart';

/// Clean AppBar conforming to the app theme specification.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool showBackButton;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.showBackButton = true,
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
          automaticallyImplyLeading: automaticallyImplyLeading,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: Row(
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
                  child: Text(
                    title,
                    style: AppTextStyles.heading2(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          actions: actions,
        ),
      ),
    );
  }
}
