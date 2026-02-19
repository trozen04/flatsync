import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/auth_service.dart';
import '../../../services/expense_service.dart';
import '../../../services/contact_service.dart';
import '../../../data/repositories/isar_service.dart';
import '../../../utils/custom_snackbar.dart';
import '../app_shell.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerifyScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _obscurePin = true;

  Future<void> _syncAfterLogin(IsarService isar) async {
    final expenseService = context.read<ExpenseService>();
    final contactService = context.read<ContactService>();
    final balances = await expenseService.getBalances(forceRefresh: true);
    if (balances.isNotEmpty) {
      await contactService.autoSyncFromBalances(balances, isar);
      contactService.notifyUpdate();
    }
    await expenseService.getExpenses(forceRefresh: true);
  }

  Future<void> _verify() async {
    if (_otpController.text.isEmpty || _nameController.text.isEmpty || _pinController.text.isEmpty) {
      CustomSnackBar.show(context, message: 'Fill all fields', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.verifySignupOtp(
        phoneNumber: widget.phoneNumber,
        otp: _otpController.text,
        name: _nameController.text,
        pin: _pinController.text,
      );

      final isar = context.read<IsarService>();
      await isar.replaceCurrentUser(user);

      await _syncAfterLogin(isar);

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
        final errorMsg = context
            .read<AuthService>()
            .getAuthErrorMessage(e, flow: AuthFlow.verifySignupOtp);
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
        appBar: AppBar(title: const Text('Verify OTP')),
        body: SafeArea(
          child: Padding(
            padding: AppDimensions.appMargin(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                AppDimensions.h20(context),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                AppDimensions.h20(context),
                TextField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: '4-digit PIN',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
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
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Verify & Sign Up', style: AppTextStyles.titleMedium(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
