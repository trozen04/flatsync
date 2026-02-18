import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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

  Future<void> _login() async {
    if (_phoneNumber.isEmpty || _pinController.text.isEmpty) {
      CustomSnackBar.show(context, message: 'Enter phone and PIN', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.login(
        phoneNumber: _phoneNumber,
        pin: _pinController.text,
      );

      final isar = context.read<IsarService>();
      await isar.replaceCurrentUser(user);

      await _syncAfterLogin(isar);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (e) {
      developer.log('Login error: $e');
      if (mounted) {
        String errorMsg = 'Oops! Something went wrong';
        if (e.toString().contains('401') || e.toString().contains('Invalid')) {
          errorMsg = 'Invalid phone or PIN';
        } else if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
          errorMsg = 'Cannot connect to server';
        } else if (e.toString().contains('timeout')) {
          errorMsg = 'Request timeout';
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
      body: SafeArea(
        child: Padding(
          padding: AppDimensions.appMargin(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Slice',
                style: AppTextStyles.displaySmall(context),
              ),
              AppDimensions.h50(context),
              IntlPhoneField(
                initialCountryCode: 'IN',
                disableLengthCheck: true,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                onChanged: (phone) {
                  _phoneNumber = phone.completeNumber;
                },
              ),
              AppDimensions.h20(context),
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'PIN',
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
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Login', style: AppTextStyles.titleMedium(context).copyWith(color: Colors.white)),
                ),
              ),
              AppDimensions.h20(context),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('New user? Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
