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
  final StreamController<int> _updatesController =
      StreamController<int>.broadcast();
  int _revision = 0;
  DateTime? _lookupBackoffUntil;
  DateTime? _autoSyncBackoffUntil;
  DateTime? _lastAutoSyncAt;

  ContactService(this._api);

  void _logResponseUser(String source, Map<String, dynamic> user,
      {int? index}) {}

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

  Future<void> autoSyncFromBalances(
      Map<String, dynamic> balances, IsarService isar) async {
    if (balances.isEmpty) return;
    final now = DateTime.now();
    if (_autoSyncBackoffUntil != null && now.isBefore(_autoSyncBackoffUntil!))
      return;
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
        developer.log('ContactService: auto-synced ${contacts.length} contacts from balances');
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

  String _normalizePhone(String phone) => PhoneUtils.normalizeRaw(phone);
  String _canonicalPhone(String phone) => PhoneUtils.canonical(phone);
  bool _looksLikePhoneName(String? value) =>
      PhoneUtils.looksLikePhoneName(value);

  bool get canAttemptLookup =>
      _lookupBackoffUntil == null ||
      DateTime.now().isAfter(_lookupBackoffUntil!);

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
    final incomingHasFreshData = incoming.contactId?.isNotEmpty ?? false;
    final mergedIsRegistered =
        incomingHasFreshData ? incoming.isRegistered : existing.isRegistered;

    // Prefer full number with + prefix for storage; fall back to whichever is longer
    final existingPhone = existing.phoneNumber ?? '';
    final incomingPhone = incoming.phoneNumber ?? '';
    String bestPhone;
    if (incomingPhone.startsWith('+')) {
      bestPhone = incomingPhone;
    } else if (existingPhone.startsWith('+')) {
      bestPhone = existingPhone;
    } else {
      bestPhone = incomingPhone.isNotEmpty ? incomingPhone : existingPhone;
    }

    final merged = ContactModel(
      contactId: (incoming.contactId?.isNotEmpty ?? false)
          ? incoming.contactId
          : existing.contactId,
      phoneNumber: bestPhone,
      name: existingNameGood
          ? existing.name
          : (incomingNameGood
              ? incoming.name
              : (existing.name?.isNotEmpty == true
                  ? existing.name
                  : incoming.name)),
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

  Future<void> upsertContactsByCanonical(
      IsarService isar, List<ContactModel> incoming) async {
    if (incoming.isEmpty) return;

    final existing =
        await isar.isar.contactModels.filter().idGreaterThan(-1).findAll();
    final existingByCanonical = <String, ContactModel>{};

    for (final c in existing) {
      final key = _canonicalPhone(c.phoneNumber ?? '');
      if (key.isEmpty) continue;
      final prev = existingByCanonical[key];
      if (prev == null) {
        existingByCanonical[key] = c;
      } else {
        final prevScore = (!_looksLikePhoneName(prev.name) ? 2 : 0) +
            ((prev.contactId?.isNotEmpty ?? false) ? 1 : 0);
        final currScore = (!_looksLikePhoneName(c.name) ? 2 : 0) +
            ((c.contactId?.isNotEmpty ?? false) ? 1 : 0);
        if (currScore > prevScore) existingByCanonical[key] = c;
      }
    }

    await isar.isar.writeTxn(() async {
      for (final raw in incoming) {
        final rawPhone = PhoneUtils.normalizeRaw(raw.phoneNumber ?? '');
        final key = _canonicalPhone(rawPhone);
        if (key.length < 7) continue; // too short to be valid

        // Store full number with country code if available
        raw.phoneNumber = rawPhone.isNotEmpty ? rawPhone : key;

        final existingContact = existingByCanonical[key];
        if (existingContact == null) {
          if (raw.name == null || raw.name!.trim().isEmpty)
            raw.name = raw.phoneNumber;
          raw.updatedAt = DateTime.now();
          await isar.isar.contactModels.put(raw);
          existingByCanonical[key] = raw;
          continue;
        }

        final merged = _mergeContact(existingContact, raw);
        await isar.isar.contactModels.put(merged);
        existingByCanonical[key] = merged;
      }

      // Cleanup duplicates
      final latestAll =
          await isar.isar.contactModels.filter().idGreaterThan(-1).findAll();
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
        await isar.isar.contactModels.put(keeper);
      }
      if (deleteIds.isNotEmpty) {
        await isar.isar.contactModels.deleteAll(deleteIds.toList());
      }
    });
  }

  Future<ContactModel?> addContactByPhone(String phoneNumber) async {
    final searchPhone = phoneNumber.startsWith('+')
        ? phoneNumber.trim()
        : _canonicalPhone(phoneNumber);
    if (searchPhone.length < 10 || !canAttemptLookup) return null;
    try {
      developer.log('[ContactService] GET /users/search?phone=$searchPhone', name: 'ContactService');
      final response = await _api.get('/users/search?phone=$searchPhone');
      final data = response.data['data'];
      if (data != null) {
        final user = data as Map<String, dynamic>;
        developer.log('[ContactService] /users/search found: id=${user['_id']}, name=${user['name']}, phone=${user['phoneNumber']}, registered=${user['isRegistered']}', name: 'ContactService');
        return ContactModel.fromJson(user);
      }
      developer.log('[ContactService] /users/search: no user found for $searchPhone', name: 'ContactService');
      return null;
    } catch (e) {
      if (_isNetworkIssue(e)) {
        _setLookupBackoff();
      }
      try {
        final users = await matchContactsList([
          {'name': searchPhone, 'phone': searchPhone}
        ]);
        if (users.isNotEmpty) return users.first;
      } catch (_) {}
      developer.log('ContactService: addContactByPhone error: $e');
      return null;
    }
  }

  Future<List<ContactModel>> matchContactsList(
      List<Map<String, dynamic>> contacts) async {
    try {
      if (contacts.isEmpty) return [];
      final sourceNameByPhone = <String, String>{};
      final payload = <Map<String, String>>[];
      for (final contact in contacts) {
        final rawPhone =
            PhoneUtils.normalizeRaw((contact['phone'] ?? '').toString());
        if (rawPhone.isEmpty) continue;
        final name = (contact['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        // Key for name lookup — canonical last 10 digits
        final canonicalPhone = _canonicalPhone(rawPhone);
        if (canonicalPhone.isEmpty) continue;
        sourceNameByPhone[canonicalPhone] = name;
        // Send full number to backend
        payload.add({'name': name, 'phone': rawPhone});
      }
      if (payload.isEmpty) return [];
      if (!canAttemptLookup) return [];

      final response = await _api.post(
        ApiConfig.matchContacts,
        data: {'contacts': payload},
      );

      final result = response.data['data'];
      final matchedUsers = result is Map<String, dynamic>
          ? (result['registeredUsers'] as List? ?? const [])
          : (result as List? ?? const []);
      developer.log('[ContactService] POST /contacts/match: sent=${payload.length}, registered=${matchedUsers.length}', name: 'ContactService');
      final models = <ContactModel>[];
      for (var i = 0; i < matchedUsers.length; i++) {
        final json = matchedUsers[i] as Map<String, dynamic>;
        if (json is! Map<String, dynamic>) continue;
        developer.log('[ContactService] matched[$i]: id=${json['_id']}, name=${json['name']}, phone=${json['phoneNumber']}', name: 'ContactService');
        final model = ContactModel.fromJson(json);
        // Backend returns full +countrycode number — preserve it
        final canonicalPhone = _canonicalPhone(model.phoneNumber ?? '');
        final fallbackName = sourceNameByPhone[canonicalPhone];
        if (_looksLikePhoneName(model.name) &&
            fallbackName != null &&
            fallbackName.isNotEmpty) {
          model.name = fallbackName;
        }
        if (model.phoneNumber?.isNotEmpty ?? false) {
          models.add(model);
        }
      }
      return models;
    } catch (e) {
      if (_isNetworkIssue(e)) _setLookupBackoff();
      developer.log('ContactService: matchContactsList error: $e');
      return [];
    }
  }

  Future<List<ContactModel>> matchContacts() async {
    try {
      // Request permission
      if (!await FlutterContacts.requestPermission()) {
        developer.log('ContactService: contact permission denied');
        return [];
      }

      // Read device contacts
      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      developer.log('ContactService: ${deviceContacts.length} device contacts found');

      // Prepare contacts for backend
      final contactsToMatch = deviceContacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => {
                'name': c.displayName,
                'phone': PhoneUtils.normalizeRaw(c.phones.first.number),
              })
          .toList();

      if (contactsToMatch.isEmpty) {
        developer.log('ContactService: no contacts with phone numbers');
        return [];
      }

      return await matchContactsList(contactsToMatch);
    } catch (e) {
      developer.log('ContactService: matchContacts error: $e');
      return [];
    }
  }
}
