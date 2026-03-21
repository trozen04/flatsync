import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../utils/phone_utils.dart';
import 'package:isar/isar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import '../models/contact_model.dart';
import '../services/isar_service.dart';
import '../constants/api_config.dart';
import 'api_service.dart';

class ContactService {
  final ApiService _api;
  final StreamController<int> _updatesController = StreamController<int>.broadcast();
  int _revision = 0;
  DateTime? _lookupBackoffUntil;
  DateTime? _autoSyncBackoffUntil;
  DateTime? _lastAutoSyncAt;

  ContactService(this._api);

  void _logResponseUser(String source, Map<String, dynamic> user, {int? index}) {
    final id = user['_id'] ?? user['id'];
    final phone = user['phoneNumber'];
    final name = user['name'];
    final suffix = index == null ? '' : '[$index]';
    developer.log('$source$suffix user -> id=$id, phone=$phone, name=$name');
  }

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
    final now = DateTime.now();
    if (_autoSyncBackoffUntil != null && now.isBefore(_autoSyncBackoffUntil!)) return;
    if (_lastAutoSyncAt != null &&
        now.difference(_lastAutoSyncAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastAutoSyncAt = now;

    try {
      // Get balance response which already contains user info
      final response = await _api.get(ApiConfig.balances);
      final data = response.data['data'];
      
      if (data is! Map<String, dynamic>) return;
      
      final contacts = <ContactModel>[];
      
      // Extract from owesMe
      final owesMe = (data['owesMe'] as List?) ?? [];
      for (var i = 0; i < owesMe.length; i++) {
        final item = owesMe[i];
        if (item is! Map<String, dynamic>) continue;
        final user = item['user'];
        if (user is Map<String, dynamic>) {
          try {
            _logResponseUser('balances.owesMe', user, index: i);
            contacts.add(ContactModel.fromJson(user));
          } catch (e) {
            developer.log('Failed to parse user from owesMe: $e');
          }
        }
      }
      
      // Extract from iOwe
      final iOwe = (data['iOwe'] as List?) ?? [];
      for (var i = 0; i < iOwe.length; i++) {
        final item = iOwe[i];
        if (item is! Map<String, dynamic>) continue;
        final user = item['user'];
        if (user is Map<String, dynamic>) {
          try {
            _logResponseUser('balances.iOwe', user, index: i);
            contacts.add(ContactModel.fromJson(user));
          } catch (e) {
            developer.log('Failed to parse user from iOwe: $e');
          }
        }
      }

      if (contacts.isNotEmpty) {
        await upsertContactsByCanonical(isar, contacts);
        notifyUpdate();
        developer.log('Auto-synced ${contacts.length} contacts from balances');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('429')) {
        _autoSyncBackoffUntil = DateTime.now().add(const Duration(minutes: 2));
        return;
      }
      if (_isNetworkIssue(e)) {
        _autoSyncBackoffUntil = DateTime.now().add(const Duration(seconds: 45));
        return;
      }
      developer.log('Auto-sync contacts error: $e');
    }
  }

  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  String _normalizePhone(String phone) => PhoneUtils.normalize(phone);
  String _canonicalPhone(String phone) => PhoneUtils.canonical(phone);
  bool _looksLikePhoneName(String? value) => PhoneUtils.looksLikePhoneName(value);

  bool get canAttemptLookup =>
      _lookupBackoffUntil == null || DateTime.now().isAfter(_lookupBackoffUntil!);

  void _setLookupBackoff([Duration duration = const Duration(seconds: 45)]) {
    _lookupBackoffUntil = DateTime.now().add(duration);
  }

  bool _isNetworkIssue(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('timeout') ||
        msg.contains('socketexception') ||
        msg.contains('connection');
  }

  ContactModel _mergeContact(ContactModel existing, ContactModel incoming) {
    final existingNameGood = !_looksLikePhoneName(existing.name);
    final incomingNameGood = !_looksLikePhoneName(incoming.name);

    // Use incoming.isRegistered if it came from a fresh API response (has contactId),
    // otherwise keep the existing value to avoid stale overrides.
    final incomingHasFreshData = incoming.contactId?.isNotEmpty ?? false;
    final mergedIsRegistered = incomingHasFreshData ? incoming.isRegistered : existing.isRegistered;

    developer.log(
      '_mergeContact: phone=${_canonicalPhone(incoming.phoneNumber ?? existing.phoneNumber ?? '')} '
      'existing.isRegistered=${existing.isRegistered} incoming.isRegistered=${incoming.isRegistered} '
      'incomingHasFreshData=$incomingHasFreshData -> merged=$mergedIsRegistered',
    );

    final merged = ContactModel(
      contactId: (incoming.contactId?.isNotEmpty ?? false) ? incoming.contactId : existing.contactId,
      phoneNumber: _canonicalPhone(incoming.phoneNumber ?? existing.phoneNumber ?? ''),
      name: existingNameGood
          ? existing.name
          : (incomingNameGood ? incoming.name : (existing.name?.isNotEmpty == true ? existing.name : incoming.name)),
      isRegistered: mergedIsRegistered,
      createdAt: existing.createdAt ?? incoming.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    merged.id = existing.id;

    if (merged.name == null || merged.name!.trim().isEmpty) {
      merged.name = merged.phoneNumber;
    }
    return merged;
  }

  Future<void> upsertContactsByCanonical(IsarService isar, List<ContactModel> incoming) async {
    if (incoming.isEmpty) return;

    final existing = await isar.isar.contactModels.where().findAll();
    final existingByCanonical = <String, ContactModel>{};

    // Build map with best candidate if duplicates already exist.
    for (final c in existing) {
      final key = _canonicalPhone(c.phoneNumber ?? '');
      if (key.isEmpty) continue;
      final prev = existingByCanonical[key];
      if (prev == null) {
        existingByCanonical[key] = c;
      } else {
        final prevScore = (!_looksLikePhoneName(prev.name) ? 2 : 0) + ((prev.contactId?.isNotEmpty ?? false) ? 1 : 0);
        final currScore = (!_looksLikePhoneName(c.name) ? 2 : 0) + ((c.contactId?.isNotEmpty ?? false) ? 1 : 0);
        if (currScore > prevScore) existingByCanonical[key] = c;
      }
    }

    await isar.isar.writeTxn(() async {
      for (final raw in incoming) {
        final key = _canonicalPhone(raw.phoneNumber ?? '');
        if (key.length < 10) continue;

        raw.phoneNumber = key;
        final existingContact = existingByCanonical[key];
        if (existingContact == null) {
          if (raw.name == null || raw.name!.trim().isEmpty) raw.name = key;
          raw.updatedAt = DateTime.now();
          await isar.isar.contactModels.put(raw);
          existingByCanonical[key] = raw;
          continue;
        }

        final merged = _mergeContact(existingContact, raw);
        await isar.isar.contactModels.put(merged);
        existingByCanonical[key] = merged;
      }

      // Cleanup already-duplicated rows sharing same canonical phone.
      final latestAll = await isar.isar.contactModels.where().findAll();
      final keeperByCanonical = <String, ContactModel>{};
      final deleteIds = <Id>{};
      for (final c in latestAll) {
        final key = _canonicalPhone(c.phoneNumber ?? '');
        if (key.isEmpty) continue;
        final keeper = keeperByCanonical[key];
        if (keeper == null) {
          keeperByCanonical[key] = c;
          continue;
        }
        final merged = _mergeContact(keeper, c);
        keeperByCanonical[key] = merged;
        deleteIds.add(keeper.id == merged.id ? c.id : keeper.id);
      }
      for (final keeper in keeperByCanonical.values) {
        keeper.phoneNumber = _canonicalPhone(keeper.phoneNumber ?? '');
        await isar.isar.contactModels.put(keeper);
      }
      if (deleteIds.isNotEmpty) {
        await isar.isar.contactModels.deleteAll(deleteIds.toList());
      }
    });
  }

  Future<ContactModel?> addContactByPhone(String phoneNumber) async {
    final normalized = _normalizePhone(phoneNumber);
    if (normalized.length < 10 || !canAttemptLookup) return null;
    try {
      // Search user by phone in backend
      final response = await _api.get('/users/search?phone=$normalized');
      
      if (response.data['data'] != null) {
        final user = response.data['data'] as Map<String, dynamic>;
        _logResponseUser('users.search', user);
        return ContactModel.fromJson(user);
      }
      return null;
    } catch (e) {
      if (_isNetworkIssue(e)) {
        _setLookupBackoff();
      }
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
      final payload = <Map<String, String>>[];
      for (final contact in contacts) {
        final phone = (contact['phone'] ?? '').toString();
        final canonical = _canonicalPhone(phone);
        if (canonical.length < 10) continue;
        final name = (contact['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        sourceNameByPhone[canonical] = name;
        payload.add({'name': name, 'phone': canonical});
      }
      if (payload.isEmpty) return [];
      if (!canAttemptLookup) return [];

      // Call backend to match
      final response = await _api.post(
        ApiConfig.matchContacts,
        data: {'contacts': payload},
      );

      final result = response.data['data'];
      developer.log('matchContactsList raw response: $result');
      final matchedUsers = result is Map<String, dynamic>
          ? (result['registeredUsers'] as List? ?? const [])
          : (result as List? ?? const []);
      developer.log('matchContactsList: sent ${payload.length} contacts, got ${matchedUsers.length} registered users back');
      final models = <ContactModel>[];
      for (var i = 0; i < matchedUsers.length; i++) {
        final json = matchedUsers[i];
        if (json is! Map<String, dynamic>) continue;
        _logResponseUser('contacts.match', json, index: i);
        final model = ContactModel.fromJson(json);
        model.phoneNumber = _canonicalPhone(model.phoneNumber ?? '');
        final fallbackName = sourceNameByPhone[_canonicalPhone(model.phoneNumber ?? '')];
        if (_looksLikePhoneName(model.name) && fallbackName != null && fallbackName.isNotEmpty) {
          model.name = fallbackName;
        }
        if (model.phoneNumber?.isNotEmpty ?? false) {
          models.add(model);
        }
      }
      return models;
    } catch (e) {
      if (_isNetworkIssue(e)) {
        _setLookupBackoff();
      }
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

