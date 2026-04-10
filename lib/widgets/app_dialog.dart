import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../constants/app_colors.dart';
import '../constants/app_shadows.dart';
import '../constants/app_text_styles.dart';
import '../utils/form_validation.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// 3. AppManualContactDialog
//    Reusable themed dialog for adding a contact manually by phone number
// ─────────────────────────────────────────────────────────────────────────────

class AppManualContactDialog extends StatefulWidget {
  final String initialCountryCode;

  const AppManualContactDialog({
    super.key,
    this.initialCountryCode = 'IN',
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    String initialCountryCode = 'IN',
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AppManualContactDialog(
        initialCountryCode: initialCountryCode,
      ),
    );
  }

  @override
  State<AppManualContactDialog> createState() => _AppManualContactDialogState();
}

class _AppManualContactDialogState extends State<AppManualContactDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _phoneNumber = '';
  String _selectedCountryCode = 'IN';
  bool _canSubmit = false;
  String? _errorMessage;
  late int _phoneMinDigits;
  late int _phoneMaxDigits;

  @override
  void initState() {
    super.initState();
    _selectedCountryCode = widget.initialCountryCode.toUpperCase();
    _phoneMinDigits =
        AppFormValidation.phoneMinDigitsForCountry(_selectedCountryCode);
    _phoneMaxDigits =
        AppFormValidation.phoneMaxDigitsForCountry(_selectedCountryCode);
    _nameController.addListener(_syncSubmitState);
    _phoneController.addListener(_syncSubmitState);
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncSubmitState);
    _phoneController.removeListener(_syncSubmitState);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncSubmitState() {
    final nextCanSubmit = _isValidForm();
    final shouldClearError = _errorMessage != null;
    if (!shouldClearError && nextCanSubmit == _canSubmit) return;
    setState(() {
      _canSubmit = nextCanSubmit;
      if (shouldClearError) {
        _errorMessage = null;
      }
    });
  }

  bool _isValidForm() {
    return AppFormValidation.validateName(
              _nameController.text,
              fieldLabel: 'Name',
            ) ==
            null &&
        AppFormValidation.validatePhoneForCountry(
              _phoneController.text,
              countryCode: _selectedCountryCode,
              fieldLabel: 'Phone number',
            ) ==
            null;
  }

  void _setError(String? message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  void _submit() {
    final nameError = AppFormValidation.validateName(
      _nameController.text,
      fieldLabel: 'Name',
    );
    if (nameError != null) {
      _setError(nameError);
      return;
    }

    final phoneError = AppFormValidation.validatePhoneForCountry(
      _phoneController.text,
      countryCode: _selectedCountryCode,
      fieldLabel: 'Phone number',
    );
    if (phoneError != null) {
      _setError(phoneError);
      return;
    }

    _setError(null);
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'phone': _phoneNumber.trim(),
    });
  }

  void _updateCountryConstraints(String countryCode) {
    final nextCountryCode = countryCode.toUpperCase();
    if (nextCountryCode == _selectedCountryCode) return;

    setState(() {
      _selectedCountryCode = nextCountryCode;
      _phoneMinDigits =
          AppFormValidation.phoneMinDigitsForCountry(_selectedCountryCode);
      _phoneMaxDigits =
          AppFormValidation.phoneMaxDigitsForCountry(_selectedCountryCode);
    });

    final digits = AppFormValidation.digitsOnly(_phoneController.text);
    if (digits.length > _phoneMaxDigits) {
      final trimmed = digits.substring(0, _phoneMaxDigits);
      _phoneController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    _syncSubmitState();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 20, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.background.withValues(alpha: 0.9),
      labelStyle: AppTextStyles.bodyMedium(context).copyWith(
        color: AppColors.textSecondary,
      ),
      hintStyle: AppTextStyles.bodyMedium(context).copyWith(
        color: AppColors.textTertiary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: AppColors.borderLight.withValues(alpha: 0.9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: AppColors.borderLight.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border:
                Border.all(color: AppColors.borderLight.withValues(alpha: 0.9)),
            boxShadow: AppShadows.cardElevated,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primary,
                            AppColors.secondaryLight,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add by phone number',
                                  style: AppTextStyles.titleLarge(context)
                                      .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Save someone even if they are not in your contacts list yet.',
                                  style:
                                      AppTextStyles.bodySmall(context).copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textCapitalization: TextCapitalization.words,
                            maxLength: AppFormValidation.nameMaxLength,
                            inputFormatters:
                                AppFormValidation.nameInputFormatters(),
                            decoration: _fieldDecoration(
                              context,
                              label: 'Full name',
                              hint: 'Enter contact name',
                              prefixIcon: Icons.badge_rounded,
                            ).copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 14),
                          IntlPhoneField(
                            initialCountryCode: widget.initialCountryCode,
                            controller: _phoneController,
                            disableLengthCheck: true,
                            keyboardType: TextInputType.phone,
                            inputFormatters:
                                AppFormValidation.phoneInputFormatters(
                              maxLength: _phoneMaxDigits,
                            ),
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              color: AppColors.textPrimary,
                            ),
                            dropdownTextStyle:
                                AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.textPrimary,
                            ),
                            onCountryChanged: (country) {
                              _updateCountryConstraints(country.code);
                            },
                            decoration: _fieldDecoration(
                              context,
                              label: 'Phone number',
                              hint: 'Enter phone number',
                              prefixIcon: Icons.call_rounded,
                            ),
                            onChanged: (phone) {
                              _phoneNumber = phone.completeNumber;
                              if (phone.countryISOCode.isNotEmpty) {
                                _updateCountryConstraints(phone.countryISOCode);
                              }
                              _setError(null);
                              _syncSubmitState();
                            },
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      AppColors.error.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                style:
                                    AppTextStyles.bodySmall(context).copyWith(
                                  color: AppColors.error,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Selected country: $_selectedCountryCode. Local number must be between $_phoneMinDigits and $_phoneMaxDigits digits.',
                                    style: AppTextStyles.bodySmall(context)
                                        .copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Cancel',
                                  isOutlined: true,
                                  textColor: AppColors.textSecondary,
                                  height: 48,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomButton(
                                  text: 'Add contact',
                                  icon: Icons.check_rounded,
                                  height: 48,
                                  backgroundColor: AppColors.primary,
                                  isDisabled: !_canSubmit,
                                  onPressed: _canSubmit ? _submit : null,
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
            ),
          ),
        ),
      ),
    );
  }
}

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
