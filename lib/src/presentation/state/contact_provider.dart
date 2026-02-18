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
    return _contacts.firstWhere(
      (c) => _canonicalPhone(c.phoneNumber) == canonical,
      orElse: () => ContactModel(phoneNumber: phone, name: phone),
    );
  }

  ContactModel? getContactById(String? id) {
    if (id == null || id.isEmpty) return null;
    return _contacts.firstWhere(
      (c) => c.contactId == id,
      orElse: () => ContactModel(contactId: id, name: id),
    );
  }

  String _canonicalPhone(String? phone) {
    if (phone == null) return '';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  String getDisplayName(String? identifier) {
    if (identifier == null || identifier.isEmpty) return 'Unknown';
    
    // Try by ID first
    final byId = getContactById(identifier);
    if (byId != null && byId.name != null && byId.name!.isNotEmpty) {
      return byId.name!;
    }
    
    // Try by phone
    final byPhone = getContactByPhone(identifier);
    if (byPhone != null && byPhone.name != null && byPhone.name!.isNotEmpty) {
      return byPhone.name!;
    }
    
    return identifier;
  }
}
