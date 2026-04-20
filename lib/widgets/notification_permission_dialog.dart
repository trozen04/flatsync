import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'custom_button.dart';

Future<bool?> showNotificationPermissionDialog(
  BuildContext context, {
  required bool alreadyEnabled,
}) {
  final title =
      alreadyEnabled ? 'Manage notifications' : 'Enable notifications';
  final body = alreadyEnabled
      ? 'Notifications are already on. You can review or change them from your phone settings.'
      : 'Get timely updates for expense changes, balance shifts, and payment reminders without opening the app all the time.';
  final primaryLabel = alreadyEnabled ? 'Open settings' : 'Enable now';
  final secondaryLabel = alreadyEnabled ? 'Close' : 'Not now';
  final accent = alreadyEnabled ? AppColors.success : AppColors.primary;
  final icon = alreadyEnabled
      ? Icons.notifications_active_rounded
      : Icons.notifications_none_rounded;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DragHandle(),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: alreadyEnabled
                            ? [AppColors.primaryDark, AppColors.primary]
                            : [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -16,
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -18,
                          bottom: -24,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style:
                                        AppTextStyles.titleLarge(sheetContext)
                                            .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    style:
                                        AppTextStyles.bodyMedium(sheetContext)
                                            .copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _PromptChip(label: 'Expense updates'),
                                      _PromptChip(label: 'Balance changes'),
                                      _PromptChip(label: 'Payment reminders'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Why SettleFlow asks',
                    style: AppTextStyles.titleMedium(sheetContext).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _BenefitRow(
                    icon: Icons.receipt_long_rounded,
                    title: 'Expense updates',
                    subtitle: 'See when someone adds or edits a split.',
                  ),
                  const SizedBox(height: 10),
                  const _BenefitRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Balance changes',
                    subtitle: 'Know when your running balance moves.',
                  ),
                  const SizedBox(height: 10),
                  const _BenefitRow(
                    icon: Icons.schedule_rounded,
                    title: 'Payment reminders',
                    subtitle: 'Get reminded before important follow-ups.',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'You can change this later from Profile > Notifications.',
                    style: AppTextStyles.bodySmall(sheetContext),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: primaryLabel,
                    icon: alreadyEnabled
                        ? Icons.settings_outlined
                        : Icons.notifications_active_rounded,
                    backgroundColor: accent,
                    onPressed: () => Navigator.pop(sheetContext, true),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;

  const _PromptChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall(context).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmall(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
