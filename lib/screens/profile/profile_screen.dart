import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_currencies.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/shadowed_app_bar.dart';
import '../../models/user_model.dart';
import '../../services/isar_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../utils/custom_snackbar.dart';

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
  String? _biometricLabel;
  UserModel? _user;

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
                          onTap: () => Navigator.pop(sheetContext, currency.code),
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
        _biometricLabel = available ? biometric.describeBiometrics(types) : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _biometricAvailable = false;
        _biometricLabel = null;
      });
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

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      CustomSnackBar.show(context, message: 'Name is required', isError: true);
      return;
    }

    final currentName = (_user?.name ?? '').trim();
    final nameUpdate = name == currentName ? null : name;

    if (nameUpdate == null) {
      CustomSnackBar.show(context, message: 'No changes to save');
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final updated = await auth.updateMe(name: nameUpdate);
      if (updated == null) {
        CustomSnackBar.show(context, message: 'Unable to update profile', isError: true);
        return;
      }

      final isar = context.read<IsarService>();
      final local = await isar.getCurrentUserLocal();
      await isar.replaceCurrentUser(_mergeTokensIfPresent(local, updated));

      if (mounted) {
        setState(() => _user = updated);
        CustomSnackBar.show(context, message: 'Profile updated');
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      developer.log('Profile save error: $e');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Unable to update profile', isError: true);
      }
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preferences = context.watch<AppPreferencesService>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: widget.showAppBar
            ? ShadowedAppBar(
                child: AppBar(
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: const Text('Profile'),
                ),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: AppDimensions.appMargin(context),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.only(
                      bottom: AppDimensions.height(context) * 0.14,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.primary.withOpacity(0.15),
                              child: Text(
                                ((_user?.name ?? 'U').trim().isEmpty
                                        ? 'U'
                                        : (_user!.name!.trim()[0]))
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _user?.name?.trim().isNotEmpty == true
                                        ? _user!.name!
                                        : 'User',
                                    style: AppTextStyles.titleMedium(context),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _user?.phoneNumber ?? '',
                                    style: AppTextStyles.bodySmall(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppDimensions.h20(context),
                      Text('Your details', style: AppTextStyles.titleMedium(context)),
                      AppDimensions.h10(context),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      AppDimensions.h10(context),
                      TextField(
                        controller: _phoneController,
                        readOnly: true,
                        enableInteractiveSelection: false,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      AppDimensions.h20(context),
                      Text('Security & preferences',
                          style: AppTextStyles.titleMedium(context)),
                      AppDimensions.h10(context),
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: preferences.biometricEnabled,
                              onChanged: _biometricBusy ? null : _toggleBiometric,
                              title: const Text('Biometric unlock'),
                              subtitle: Text(
                                _biometricAvailable
                                    ? (_biometricLabel == null
                                        ? 'Use biometrics to open the app'
                                        : 'Use $_biometricLabel to open the app')
                                    : 'Not available on this device',
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('Default currency'),
                              subtitle: Text(
                                '${preferences.preferredCurrency.code} - ${preferences.preferredCurrency.label}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showCurrencyPicker(preferences),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                'This currency will be used for amount input and display across the app.',
                                style: AppTextStyles.bodySmall(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        floatingActionButton: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.width(context) * 0.04),
          child: CustomButton(
            text: 'Save',
            onPressed: _save,
            isLoading: _saving,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
