import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class AppDialog extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? message;
  final List<Widget>? actions;
  final Widget? content;

  const AppDialog({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.message,
    this.actions,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.blue).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor ?? Colors.blue),
            ),
            AppSpacing.verticalSpace(context, 20),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (message != null) ...[
            AppSpacing.verticalSpace(context, 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
          if (content != null) ...[
            AppSpacing.verticalSpace(context, 16),
            content!,
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            AppSpacing.verticalSpace(context, 24),
            Row(
              children: List.generate(
                actions!.length * 2 - 1,
                (i) => i.isEven
                    ? Expanded(child: actions![i ~/ 2])
                    : AppSpacing.horizontalSpace(context, 12),
              ),
            ),
          ],
          AppSpacing.verticalSpace(context, 16),
        ],
      ),
    );
  }

  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    String? message,
    IconData? icon,
    Color? iconColor,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? Colors.red : null,
              foregroundColor: isDanger ? Colors.white : null,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
