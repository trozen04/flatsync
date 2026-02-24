import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/shadowed_app_bar.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../services/auth_service.dart';
import '../../utils/custom_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _avatarController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
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
        _avatarController.text = local.avatar ?? '';
      }

      final remote = await context.read<AuthService>().getCurrentUser();
      if (mounted && remote != null) {
        _user = remote;
        _nameController.text = remote.name ?? '';
        _avatarController.text = remote.avatar ?? '';
        await isar.replaceCurrentUser(_mergeTokensIfPresent(local, remote));
      }
    } catch (e) {
      developer.log('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
    final avatarRaw = _avatarController.text.trim();

    if (name.isEmpty) {
      CustomSnackBar.show(context, message: 'Name is required', isError: true);
      return;
    }

    final currentName = (_user?.name ?? '').trim();
    final currentAvatar = (_user?.avatar ?? '').trim();
    final nameUpdate = name == currentName ? null : name;
    final avatarUpdate = avatarRaw == currentAvatar ? null : (avatarRaw.isEmpty ? '' : avatarRaw);

    if (nameUpdate == null && avatarUpdate == null) {
      CustomSnackBar.show(context, message: 'No changes to save');
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final updated = await auth.updateMe(name: nameUpdate, avatar: avatarUpdate);
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                ((_user?.name ?? 'U').trim().isEmpty ? 'U' : (_user!.name!.trim()[0])).toUpperCase(),
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
                                    _user?.name?.trim().isNotEmpty == true ? _user!.name! : 'User',
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
                        controller: _avatarController,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL (optional)',
                          border: OutlineInputBorder(),
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
