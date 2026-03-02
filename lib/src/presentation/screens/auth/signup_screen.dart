import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../utils/custom_snackbar.dart';
import 'otp_verify_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static DateTime? _lastOtpRequest;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _phoneNumber = '';
  bool _loading = false;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
  }

  void _updateCountdown() {
    if (SignupScreen._lastOtpRequest != null) {
      final elapsed = DateTime.now().difference(SignupScreen._lastOtpRequest!).inSeconds;
      final remaining = 10 - elapsed;
      if (remaining > 0) {
        setState(() => _countdown = remaining);
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber.isEmpty) {
      CustomSnackBar.show(context, message: 'Enter phone number', isError: true);
      return;
    }

    if (_countdown > 0) {
      CustomSnackBar.show(context, message: 'Please wait $_countdown seconds', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.sendSignupOtp(_phoneNumber);

      SignupScreen._lastOtpRequest = DateTime.now();
      setState(() => _countdown = 10);
      _startCountdown();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(phoneNumber: _phoneNumber),
          ),
        );
      }
    } catch (e) {
      developer.log('Signup OTP error: $e');
      if (mounted) {
        final errorMsg = context
            .read<AuthService>()
            .getAuthErrorMessage(e, flow: AuthFlow.sendSignupOtp);

        final isTooManyRequests =
            e is DioException && e.response?.statusCode == 429;
        if (isTooManyRequests) {
          SignupScreen._lastOtpRequest = DateTime.now();
          setState(() => _countdown = 10);
          _startCountdown();
        }
        CustomSnackBar.show(context, message: errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: AppDimensions.appMargin(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _countdown > 0 ? 'Wait $_countdown seconds' : 'Send OTP',
                onPressed: _sendOtp,
                isLoading: _loading,
              ),
            ),
            AppDimensions.h10(context),
            CustomButton(
              text: 'Already have account? Login',
              onPressed: () => Navigator.pop(context),
              isOutlined: true,
            ),
          ],
        ),
      ),
    );
  }
}
