import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import '../../services/contact_service.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/phone_utils.dart';
import '../../core/widgets/shadowed_app_bar.dart';

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
      developer.log('🔍 Checking contact permission...');
      
      final status = await Permission.contacts.status;
      developer.log('📱 Current permission status: $status');
      
      if (status.isDenied) {
        developer.log('⚠️ Permission denied, requesting...');
        final result = await Permission.contacts.request();
        developer.log('📱 Request result: $result');
        
        if (!result.isGranted) {
          developer.log('❌ Permission not granted, showing dialog');
          if (mounted) {
            final retry = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Contact Permission Required'),
                content: const Text('This app needs access to your contacts to find registered users. Please grant permission in settings.'),
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
            
            if (retry == true) {
              developer.log('🔧 Opening app settings');
              await openAppSettings();
            }
            Navigator.pop(context);
          }
          return;
        }
      }

      developer.log('✅ Permission granted, loading contacts...');
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      
      developer.log('📇 Loaded ${contacts.length} contacts');
      final contactsWithPhone = contacts.where((c) => c.phones.isNotEmpty).toList();
      developer.log('📞 Contacts with phone: ${contactsWithPhone.length}');

      if (mounted) {
        final preselected = await _loadPreviouslyAddedPhones(contactsWithPhone);
        setState(() {
          _deviceContacts = contactsWithPhone;
          _filteredContacts = contactsWithPhone;
          _selectedPhones = preselected;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      developer.log('❌ Load device contacts error: $e');
      developer.log('Stack trace: $stackTrace');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Failed to load contacts', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  Future<Set<String>> _loadPreviouslyAddedPhones(List<Contact> deviceContacts) async {
    try {
      final isar = context.read<IsarService>();
      final savedContacts = await isar.isar.contactModels.where().findAll();
      if (savedContacts.isEmpty) return <String>{};

      final savedCanonicalPhones = savedContacts
          .map((c) => _canonicalPhone(c.phoneNumber ?? ''))
          .where((p) => p.isNotEmpty)
          .toSet();

      return deviceContacts
          .map((c) => _normalizePhone(c.phones.first.number))
          .where((phone) => savedCanonicalPhones.contains(_canonicalPhone(phone)))
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  String _normalizePhone(String phone) => PhoneUtils.normalize(phone);
  String _canonicalPhone(String phone) => PhoneUtils.canonical(phone);
  bool _looksLikePhoneName(String? value) => PhoneUtils.looksLikePhoneName(value);

  Future<void> _syncSelected() async {
    if (_selectedPhones.isEmpty) {
      CustomSnackBar.show(context, message: 'Select at least one contact', isError: true);
      return;
    }

    setState(() => _syncing = true);

    try {
      final selectedContacts = _deviceContacts
          .where((c) => _selectedPhones.contains(_normalizePhone(c.phones.first.number)))
          .toList();

      // Try to match with backend
      final contactsData = selectedContacts.map((c) => {
        'name': c.displayName,
        'phone': _normalizePhone(c.phones.first.number),
      }).toList();

      final contactService = context.read<ContactService>();
      final registeredUsers = await contactService.matchContactsList(contactsData);

      developer.log('🔍 Sent ${contactsData.length} contacts to backend');
      developer.log('✅ Backend returned ${registeredUsers.length} registered users');
      for (var user in registeredUsers) {
        developer.log('  - ${user.name} (${user.phoneNumber})');
      }

      // Create map of registered users by canonical phone for robust matching.
      final registeredPhones = <String, ContactModel>{};
      for (final user in registeredUsers) {
        final phone = user.phoneNumber;
        if (phone == null || phone.isEmpty) continue;
        registeredPhones[_canonicalPhone(phone)] = user;
      }

      // Save ALL contacts (registered + unregistered)
      final isar = context.read<IsarService>();
      final allContacts = <ContactModel>[];

      for (var contact in selectedContacts) {
        final phone = _normalizePhone(contact.phones.first.number);
        final registered = registeredPhones[_canonicalPhone(phone)];

        if (registered != null) {
          if (_looksLikePhoneName(registered.name)) {
            registered.name = contact.displayName;
          }
          allContacts.add(registered);
        } else {
          // Add as unregistered contact (no contactId since not registered)
          allContacts.add(ContactModel(
            name: contact.displayName,
            phoneNumber: phone,
            isRegistered: false,
            createdAt: DateTime.now(),
          ));
        }
      }

      await contactService.upsertContactsByCanonical(isar, allContacts);

      developer.log('✅ Saved ${allContacts.length} contacts');
      developer.log('📊 Registered: ${allContacts.where((c) => c.isRegistered).length}');
      developer.log('📊 Unregistered: ${allContacts.where((c) => !c.isRegistered).length}');

      // Notify all screens about contact updates
      contactService.notifyUpdate();

      if (mounted) {
        CustomSnackBar.show(context, message: 'Added ${allContacts.length} contacts');
        Navigator.pop(context, allContacts.length);
      }
    } catch (e) {
      developer.log('Sync selected error: $e');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Failed to sync contacts', isError: true);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShadowedAppBar(
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Select Contacts'),
          actions: [
            if (_selectedPhones.isNotEmpty)
              TextButton(
                onPressed: _syncing ? null : _syncSelected,
                child: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Add (${_selectedPhones.length})',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deviceContacts.isEmpty
              ? const Center(child: Text('No contacts found'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search contacts...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
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
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final phone = _normalizePhone(contact.phones.first.number);
                          final isSelected = _selectedPhones.contains(phone);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedPhones.add(phone);
                                } else {
                                  _selectedPhones.remove(phone);
                                }
                              });
                            },
                            title: Text(contact.displayName),
                            subtitle: Text(phone),
                            secondary: CircleAvatar(
                              child: Text(contact.displayName[0].toUpperCase()),
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
