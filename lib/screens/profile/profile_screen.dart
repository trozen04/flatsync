import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_currencies.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../routes/app_routes.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_sections.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../models/user_model.dart';
import '../../services/isar_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/network_error_handler.dart';
import '../../constants/app_shadows.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _biometricBusy = false;
  bool _biometricAvailable = false;
  bool _notificationBusy = false;
  bool _notificationsEnabled = false;
  String? _biometricLabel;
  UserModel? _user;

  Future<void> _toggleNotifications(bool enabled) async {
    if (_notificationBusy) return;

    setState(() => _notificationBusy = true);
    try {
      final preferences = context.read<AppPreferencesService>();
      final notificationService = context.read<NotificationService>();
      if (enabled) {
        await notificationService.registerDevice(requestPermission: true);
        final granted = await notificationService.hasNotificationPermission();
        await preferences.setNotificationsEnabled(granted);
        await preferences.setNotificationPromptSeen(true);
        if (!mounted) return;
        setState(() => _notificationsEnabled = granted);
        CustomSnackBar.show(
          context,
          message: granted
              ? 'Notifications enabled'
              : 'Notification permission not granted',
          isError: !granted,
        );
        return;
      }

      await notificationService.unregisterDevice();
      await preferences.setNotificationsEnabled(false);
      if (!mounted) return;
      setState(() => _notificationsEnabled = false);

      CustomSnackBar.show(
        context,
        message: 'Notifications disabled',
      );
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  Future<void> _showCurrencyPicker(AppPreferencesService preferences) async {
    final searchController = TextEditingController();
    var query = '';

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final filtered = AppCurrencies.supported.where((currency) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) return true;
            return currency.code.toLowerCase().contains(q) ||
                currency.label.toLowerCase().contains(q);
          }).toList();

          return SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Choose Currency',
                    style: AppTextStyles.titleMedium(sheetContext),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search currency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setSheetState(() => query = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final currency = filtered[index];
                        final isSelected =
                            currency.code == preferences.preferredCurrencyCode;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(currency.code.substring(0, 1)),
                          ),
                          title: Text('${currency.code} - ${currency.label}'),
                          subtitle: Text(currency.symbol.trim()),
                          trailing: isSelected ? const Icon(Icons.check) : null,
                          onTap: () =>
                              Navigator.pop(sheetContext, currency.code),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted || selected == null) return;
    await preferences.setPreferredCurrency(
      selected,
      manuallySelected: true,
    );
    if (!mounted) return;
    CustomSnackBar.show(context, message: 'Default currency updated');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      await _loadBiometricAvailability();
      await _loadNotificationStatus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final isar = context.read<IsarService>();
      final local = await isar.getCurrentUserLocal();
      if (mounted && local != null) {
        _user = local;
        _nameController.text = local.name ?? '';
        _phoneController.text = local.phoneNumber ?? '';
      }

      final remote = await context.read<AuthService>().getCurrentUser();
      if (mounted && remote != null) {
        _user = remote;
        _nameController.text = remote.name ?? '';
        _phoneController.text = remote.phoneNumber ?? '';
        await isar.replaceCurrentUser(_mergeTokensIfPresent(local, remote));
      }
    } catch (e) {
      developer.log('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBiometricAvailability() async {
    try {
      final biometric = context.read<BiometricAuthService>();
      final available = await biometric.isAvailable();
      final types = await biometric.getAvailableBiometrics();
      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        _biometricLabel =
            available ? biometric.describeBiometrics(types) : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _biometricAvailable = false;
        _biometricLabel = null;
      });
    }
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final preferences = context.read<AppPreferencesService>();
      final notificationService = context.read<NotificationService>();
      final granted = await notificationService.hasNotificationPermission();
      if (!mounted) return;
      final enabled = preferences.notificationsEnabled && granted;
      if (preferences.notificationsEnabled && !granted) {
        await preferences.setNotificationsEnabled(false);
      }
      setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = false);
    }
  }

  UserModel _mergeTokensIfPresent(UserModel? local, UserModel remote) {
    if (local == null) return remote;
    // Keep auth tokens/pin from local; server /auth/me doesn't return them.
    remote.accessToken = local.accessToken;
    remote.refreshToken = local.refreshToken;
    remote.hashedPin = local.hashedPin;
    remote.isLoggedIn = local.isLoggedIn;
    return remote;
  }

  Future<bool> _saveName(String name) async {
    if (_saving) return false;
    if (name.isEmpty) {
      CustomSnackBar.show(context, message: 'Name is required', isError: true);
      return false;
    }

    final currentName = (_user?.name ?? '').trim();
    final nameUpdate = name == currentName ? null : name;

    if (nameUpdate == null) {
      CustomSnackBar.show(context, message: 'No changes to save');
      return false;
    }

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final updated = await auth.updateMe(name: nameUpdate);
      if (updated == null) {
        CustomSnackBar.show(context,
            message: 'Unable to update profile', isError: true);
        return false;
      }

      final isar = context.read<IsarService>();
      final local = await isar.getCurrentUserLocal();
      await isar.replaceCurrentUser(_mergeTokensIfPresent(local, updated));

      if (mounted) {
        setState(() => _user = updated);
        CustomSnackBar.show(context, message: 'Profile updated');
        FocusScope.of(context).unfocus();
      }
      return true;
    } catch (e) {
      developer.log('Profile save error: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: NetworkErrorHandler.message(
            e,
            fallback: 'Unable to update profile',
          ),
          isError: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (_biometricBusy) return;
    if (enabled && !_biometricAvailable) {
      CustomSnackBar.show(
        context,
        message: 'Biometric authentication is not available on this device',
        isError: true,
      );
      return;
    }

    setState(() => _biometricBusy = true);
    try {
      final preferences = context.read<AppPreferencesService>();
      if (enabled) {
        final ok = await context.read<BiometricAuthService>().authenticate(
              reason: 'Confirm biometric unlock for SplitEasy',
            );
        if (!ok) {
          if (mounted) {
            CustomSnackBar.show(
              context,
              message: 'Biometric verification failed',
              isError: true,
            );
          }
          return;
        }
      }

      await preferences.setBiometricEnabled(enabled);
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: enabled
              ? 'Biometric unlock enabled'
              : 'Biometric unlock disabled',
        );
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _editAccountDetails() async {
    final nameController = TextEditingController(text: _nameController.text);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, _) {
              return Padding(
                padding: AppDimensions.appMargin(sheetContext),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit account',
                      style: AppTextStyles.titleMedium(sheetContext).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppDimensions.h20(sheetContext),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    AppDimensions.h10(sheetContext),
                    TextField(
                      controller: _phoneController,
                      readOnly: true,
                      enableInteractiveSelection: false,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    AppDimensions.h20(sheetContext),
                    CustomButton(
                      text: 'Save changes',
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          CustomSnackBar.show(
                            sheetContext,
                            message: 'Name is required',
                            isError: true,
                          );
                          return;
                        }
                        final ok = await _saveName(name);
                        if (ok && sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _initials() {
    final value = (_user?.name ?? '').trim();
    if (value.isEmpty) return 'S';
    final parts = value.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _groupCard(BuildContext context, List<Widget> children) {
    return AppCard(
      type: AppCardType.elevated,
      padding: EdgeInsets.zero,
      child: Column(
        children: _withDividers(children),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    return [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i != children.length - 1) const Divider(height: 1),
      ],
    ];
  }

  Widget _profileActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppListTile(
      dense: true,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.colored(AppColors.primary, intensity: 0.22),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Text(
        title,
        style: AppTextStyles.titleSmall(context).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall(context),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }

  Widget _profileSwitchRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool busy,
    required ValueChanged<bool> onChanged,
  }) {
    return AppListTile(
      dense: true,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: value
                ? [const Color(0xFF6EE7B7), AppColors.success]
                : [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.colored(
            value ? AppColors.success : AppColors.primary,
            intensity: 0.22,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Text(
        title,
        style: AppTextStyles.titleSmall(context).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall(context),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: busy ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferencesService>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: widget.showAppBar
            ? const GradientAppBar(title: 'Profile')
            : null,
        body: Padding(
          padding: AppDimensions.appMargin(context),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _ProfileHeroCard(
                      name: _user?.name ?? 'Your profile',
                      phone: _phoneController.text,
                      notificationsEnabled: _notificationsEnabled,
                      biometricEnabled: preferences.biometricEnabled,
                      onEditAccount: _editAccountDetails,
                    ),
                    AppDimensions.h20(context),
                    const AppSectionHeader(
                      title: 'Preferences',
                      subtitle: 'Security, currency, and notification controls.',
                    ),
                    AppDimensions.h10(context),
                    _groupCard(
                      context,
                      [
                        _profileSwitchRow(
                          context,
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometric unlock',
                          subtitle: _biometricAvailable
                              ? (_biometricLabel == null
                                  ? 'Use biometrics to open the app'
                                  : 'Use $_biometricLabel to open the app')
                              : 'Not available on this device',
                          value: preferences.biometricEnabled,
                          busy: _biometricBusy,
                          onChanged: _toggleBiometric,
                        ),
                        _profileActionRow(
                          context,
                          icon: Icons.currency_rupee_rounded,
                          title: 'Default currency',
                          subtitle:
                              '${preferences.preferredCurrency.code} - ${preferences.preferredCurrency.label}',
                          onTap: () => _showCurrencyPicker(preferences),
                        ),
                        _profileSwitchRow(
                          context,
                          icon: Icons.notifications_rounded,
                          title: 'Notifications',
                          subtitle: _notificationsEnabled
                              ? 'Enabled for expense and payment updates.'
                              : 'Disabled. Tap to turn on reminders.',
                          value: _notificationsEnabled,
                          busy: _notificationBusy,
                          onChanged: _toggleNotifications,
                        ),
                      ],
                    ),
                    AppDimensions.h20(context),
                    AppSectionHeader(
                      title: 'Help & legal',
                      subtitle: 'Support, policies, and app information.',
                    ),
                    AppDimensions.h10(context),
                    _groupCard(
                      context,
                      [
                        _profileActionRow(
                          context,
                          icon: Icons.menu_book_rounded,
                          title: 'Help & Guide',
                          subtitle:
                              'How to use the app, support, version, and more apps',
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.helpGuide),
                        ),
                        _profileActionRow(
                          context,
                          icon: Icons.description_rounded,
                          title: 'Terms & Conditions',
                          subtitle: 'Rules for using the app',
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.terms),
                        ),
                        _profileActionRow(
                          context,
                          icon: Icons.privacy_tip_rounded,
                          title: 'Privacy Policy',
                          subtitle: 'How your data is handled',
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.privacy),
                        ),
                      ],
                    ),
                    AppDimensions.h20(context),
                  ],
                ),
              ),
        ),
      );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final String name;
  final String phone;
  final bool notificationsEnabled;
  final bool biometricEnabled;
  final VoidCallback onEditAccount;

  const _ProfileHeroCard({
    required this.name,
    required this.phone,
    required this.notificationsEnabled,
    required this.biometricEnabled,
    required this.onEditAccount,
  });

  String _initials(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'S';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: AppDimensions.compactCardPadding(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.cardElevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                child: Text(
                  _initials(name),
                  style: AppTextStyles.titleMedium(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppDimensions.w10(context),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isEmpty ? 'Mobile number not set' : phone,
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onEditAccount,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          AppDimensions.h10(context),
          Text(
            'A compact view of your SplitEasy profile.',
            style: AppTextStyles.bodySmall(context).copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          AppDimensions.h10(context),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                label: 'Biometric',
                value: biometricEnabled ? 'On' : 'Off',
                icon: Icons.fingerprint_rounded,
                textColor: text,
              ),
              _HeroChip(
                label: 'Alerts',
                value: notificationsEnabled ? 'On' : 'Off',
                icon: Icons.notifications_rounded,
                textColor: text,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color textColor;

  const _HeroChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: AppTextStyles.labelSmall(context).copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
