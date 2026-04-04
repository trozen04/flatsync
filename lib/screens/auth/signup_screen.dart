import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../constants/app_dimensions.dart';
import '../../utils/image_assets.dart';
import '../../widgets/custom_button.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/gradient_app_bar.dart';
import 'otp_verify_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static DateTime? _lastOtpRequest;
  static String? _lastOtpPhone;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const int _otpCooldownSeconds = 120;
  static const String _otpBypassPhone = '8887692942';

  String _phoneNumber = '';
  bool _loading = false;
  int _countdown = 0;
  bool _countdownActive = false;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  String _canonicalPhone(String phone) => PhoneUtils.canonical(phone);

  bool get _isOtpBypassed => _canonicalPhone(_phoneNumber) == _otpBypassPhone;

  void _syncCountdown() {
    if (_isOtpBypassed) {
      if (_countdown != 0) {
        setState(() => _countdown = 0);
      }
      return;
    }

    final lastRequest = SignupScreen._lastOtpRequest;
    final currentPhone = _canonicalPhone(_phoneNumber);
    if (lastRequest == null ||
        currentPhone.isEmpty ||
        SignupScreen._lastOtpPhone != currentPhone) {
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
      CustomSnackBar.show(context, message: 'Enter phone number', isError: true);
      return;
    }

    if (!_isOtpBypassed && _countdown > 0) {
      CustomSnackBar.show(context, message: 'Please wait $_countdown seconds', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      developer.log('SignupScreen: sendOtp request ($_phoneNumber)', name: 'SignupScreen');
      final authService = context.read<AuthService>();
      final response = await authService.sendSignupOtp(_phoneNumber);
      developer.log('SignupScreen: sendOtp response: $response', name: 'SignupScreen');
      final deliveryLabel = authService.describeOtpDestination(response);

      if (_isOtpBypassed) {
        SignupScreen._lastOtpRequest = null;
        SignupScreen._lastOtpPhone = null;
        setState(() => _countdown = 0);
      } else {
        SignupScreen._lastOtpRequest = DateTime.now();
        SignupScreen._lastOtpPhone = _canonicalPhone(_phoneNumber);
        setState(() => _countdown = _otpCooldownSeconds);
        _startCountdown();
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              phoneNumber: _phoneNumber,
              deliveryLabel: deliveryLabel,
            ),
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
        if (isTooManyRequests && !_isOtpBypassed) {
          SignupScreen._lastOtpRequest = DateTime.now();
          SignupScreen._lastOtpPhone = _canonicalPhone(_phoneNumber);
          setState(() => _countdown = _otpCooldownSeconds);
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: const GradientAppBar(title: 'Sign Up'),
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
                          height: AppDimensions.height(context) * 0.07 ,
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
                          onCountryChanged: (country) {
                            context
                                .read<AppPreferencesService>()
                                .autoSetCurrencyFromCountry(country.code);
                          },
                          onChanged: (phone) {
                            final digits =
                                phone.number.replaceAll(RegExp(r'[^0-9]'), '');
                            setState(() {
                              _phoneNumber = digits.length >= 6 && digits.length <= 15
                                  ? phone.completeNumber
                                  : '';
                            });
                            context
                                .read<AppPreferencesService>()
                                .autoSetCurrencyFromCountry(phone.countryISOCode);
                            _syncCountdown();
                          },
                        ),
                        AppDimensions.h20(context),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: !_isOtpBypassed && _countdown > 0
                                ? 'Wait $_countdown seconds'
                                : 'Send Code',
                            onPressed: (!_isOtpBypassed && _countdown > 0)
                                ? null
                                : _sendOtp,
                            isLoading: _loading,
                            isDisabled: !_isOtpBypassed && _countdown > 0,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
