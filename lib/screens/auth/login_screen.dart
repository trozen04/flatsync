import 'package:flatsync/utils/image_assets.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/custom_button.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/expense_service.dart';
import '../../services/isar_service.dart';
import '../../services/notification_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/form_validation.dart';
import '../../widgets/gradient_app_bar.dart';
import '../shell/app_shell.dart';
import 'forgot_pin_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _phoneNumber = '';
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _obscurePin = true;
  DateTime? _lastLoginAttempt;
  static const _cooldown = Duration(seconds: 10);
  int _countdown = 0;
  bool _countdownActive = false;

  Future<void> _login() async {
    final phoneError = AppFormValidation.validatePhoneDigits(_phoneNumber);
    if (phoneError != null) {
      CustomSnackBar.show(context, message: phoneError, isError: true);
      return;
    }

    final pinError = AppFormValidation.validatePin(_pinController.text);
    if (pinError != null) {
      CustomSnackBar.show(context, message: pinError, isError: true);
      return;
    }

    final now = DateTime.now();
    if (_lastLoginAttempt != null &&
        now.difference(_lastLoginAttempt!) < _cooldown) {
      return;
    }
    _lastLoginAttempt = now;
    setState(() => _countdown = _cooldown.inSeconds);
    _startCountdown();

    setState(() => _loading = true);

    final authService = context.read<AuthService>();
    final isar = context.read<IsarService>();
    final notificationService = context.read<NotificationService>();
    final preferences = context.read<AppPreferencesService>();
    final expenseService = context.read<ExpenseService>();
    final contactService = context.read<ContactService>();

    try {
      developer.log('LoginScreen: login request ($_phoneNumber)',
          name: 'LoginScreen');
      final user = await authService.login(
        phoneNumber: _phoneNumber,
        pin: _pinController.text,
      );
      developer.log('LoginScreen: login response userId=${user.userId}',
          name: 'LoginScreen');

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (e) {
      developer.log('Login error: $e');
      if (mounted) {
        final errorMsg =
            authService.getAuthErrorMessage(e, flow: AuthFlow.login);
        CustomSnackBar.show(context, message: errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown() {
    if (_countdownActive || _countdown <= 0) return;
    _countdownActive = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) { _countdownActive = false; return false; }
      if (_countdown <= 1) {
        setState(() => _countdown = 0);
        _countdownActive = false;
        return false;
      }
      setState(() => _countdown--);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: const GradientAppBar(title: 'Welcome', showBackButton: false),
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
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        AppDimensions.h50(context),
                        Image.asset(
                          ImageAssets.nameIcon,
                          fit: BoxFit.cover,
                          height: AppDimensions.height(context) * 0.07,
                        ),
                        AppDimensions.h50(context),
                        IntlPhoneField(
                          initialCountryCode: 'IN',
                          disableLengthCheck: false,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters:
                              AppFormValidation.phoneInputFormatters(),
                          onCountryChanged: (country) {
                            context
                                .read<AppPreferencesService>()
                                .autoSetCurrencyFromCountry(country.code);
                          },
                          onChanged: (phone) {
                            _phoneNumber = AppFormValidation.isValidPhoneDigits(
                                    phone.number)
                                ? phone.completeNumber
                                : '';
                            context
                                .read<AppPreferencesService>()
                                .autoSetCurrencyFromCountry(
                                    phone.countryISOCode);
                          },
                        ),
                        AppDimensions.h20(context),
                        TextField(
                          controller: _pinController,
                          decoration: InputDecoration(
                            labelText: 'PIN',
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
                            text: _countdown > 0
                                ? 'Wait $_countdown seconds'
                                : 'Login',
                            onPressed: _countdown > 0 ? null : _login,
                            isLoading: _loading,
                            isDisabled: _countdown > 0,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              final resetDone = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ForgotPinScreen()),
                              );
                              if (!context.mounted) return;
                              if (resetDone == true) {
                                CustomSnackBar.show(context,
                                    message:
                                        'PIN reset successful. Please login.');
                              }
                            },
                            child: Text(
                              'Forgot PIN?',
                              style: AppTextStyles.bodyMedium(context),
                            ),
                          ),
                        ),
                        AppDimensions.h20(context),
                        CustomButton(
                          text: 'New user? Sign Up',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          ),
                          isOutlined: true,
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
