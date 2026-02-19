import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../services/contact_service.dart';

class ContactProvider extends ChangeNotifier {
  final IsarService _isarService;
  final ContactService _contactService;
  List<ContactModel> _contacts = [];
  bool _isLoading = false;

  ContactProvider(this._isarService, this._contactService) {
    _contactService.updates.listen((_) => loadContacts());
    loadContacts();
  }

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;

  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final contacts = await _isarService.isar.contactModels.where().findAll();
      contacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      _contacts = contacts;
    } catch (e) {
      debugPrint('Load contacts error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ContactModel? getContactByPhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final canonical = _canonicalPhone(phone);
    for (final contact in _contacts) {
      if (_canonicalPhone(contact.phoneNumber) == canonical) {
        return contact;
      }
    }
    return null;
  }

  ContactModel? getContactById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final contact in _contacts) {
      if (contact.contactId == id) {
        return contact;
      }
    }
    return null;
  }

  String _canonicalPhone(String? phone) {
    if (phone == null) return '';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  bool _looksLikePhoneName(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }

  String getDisplayName(String? identifier) {
    if (identifier == null || identifier.isEmpty) return 'Unknown';

    // Try by ID first if it has a real name.
    final byId = getContactById(identifier);
    if (byId != null &&
        byId.name != null &&
        byId.name!.trim().isNotEmpty &&
        !_looksLikePhoneName(byId.name)) {
      return byId.name!.trim();
    }

    // Try best phone match and prefer non-phone-like names.
    final canonical = _canonicalPhone(identifier);
    if (canonical.isNotEmpty) {
      ContactModel? fallbackMatch;
      for (final contact in _contacts) {
        if (_canonicalPhone(contact.phoneNumber) != canonical) continue;
        final hasUsableName =
            contact.name != null && contact.name!.trim().isNotEmpty;
        if (!hasUsableName) continue;
        if (!_looksLikePhoneName(contact.name)) {
          return contact.name!.trim();
        }
        fallbackMatch ??= contact;
      }
      if (fallbackMatch != null && fallbackMatch.name != null) {
        return fallbackMatch.name!.trim();
      }
    }

    // Fallback direct phone lookup.
    final byPhone = getContactByPhone(identifier);
    if (byPhone != null &&
        byPhone.name != null &&
        byPhone.name!.trim().isNotEmpty) {
      return byPhone.name!.trim();
    }

    // If ID contact exists but only has phone-like name, still show it as last resort.
    if (byId != null && byId.name != null && byId.name!.trim().isNotEmpty) {
      return byId.name!.trim();
    }

    return identifier;
  }
}
