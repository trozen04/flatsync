import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'custom_button.dart';

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
                      padding: EdgeInsets.only(
                          bottom: i < fields.length - 1 ? 14 : 0),
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
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: accentColor, width: 1.5),
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

// ─────────────────────────────────────────────────────────────
// 3. AppSessionExpiredDialog
//    Use for: forced logout when the account is signed in elsewhere
// ─────────────────────────────────────────────────────────────

class AppSessionExpiredDialog extends StatelessWidget {
  final String message;

  const AppSessionExpiredDialog({
    super.key,
    required this.message,
  });

  static Future<void> show(
    BuildContext context, {
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppSessionExpiredDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.error.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phonelink_lock_rounded,
                    size: 30,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Session ended',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SessionDetailRow(
                          icon: Icons.security_rounded,
                          text:
                              'For your security, this device has been signed out.',
                        ),
                        SizedBox(height: 10),
                        _SessionDetailRow(
                          icon: Icons.login_rounded,
                          text: 'You can log in again with your PIN.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Log in again',
                          icon: Icons.login_rounded,
                          backgroundColor: AppColors.error,
                          onPressed: () => Navigator.pop(context),
                          height: 50,
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

class _SessionDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SessionDetailRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall(context).copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
