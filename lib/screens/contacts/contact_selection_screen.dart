import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/network_error_handler.dart';
import '../../services/contact_service.dart';
import '../../models/contact_model.dart';
import '../../services/isar_service.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/gradient_app_bar.dart';

class ContactSelectionScreen extends StatefulWidget {
  const ContactSelectionScreen({super.key});

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  List<Contact> _deviceContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedPhones = {};
  bool _loading = true;
  bool _syncing = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDeviceContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _deviceContacts;
      } else {
        _filteredContacts = _deviceContacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          final phone = _normalizePhone(contact.phones.first.number);
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || phone.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _loadDeviceContacts() async {
    try {
      final status = await Permission.contacts.status;
      if (status.isDenied) {
        final result = await Permission.contacts.request();
        if (!result.isGranted) {
          if (mounted) {
            final navigator = Navigator.of(context);
            final retry = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Contact Permission Required'),
                content: const Text(
                    'This app needs access to your contacts to find registered users. Please grant permission in settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
            if (retry == true) await openAppSettings();
            navigator.pop();
          }
          return;
        }
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      final contactsWithPhone =
          contacts.where((c) => c.phones.isNotEmpty).toList();

      if (mounted) {
        final preselected = await _loadPreviouslyAddedPhones(contactsWithPhone);
        setState(() {
          _deviceContacts = contactsWithPhone;
          _filteredContacts = contactsWithPhone;
          _selectedPhones = preselected;
          _loading = false;
        });
      }
    } catch (e) {
      developer.log('Load device contacts error: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: NetworkErrorHandler.message(e,
              fallback: 'Failed to load contacts'),
          isError: true,
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<Set<String>> _loadPreviouslyAddedPhones(
      List<Contact> deviceContacts) async {
    try {
      final isar = context.read<IsarService>();
      final savedContacts =
          await isar.isar.contactModels.filter().idGreaterThan(-1).findAll();
      if (savedContacts.isEmpty) return <String>{};
      final savedCanonicalPhones = savedContacts
          .map((c) => PhoneUtils.canonical(c.phoneNumber ?? ''))
          .where((p) => p.isNotEmpty)
          .toSet();
      return deviceContacts
          .map((c) => _normalizePhone(c.phones.first.number))
          .where((phone) =>
              savedCanonicalPhones.contains(PhoneUtils.canonical(phone)))
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  String _normalizePhone(String phone) => PhoneUtils.normalizeRaw(phone);
  String _canonicalPhone(String phone) => PhoneUtils.canonical(phone);
  bool _looksLikePhoneName(String? value) =>
      PhoneUtils.looksLikePhoneName(value);

  Future<void> _syncSelected() async {
    if (_selectedPhones.isEmpty) {
      CustomSnackBar.show(context,
          message: 'Select at least one contact', isError: true);
      return;
    }
    setState(() => _syncing = true);
    try {
      final isar = context.read<IsarService>();
      final contactService = context.read<ContactService>();
      final selectedContacts = _deviceContacts
          .where((c) =>
              _selectedPhones.contains(_normalizePhone(c.phones.first.number)))
          .toList();

      final contactsData = selectedContacts
          .map((c) => {
                'name': c.displayName,
                'phone': _normalizePhone(c.phones.first.number)
              })
          .toList();

      final registeredUsers =
          await contactService.matchContactsList(contactsData);

      final registeredPhones = <String, ContactModel>{};
      for (final user in registeredUsers) {
        final phone = user.phoneNumber;
        if (phone == null || phone.isEmpty) continue;
        registeredPhones[_canonicalPhone(phone)] = user;
      }

      final allContacts = <ContactModel>[];
      for (var contact in selectedContacts) {
        final rawPhone = _normalizePhone(contact.phones.first.number);
        final phone = _canonicalPhone(rawPhone);
        final registered = registeredPhones[phone];
        if (registered != null) {
          if (_looksLikePhoneName(registered.name))
            registered.name = contact.displayName;
          // Preserve raw phone with country code if registered model has only 10 digits
          if ((registered.phoneNumber?.length ?? 0) <= 10) {
            registered.phoneNumber = rawPhone;
          }
          allContacts.add(registered);
        } else {
          allContacts.add(ContactModel(
            name: contact.displayName,
            phoneNumber: rawPhone,
            isRegistered: false,
            createdAt: DateTime.now(),
          ));
        }
      }

      await contactService.upsertContactsByCanonical(isar, allContacts);
      contactService.notifyUpdate();

      if (mounted) {
        CustomSnackBar.show(context,
            message: 'Added ${allContacts.length} contacts');
        Navigator.of(context).pop(allContacts.length);
      }
    } catch (e) {
      developer.log('Sync selected error: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: NetworkErrorHandler.message(e,
              fallback: 'Failed to sync contacts'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCount = _selectedPhones.length;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Select Contacts',
        actions: [
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _syncing ? null : _syncSelected,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Add $selectedCount',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deviceContacts.isEmpty
              ? Center(
                  child: Text('No contacts found',
                      style: AppTextStyles.bodyMedium(context)),
                )
              : Column(
                  children: [
                    Padding(
                      padding:
                          AppDimensions.appMargin(context).copyWith(bottom: 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search contacts...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterContacts('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _filterContacts,
                      ),
                    ),
                    if (selectedCount > 0)
                      Padding(
                        padding: AppDimensions.appMargin(context)
                            .copyWith(top: 8, bottom: 0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Text(
                                '$selectedCount selected',
                                style:
                                    AppTextStyles.labelSmall(context).copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedPhones.clear()),
                              child: Text(
                                'Clear all',
                                style:
                                    AppTextStyles.labelSmall(context).copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    AppDimensions.h10(context),
                    Expanded(
                      child: ListView.builder(
                        padding:
                            AppDimensions.appMargin(context).copyWith(top: 0),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final phone =
                              _normalizePhone(contact.phones.first.number);
                          final isSelected = _selectedPhones.contains(phone);
                          final initial = contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?';

                          return GestureDetector(
                            onTap: () => setState(() {
                              if (isSelected) {
                                _selectedPhones.remove(phone);
                              } else {
                                _selectedPhones.add(phone);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: AppDimensions.compactCardMargin(context),
                              padding:
                                  AppDimensions.compactCardPadding(context),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.05)
                                    : scheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.35)
                                      : AppColors.borderLight,
                                  width: isSelected ? 1.5 : 1.2,
                                ),
                                boxShadow: isSelected
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.primary
                                              .withValues(alpha: 0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: AppTextStyles.titleSmall(context)
                                          .copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          contact.displayName,
                                          style:
                                              AppTextStyles.titleSmall(context)
                                                  .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          phone,
                                          style:
                                              AppTextStyles.bodySmall(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.borderLight,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded,
                                            size: 15, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
