import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../widgets/custom_button.dart';
import '../../services/auth_service.dart';
import '../../utils/custom_snackbar.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  static DateTime? _lastOtpRequest;
  static String? _lastOtpPhone;

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  static const int _otpCooldownSeconds = 120;
  static const String _otpBypassPhone = '8887692942';

  String _phoneNumber = '';
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _obscurePin = true;
  bool _otpSent = false;
  int _countdown = 0;
  bool _countdownActive = false;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String _canonicalPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  bool get _isOtpBypassed => _canonicalPhone(_phoneNumber) == _otpBypassPhone;

  void _syncCountdown() {
    if (_isOtpBypassed) {
      if (_countdown != 0) {
        setState(() => _countdown = 0);
      }
      return;
    }

    final lastRequest = ForgotPinScreen._lastOtpRequest;
    final currentPhone = _canonicalPhone(_phoneNumber);
    if (lastRequest == null ||
        currentPhone.isEmpty ||
        ForgotPinScreen._lastOtpPhone != currentPhone) {
      if (_countdown != 0) {
        setState(() => _countdown = 0);
      }
      return;
    }

    final elapsed = DateTime.now().difference(lastRequest).inSeconds;
    final remaining = _otpCooldownSeconds - elapsed;
    if (remaining > 0) {
      setState(() => _countdown = remaining);
      _startCountdown();
      return;
    }

    if (_countdown != 0) {
      setState(() => _countdown = 0);
    }
  }

  void _startCountdown() {
    if (_countdownActive || _countdown <= 0) return;
    _countdownActive = true;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) {
        _countdownActive = false;
        return false;
      }
      if (_isOtpBypassed || _countdown <= 1) {
        setState(() => _countdown = 0);
        _countdownActive = false;
        return false;
      }
      setState(() => _countdown--);
      return true;
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneNumber.isEmpty) {
      CustomSnackBar.show(context,
          message: 'Enter phone number', isError: true);
      return;
    }
    if (!_isOtpBypassed && _countdown > 0) {
      CustomSnackBar.show(context,
          message: 'Please wait $_countdown seconds', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final response = await authService.sendResetPinOtp(_phoneNumber);
      final deliveryLabel = authService.describeOtpDestination(response);
      if (_isOtpBypassed) {
        ForgotPinScreen._lastOtpRequest = null;
        ForgotPinScreen._lastOtpPhone = null;
        setState(() {
          _otpSent = true;
          _countdown = 0;
        });
      } else {
        ForgotPinScreen._lastOtpRequest = DateTime.now();
        ForgotPinScreen._lastOtpPhone = _canonicalPhone(_phoneNumber);
        setState(() {
          _otpSent = true;
          _countdown = _otpCooldownSeconds;
        });
        _startCountdown();
      }
      if (mounted) {
        CustomSnackBar.show(context,
            message: 'Code sent. Check your $deliveryLabel.');
      }
    } catch (e) {
      developer.log('Forgot PIN send OTP error: $e');
      if (mounted) {
        final errorMsg = context
            .read<AuthService>()
            .getAuthErrorMessage(e, flow: AuthFlow.sendResetPinOtp);
        final isTooManyRequests =
            e is DioException && e.response?.statusCode == 429;
        if (isTooManyRequests && !_isOtpBypassed) {
          ForgotPinScreen._lastOtpRequest = DateTime.now();
          ForgotPinScreen._lastOtpPhone = _canonicalPhone(_phoneNumber);
          setState(() => _countdown = _otpCooldownSeconds);
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
                    setState(() {
                      _phoneNumber = digits.length >= 6 && digits.length <= 15
                          ? phone.completeNumber
                          : '';
                    });
                    _syncCountdown();
                  },
                ),
                AppDimensions.h20(context),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: !_isOtpBypassed && _countdown > 0
                        ? 'Wait $_countdown seconds'
                        : 'Send Reset Code',
                    onPressed: _sendOtp,
                    isLoading: _loading,
                  ),
                ),
                if (_otpSent) ...[
                  AppDimensions.h20(context),
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
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

