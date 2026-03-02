import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../utils/custom_snackbar.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  static DateTime? _lastOtpRequest;

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  String _phoneNumber = '';
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _obscurePin = true;
  bool _otpSent = false;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _updateCountdown() {
    if (ForgotPinScreen._lastOtpRequest != null) {
      final elapsed =
          DateTime.now().difference(ForgotPinScreen._lastOtpRequest!).inSeconds;
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
      CustomSnackBar.show(context,
          message: 'Enter phone number', isError: true);
      return;
    }
    if (_countdown > 0) {
      CustomSnackBar.show(context,
          message: 'Please wait $_countdown seconds', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthService>().sendResetPinOtp(_phoneNumber);
      ForgotPinScreen._lastOtpRequest = DateTime.now();
      setState(() {
        _otpSent = true;
        _countdown = 10;
      });
      _startCountdown();
      if (mounted) {
        CustomSnackBar.show(context,
            message: 'OTP sent. Check your server logs/SMS.');
      }
    } catch (e) {
      developer.log('Forgot PIN send OTP error: $e');
      if (mounted) {
        final errorMsg = context
            .read<AuthService>()
            .getAuthErrorMessage(e, flow: AuthFlow.sendResetPinOtp);
        final isTooManyRequests =
            e is DioException && e.response?.statusCode == 429;
        if (isTooManyRequests) {
          ForgotPinScreen._lastOtpRequest = DateTime.now();
          setState(() => _countdown = 10);
          _startCountdown();
        }
        CustomSnackBar.show(context, message: errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPin() async {
    if (_phoneNumber.isEmpty ||
        _otpController.text.isEmpty ||
        _pinController.text.isEmpty) {
      CustomSnackBar.show(context, message: 'Fill all fields', isError: true);
      return;
    }
    if (_pinController.text.length < 4 || _pinController.text.length > 6) {
      CustomSnackBar.show(context,
          message: 'PIN must be 4-6 digits', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthService>().verifyResetPinOtp(
            phoneNumber: _phoneNumber,
            otp: _otpController.text,
            pin: _pinController.text,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      developer.log('Forgot PIN verify error: $e');
      if (mounted) {
        final errorMsg = context
            .read<AuthService>()
            .getAuthErrorMessage(e, flow: AuthFlow.verifyResetPinOtp);
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
        appBar: AppBar(title: const Text('Forgot PIN')),
        body: SafeArea(
          child: Padding(
            padding: AppDimensions.appMargin(context),
            child: Column(
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
                    final digits =
                        phone.number.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length >= 6 && digits.length <= 15) {
                      _phoneNumber = phone.completeNumber;
                    }
                  },
                ),
                AppDimensions.h20(context),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _countdown > 0
                        ? 'Wait $_countdown seconds'
                        : 'Send Reset OTP',
                    onPressed: _sendOtp,
                    isLoading: _loading,
                  ),
                ),
                if (_otpSent) ...[
                  AppDimensions.h20(context),
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                  ),
                  AppDimensions.h10(context),
                  TextField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: 'New PIN (4-6 digits)',
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: _obscurePin,
                    maxLength: 6,
                  ),
                  AppDimensions.h10(context),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Reset PIN',
                      onPressed: _resetPin,
                      isLoading: _loading,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
