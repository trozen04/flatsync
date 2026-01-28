import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flatsync/src/core/theme/app_colors.dart';
import 'package:flatsync/src/core/theme/app_text_styles.dart';
import 'package:flatsync/src/core/theme/app_spacing.dart';
import 'package:flatsync/src/core/widgets/app_button.dart';
import 'package:flatsync/src/core/user/user_profile.dart';
import 'package:flatsync/src/presentation/screens/app_shell.dart';

import '../../utils/custom_snackbar.dart';

class UserSetupScreen extends StatefulWidget {

  const UserSetupScreen({
    super.key,
  });

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  String? _selectedUser;
  String _deviceName = '';
  bool _isLoading = false;
  
  final List<String> _users = ['Bhoopendra', 'Anand', 'Naman', 'Varun'];

  @override
  void initState() {
    super.initState();
    _getDeviceName();
  }
  
  Future<void> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        setState(() => _deviceName = info.model);
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        setState(() => _deviceName = info.name);
      }
    } catch (e) {
      setState(() => _deviceName = 'Unknown Device');
    }
  }

  Future<void> _saveUser() async {
    if (_selectedUser == null) {
      CustomSnackBar.show(
        context,
        message: 'Please select a user',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userWithDevice = '$_selectedUser ($_deviceName)';
      await UserProfile.setUserName(userWithDevice);
      if (mounted) {
        // Navigate directly to AppShell
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AppShell()),
            );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error saving user: $e',
          isError: true,
        );
        developer.log('Error saving user: $e');

      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Icon/Logo
                Container(
                  padding: EdgeInsets.all(AppSpacing.responsive(context, AppSpacing.xxl)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: AppSpacing.responsive(context, 80),
                    color: AppColors.primary,
                  ),
                ),
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.huge),

                // Welcome Text
                Text(
                  'Welcome to Slice!',
                  style: AppTextStyles.headlineMedium(context),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),

                Text(
                  'Select your name and device will be automatically added for identification.',
                  style: AppTextStyles.bodyLarge(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.huge),

                // User Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.responsive(context, 12),
                    ),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedUser,
                    decoration: InputDecoration(
                      labelText: 'Select User',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: InputBorder.none,
                      contentPadding: AppSpacing.cardPadding(context),
                    ),
                    items: _users.map((user) => DropdownMenuItem(
                      value: user,
                      child: Text(user),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedUser = value),
                  ),
                ),
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),
                
                // Device Info
                if (_deviceName.isNotEmpty)
                  Container(
                    padding: AppSpacing.cardPadding(context),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.responsive(context, 12),
                      ),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: AppColors.success,
                          size: AppSpacing.responsive(context, 20),
                        ),
                        AppSpacing.horizontalSpace(context, AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Device: $_deviceName',
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.lg),

                // Info Text
                Container(
                  padding: AppSpacing.cardPadding(context),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.responsive(context, 12),
                    ),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: AppSpacing.responsive(context, 20),
                      ),
                      AppSpacing.horizontalSpace(context, AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Your name and device will appear when you add expenses for easy identification.',
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.responsiveVerticalSpace(context, AppSpacing.xxxl),

                // Continue Button
                AppButton(
                  text: 'Get Started',
                  icon: Icons.arrow_forward,
                  onPressed: _selectedUser != null ? _saveUser : null,
                  isLoading: _isLoading,
                  type: AppButtonType.primary,
                  size: AppButtonSize.large,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}