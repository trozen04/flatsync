import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ─────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.13),
          blurRadius: 36,
          offset: const Offset(0, 10),
        ),
      ],
    );

Widget _dialogButton({
  required String label,
  required VoidCallback onTap,
  required Color bg,
  required Color fg,
  bool outlined = false,
}) =>
    SizedBox(
      height: 46,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
    );

// ─────────────────────────────────────────────
// 1. AppConfirmDialog
//    Use for: confirm, warn, danger, info prompts
// ─────────────────────────────────────────────

enum DialogVariant { info, warning, danger }

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final DialogVariant variant;
  final String confirmLabel;
  final String cancelLabel;

  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    required this.icon,
    this.variant = DialogVariant.info,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
  });

  Color get _accentColor => switch (variant) {
        DialogVariant.danger => AppColors.error,
        DialogVariant.warning => AppColors.warning,
        DialogVariant.info => AppColors.primary,
      };

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    required IconData icon,
    DialogVariant variant = DialogVariant.info,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AppConfirmDialog(
          title: title,
          message: message,
          icon: icon,
          variant: variant,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogButton(
                          label: cancelLabel,
                          onTap: () => Navigator.pop(context, false),
                          bg: Colors.transparent,
                          fg: AppColors.textSecondary,
                          outlined: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogButton(
                          label: confirmLabel,
                          onTap: () => Navigator.pop(context, true),
                          bg: color,
                          fg: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2. AppFormDialog
//    Use for: any dialog with input fields
// ─────────────────────────────────────────────

class AppFormField {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefix;
  final TextInputType keyboardType;
  final bool autofocus;

  const AppFormField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefix,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
  });
}

class AppFormDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color accentColor;
  final List<AppFormField> fields;
  final String confirmLabel;
  final String cancelLabel;
  final String? Function()? onConfirm; // return error string or null

  const AppFormDialog({
    super.key,
    required this.title,
    this.icon,
    this.accentColor = AppColors.primary,
    required this.fields,
    this.confirmLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            // Fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  ...fields.asMap().entries.map((entry) {
                    final i = entry.key;
                    final f = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < fields.length - 1 ? 14 : 0),
                      child: TextField(
                        controller: f.controller,
                        keyboardType: f.keyboardType,
                        autofocus: f.autofocus,
                        decoration: InputDecoration(
                          labelText: f.label,
                          hintText: f.hint,
                          prefixText: f.prefix,
                          filled: true,
                          fillColor: const Color(0xFFF8F9FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accentColor, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogButton(
                          label: cancelLabel,
                          onTap: () => Navigator.pop(context),
                          bg: Colors.transparent,
                          fg: AppColors.textSecondary,
                          outlined: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogButton(
                          label: confirmLabel,
                          onTap: () {
                            if (onConfirm != null) {
                              final err = onConfirm!();
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err)),
                                );
                                return;
                              }
                            }
                            Navigator.pop(context, true);
                          },
                          bg: accentColor,
                          fg: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
