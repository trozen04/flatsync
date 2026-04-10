import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../constants/app_dimensions.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/expense_service.dart';
import '../../services/isar_service.dart';
import '../../services/notification_service.dart';
import '../../services/app_preferences_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/form_validation.dart';
import '../shell/app_shell.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final String deliveryLabel;

  const OtpVerifyScreen({
    super.key,
    required this.phoneNumber,
    this.deliveryLabel = 'messages',
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _obscurePin = true;

  Future<void> _verify() async {
    final otpError = AppFormValidation.validateOtp(_otpController.text);
    if (otpError != null) {
      CustomSnackBar.show(context, message: otpError, isError: true);
      return;
    }

    final nameError = AppFormValidation.validateName(_nameController.text,
        fieldLabel: 'Name');
    if (nameError != null) {
      CustomSnackBar.show(context, message: nameError, isError: true);
      return;
    }

    final pinError = AppFormValidation.validatePin(_pinController.text);
    if (pinError != null) {
      CustomSnackBar.show(context, message: pinError, isError: true);
      return;
    }

    setState(() => _loading = true);

    final authService = context.read<AuthService>();
    final isar = context.read<IsarService>();
    final notificationService = context.read<NotificationService>();
    final preferences = context.read<AppPreferencesService>();
    final expenseService = context.read<ExpenseService>();
    final contactService = context.read<ContactService>();

    try {
      final user = await authService.verifySignupOtp(
        phoneNumber: widget.phoneNumber,
        otp: _otpController.text,
        name: _nameController.text,
        pin: _pinController.text,
      );

      await isar.replaceCurrentUser(user);

      await notificationService.syncTokenToServer();
      final permissionGranted =
          await notificationService.requestNotificationPermission();
      await preferences.setNotificationsEnabled(permissionGranted);
      await preferences.setNotificationPromptSeen(true);

      await authService.syncContactsOnLogin(
        expenseService: expenseService,
        contactService: contactService,
        isar: isar,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      }
    } catch (e) {
      developer.log('OTP verify error: $e');
      if (mounted) {
        final errorMsg =
            authService.getAuthErrorMessage(e, flow: AuthFlow.verifySignupOtp);
        CustomSnackBar.show(context, message: errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: const GradientAppBar(title: 'Verify Code'),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: AppDimensions.appMargin(context),
                    child: Column(
                      children: [
                        Text(
                          'Enter the code sent to your ${widget.deliveryLabel}.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        AppDimensions.h20(context),
                        TextField(
                          controller: _otpController,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters:
                              AppFormValidation.otpInputFormatters(),
                          maxLength: AppFormValidation.otpLength,
                        ),
                        AppDimensions.h20(context),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          maxLength: AppFormValidation.nameMaxLength,
                          inputFormatters:
                              AppFormValidation.nameInputFormatters(),
                        ),
                        AppDimensions.h20(context),
                        TextField(
                          controller: _pinController,
                          decoration: InputDecoration(
                            labelText: '4-digit PIN',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters:
                              AppFormValidation.pinInputFormatters(),
                          obscureText: _obscurePin,
                          maxLength: AppFormValidation.pinLength,
                        ),
                        AppDimensions.h30(context),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: 'Verify & Sign Up',
                            onPressed: _verify,
                            isLoading: _loading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
