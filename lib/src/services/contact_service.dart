import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:isar/isar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import '../data/models/contact_model.dart';
import '../data/repositories/isar_service.dart';
import '../core/constants/api_config.dart';
import 'api_service.dart';

class ContactService {
  final ApiService _api;
  final StreamController<int> _updatesController = StreamController<int>.broadcast();
  int _revision = 0;

  ContactService(this._api);

  Stream<int> get updates => _updatesController.stream;

  void notifyUpdate() {
    _revision++;
    if (!_updatesController.isClosed) {
      _updatesController.add(_revision);
    }
  }

  void dispose() {
    _updatesController.close();
  }

  Future<void> autoSyncFromBalances(Map<String, dynamic> balances, IsarService isar) async {
    if (balances.isEmpty) return;

    try {
      // Get balance response which already contains user info
      final response = await _api.get(ApiConfig.balances);
      final data = response.data['data'];
      
      if (data is! Map<String, dynamic>) return;
      
      final contacts = <ContactModel>[];
      
      // Extract from owesMe
      final owesMe = (data['owesMe'] as List?) ?? [];
      for (final item in owesMe) {
        if (item is! Map<String, dynamic>) continue;
        final user = item['user'];
        if (user is Map<String, dynamic>) {
          try {
            contacts.add(ContactModel.fromJson(user));
          } catch (e) {
            developer.log('Failed to parse user from owesMe: $e');
          }
        }
      }
      
      // Extract from iOwe
      final iOwe = (data['iOwe'] as List?) ?? [];
      for (final item in iOwe) {
        if (item is! Map<String, dynamic>) continue;
        final user = item['user'];
        if (user is Map<String, dynamic>) {
          try {
            contacts.add(ContactModel.fromJson(user));
          } catch (e) {
            developer.log('Failed to parse user from iOwe: $e');
          }
        }
      }

      if (contacts.isNotEmpty) {
        await isar.isar.writeTxn(() async {
          for (var contact in contacts) {
            final existing = await isar.isar.contactModels
                .filter()
                .phoneNumberEqualTo(contact.phoneNumber)
                .findFirst();
            if (existing != null) {
              contact.id = existing.id;
            }
          }
          await isar.isar.contactModels.putAll(contacts);
        });
        notifyUpdate();
        developer.log('Auto-synced ${contacts.length} contacts from balances');
      }
    } catch (e) {
      developer.log('Auto-sync contacts error: $e');
    }
  }

  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  String _normalizePhone(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    // Remove + and country code, keep last 10 digits
    String digits = cleaned.replaceAll('+', '').replaceAll(RegExp(r'^91'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  String _canonicalPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  bool _looksLikePhoneName(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }

  Future<ContactModel?> addContactByPhone(String phoneNumber) async {
    final normalized = _normalizePhone(phoneNumber);
    try {
      // Search user by phone in backend
      final response = await _api.get('/users/search?phone=$normalized');
      
      if (response.data['data'] != null) {
        return ContactModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      // Fallback: auto-create pending user via contact match flow.
      try {
        final users = await matchContactsList([
          {'name': normalized, 'phone': normalized}
        ]);
        if (users.isNotEmpty) {
          return users.first;
        }
      } catch (_) {}
      developer.log('Add contact by phone error: $e');
      return null;
    }
  }

  Future<List<ContactModel>> matchContactsList(List<Map<String, dynamic>> contacts) async {
    try {
      if (contacts.isEmpty) return [];
      final sourceNameByPhone = <String, String>{};
      for (final contact in contacts) {
        final phone = (contact['phone'] ?? '').toString();
        final name = (contact['name'] ?? '').toString().trim();
        if (phone.isEmpty || name.isEmpty) continue;
        sourceNameByPhone[_canonicalPhone(phone)] = name;
      }

      // Call backend to match
      final response = await _api.post(
        ApiConfig.matchContacts,
        data: {'contacts': contacts},
      );

      final result = response.data['data'];
      final matchedUsers = result is Map<String, dynamic>
          ? (result['registeredUsers'] as List? ?? const [])
          : (result as List? ?? const []);
      developer.log('Matched ${matchedUsers.length} users');
      return matchedUsers.map((json) {
        final model = ContactModel.fromJson(json);
        final fallbackName = sourceNameByPhone[_canonicalPhone(model.phoneNumber ?? '')];
        if (_looksLikePhoneName(model.name) && fallbackName != null && fallbackName.isNotEmpty) {
          model.name = fallbackName;
        }
        return model;
      }).toList();
    } catch (e) {
      developer.log('Match contacts list error: $e');
      return [];
    }
  }

  Future<List<ContactModel>> matchContacts() async {
    try {
      // Request permission
      if (!await FlutterContacts.requestPermission()) {
        developer.log('Contact permission denied');
        return [];
      }

      // Read device contacts
      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      developer.log('Found ${deviceContacts.length} device contacts');

      // Prepare contacts for backend
      final contactsToMatch = deviceContacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => {
                'name': c.displayName,
                'phone': _normalizePhone(c.phones.first.number),
              })
          .toList();

      if (contactsToMatch.isEmpty) {
        developer.log('No contacts with phone numbers');
        return [];
      }

      return await matchContactsList(contactsToMatch);
    } catch (e) {
      developer.log('Match contacts error: $e');
      return [];
    }
  }
}
