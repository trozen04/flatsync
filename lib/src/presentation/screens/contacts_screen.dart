import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../services/contact_service.dart';
import '../../services/expense_service.dart';
import '../../utils/custom_snackbar.dart';
import 'contact_selection_screen.dart';
import 'conversation_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactModel> _contacts = [];
  Map<String, int> _balances = {};

  bool _refreshing = false;
  bool _syncing = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  StreamSubscription<int>? _updatesSub;
  StreamSubscription<int>? _contactUpdatesSub;
  static const double _currencyDivisor = 100.0;
  bool _isReconciling = false;
  DateTime? _lastReconcileAt;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshData(forceRefresh: false));
    _updatesSub = context.read<ExpenseService>().updates.listen((_) {
      if (mounted) _loadBalances(forceRefresh: true);
    });
    // Listen to contact updates
    _contactUpdatesSub = context.read<ContactService>().updates.listen((_) {
      if (mounted) {
        _loadLocalContacts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _updatesSub?.cancel();
    _contactUpdatesSub?.cancel();
    super.dispose();
  }

  String _canonicalPhone(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  bool _looksLikePhoneName(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }

  Future<void> _refreshData({bool forceRefresh = false}) async {
    if (mounted) setState(() => _refreshing = true);
    await _loadLocalContacts();
    await _loadBalances(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _loadLocalContacts() async {
    try {
      final isar = context.read<IsarService>();
      final contacts = await isar.isar.contactModels.where().findAll();
      contacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      if (!mounted) return;
      setState(() => _contacts = contacts);

      // Non-blocking background reconciliation for contact IDs.
      final shouldReconcile = !_isReconciling &&
          (context.read<ContactService>().canAttemptLookup) &&
          (_lastReconcileAt == null ||
              DateTime.now().difference(_lastReconcileAt!) > const Duration(seconds: 30));
      if (shouldReconcile) {
        _lastReconcileAt = DateTime.now();
        unawaited(_reconcileContactIds(contacts));
      }
    } catch (e) {
      developer.log('Load local contacts error: $e');
    }
  }

  Future<void> _reconcileContactIds(List<ContactModel> contacts) async {
    _isReconciling = true;
    try {
      final unresolved = contacts
          .where((c) => (c.contactId == null || c.contactId!.isEmpty) && (c.phoneNumber?.isNotEmpty ?? false))
          .toList();

      if (unresolved.isEmpty) return;

      final contactService = context.read<ContactService>();
      final isar = context.read<IsarService>();
      final updated = <ContactModel>[];

      for (final contact in unresolved) {
        final resolved = await contactService.addContactByPhone(contact.phoneNumber!);
        if (resolved != null) {
          contact.contactId = resolved.contactId;
          contact.isRegistered = true;
          contact.name = contact.name?.isNotEmpty == true ? contact.name : resolved.name;
          contact.updatedAt = DateTime.now();
          updated.add(contact);
        }
      }

      if (updated.isNotEmpty) {
        await contactService.upsertContactsByCanonical(isar, updated);
        await _loadLocalContacts();
      }
    } finally {
      _isReconciling = false;
    }
  }

  Future<void> _loadBalances({bool forceRefresh = false}) async {
    try {
      final expenseService = context.read<ExpenseService>();
      final raw = await expenseService.getBalances(forceRefresh: forceRefresh);
      final normalized = <String, int>{};
      raw.forEach((k, v) {
        normalized[k.toString()] = (v as num).round();
      });
      if (!mounted) return;
      setState(() => _balances = normalized);
    } catch (e) {
      developer.log('Load contact balances error: $e');
    }
  }

  int _balanceForContact(ContactModel c) {
    final byId = c.contactId != null ? _balances[c.contactId!] : null;
    if (byId != null) return byId;

    final phoneKey = _canonicalPhone(c.phoneNumber);
    for (final entry in _balances.entries) {
      if (_canonicalPhone(entry.key) == phoneKey) return entry.value;
    }
    return 0;
  }

  String _balanceText(int amount) {
    final rupees = amount.abs() / _currencyDivisor;
    if (amount > 0) return 'Owes you Rs ${rupees.toStringAsFixed(2)}';
    if (amount < 0) return 'You owe Rs ${rupees.toStringAsFixed(2)}';
    return 'Settled';
  }

  Color _balanceColor(int amount) {
    if (amount > 0) return AppColors.success;
    if (amount < 0) return AppColors.error;
    return AppColors.textSecondary;
  }

  Future<void> _openContactSelection() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const ContactSelectionScreen()),
    );

    if (result != null && result > 0) {
      await _refreshData(forceRefresh: true);
    }
  }

  Future<void> _syncContacts() async {
    setState(() => _syncing = true);

    try {
      final contactService = context.read<ContactService>();
      final matchedContacts = await contactService.matchContacts();

      if (matchedContacts.isEmpty) {
        if (mounted) {
          CustomSnackBar.show(context, message: 'No contacts found', isError: true);
        }
      } else {
        final isar = context.read<IsarService>();
        await contactService.upsertContactsByCanonical(isar, matchedContacts);

        // Notify all screens about contact updates
        contactService.notifyUpdate();

        await _refreshData(forceRefresh: true);

        if (mounted) {
          CustomSnackBar.show(context, message: 'Synced ${matchedContacts.length} contacts');
        }
      }
    } catch (e) {
      developer.log('Sync contacts error: $e');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Failed to sync contacts', isError: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addManualContact() async {
    final nameController = TextEditingController();
    String phoneNumber = '';

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'John Doe'),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                initialCountryCode: 'IN',
                disableLengthCheck: true,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                onChanged: (phone) {
                  setDialogState(() {
                    phoneNumber = phone.completeNumber;
                  });
                },
              ),
            ],
          ),
          actions: [
            CustomButton(
              text: 'Cancel',
              onPressed: () => Navigator.pop(context),
              isOutlined: true,
            ),
            CustomButton(
              text: 'Add',
              onPressed: () {
                if (nameController.text.isEmpty || phoneNumber.isEmpty) return;
                Navigator.pop(context, {'name': nameController.text, 'phone': phoneNumber});
              },
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _syncing = true);

    try {
      final contactService = context.read<ContactService>();
      final registered = await contactService.addContactByPhone(result['phone']!);

      final contact = registered ??
          ContactModel(
            name: result['name']!,
            phoneNumber: result['phone']!,
            isRegistered: false,
            createdAt: DateTime.now(),
          );
      if (registered != null && _looksLikePhoneName(contact.name)) {
        contact.name = result['name']!;
      }

      final isar = context.read<IsarService>();
      await contactService.upsertContactsByCanonical(isar, [contact]);

      // Notify all screens about contact updates
      contactService.notifyUpdate();

      await _refreshData(forceRefresh: true);

      if (mounted) {
        CustomSnackBar.show(context, message: 'Contact added: ${contact.name}');
      }
    } catch (e) {
      developer.log('Add manual contact error: $e');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Failed to add contact', isError: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_contacts.isEmpty) {
      return Column(
        children: [
          LoadingIndicator(isLoading: _syncing || _refreshing),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contacts_outlined, size: 64, color: AppColors.textTertiary),
                  AppDimensions.h20(context),
                  Text(
                    'No contacts found',
                    style: AppTextStyles.headlineSmall(context),
                  ),
                  AppDimensions.h10(context),
                  Text(
                    'Sync your device contacts to start splitting',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  AppDimensions.h20(context),
                  CustomButton(
                    text: 'Select from Contacts',
                    icon: Icons.contacts,
                    onPressed: _openContactSelection,
                  ),
                  AppDimensions.h10(context),
                  CustomButton(
                    text: 'Add by Phone Number',
                    icon: Icons.person_add,
                    onPressed: _addManualContact,
                    isOutlined: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final filtered = _query.trim().isEmpty
        ? _contacts
        : _contacts.where((c) {
            final q = _query.trim().toLowerCase();
            final name = (c.name ?? '').toLowerCase();
            final phone = (c.phoneNumber ?? '').toLowerCase();
            return name.contains(q) || phone.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: AppDimensions.appMargin(context),
        child: Column(
          children: [
            LoadingIndicator(isLoading: _syncing || _refreshing),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            AppDimensions.h20(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshData(forceRefresh: true),
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final balance = _balanceForContact(contact);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ConversationScreen(contact: contact)),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _balanceColor(balance).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  (contact.name ?? 'U')[0].toUpperCase(),
                                  style: TextStyle(
                                    color: _balanceColor(balance),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name ?? 'Unknown',
                                    style: AppTextStyles.titleMedium(context).copyWith(fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _balanceText(balance),
                                    style: AppTextStyles.labelLarge(context).copyWith(
                                      color: _balanceColor(balance),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openContactSelection,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
