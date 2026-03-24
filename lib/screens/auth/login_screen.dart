import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../services/auth_service.dart';
import '../../services/isar_service.dart';
import '../../services/notification_service.dart';
import '../../utils/custom_snackbar.dart';
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

  Future<void> _login() async {
    if (_phoneNumber.isEmpty || _pinController.text.isEmpty) {
      CustomSnackBar.show(context,
          message: 'Enter phone and PIN', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      developer.log('LoginScreen: login request ($_phoneNumber)', name: 'LoginScreen');
      final authService = context.read<AuthService>();
      final isar = context.read<IsarService>();
      final user = await authService.login(
        phoneNumber: _phoneNumber,
        pin: _pinController.text,
      );
      developer.log('LoginScreen: login response userId=${user.userId}', name: 'LoginScreen');

      await isar.replaceCurrentUser(user);

      await authService.syncContactsOnLogin(
        expenseService: context.read(),
        contactService: context.read(),
        isar: isar,
      );

      // Register FCM token and request location permission
      final notificationService = context.read<NotificationService>();
      await notificationService.registerDevice();
      await notificationService.requestLocationPermission();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (e) {
      developer.log('Login error: $e');
      if (mounted) {
        final errorMsg = context
            .read<AuthService>()
            .getAuthErrorMessage(e, flow: AuthFlow.login);
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
        body: SafeArea(
          child: Padding(
            padding: AppDimensions.appMargin(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SplitEasy',
                  style: AppTextStyles.displayMedium(context).copyWith(
                    fontWeight: FontWeight.bold
                  ),
                ),
                AppDimensions.h50(context),
                IntlPhoneField(
                  initialCountryCode: 'IN',
                  disableLengthCheck: false,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: (phone) {
                    final digits = phone.number.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length >= 6 && digits.length <= 15) {
                      _phoneNumber = phone.completeNumber;
                    }
                  },
                ),
                AppDimensions.h20(context),
                TextField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePin ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  obscureText: _obscurePin,
                  maxLength: 4,
                ),
                AppDimensions.h30(context),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Login',
                    onPressed: _login,
                    isLoading: _loading,
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
                            message: 'PIN reset successful. Please login.');
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
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  isOutlined: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

