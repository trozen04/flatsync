import 'package:flatsync/models/expense_model.dart';
import 'package:flatsync/models/user_model.dart';
import 'package:flatsync/models/contact_model.dart';
import 'package:flatsync/utils/phone_utils.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  late Isar isar;

  int _compareContactsByLatestDate(ContactModel a, ContactModel b) {
    final aDate =
        a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateComp = bDate.compareTo(aDate);
    if (dateComp != 0) return dateComp;
    final aName = (a.name ?? '').trim().toLowerCase();
    final bName = (b.name ?? '').trim().toLowerCase();
    return aName.compareTo(bName);
  }

  Future<void> touchContactActivity(String? phoneNumber, {String? contactId}) async {
    final rawPhone = PhoneUtils.normalizeRaw(phoneNumber ?? '');
    final key = PhoneUtils.canonical(rawPhone);
    if (key.isEmpty && (contactId == null || contactId.isEmpty)) return;

    final all = await isar.contactModels.filter().idGreaterThan(-1).findAll();
    ContactModel? target;
    for (final c in all) {
      if (key.isNotEmpty && PhoneUtils.canonical(c.phoneNumber ?? '') == key) {
        target = c;
        break;
      }
      if (contactId != null &&
          contactId.isNotEmpty &&
          c.contactId == contactId) {
        target = c;
        break;
      }
    }

    if (target != null) {
      target.updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.contactModels.put(target!);
      });
    }
  }

  Future<void> openDB() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        ExpenseModelSchema,
        UserModelSchema,
        ContactModelSchema,
      ],
      directory: dir.path,
      maxSizeMiB: 256,
    );
  }

  Future<List<ExpenseModel>> getAllExpenses() async {
    return await isar.expenseModels.where().findAll();
  }

  Future<void> upsertExpense(ExpenseModel expense) async {
    await isar.writeTxn(() async {
      final existing = await isar.expenseModels.where().uuidEqualTo(expense.uuid).findFirst();
      if (existing != null) {
        if (!expense.lastModifiedAt.isBefore(existing.lastModifiedAt)) {
          expense.id = existing.id;
          await isar.expenseModels.put(expense);
        }
      } else {
        await isar.expenseModels.put(expense);
      }
    });
  }

  Future<void> batchUpsertExpenses(List<ExpenseModel> expenses) async {
    await isar.writeTxn(() async {
      for (final expense in expenses) {
        final existing = await isar.expenseModels.where().uuidEqualTo(expense.uuid).findFirst();
        if (existing != null) {
          if (!expense.lastModifiedAt.isBefore(existing.lastModifiedAt)) {
            expense.id = existing.id;
            await isar.expenseModels.put(expense);
          }
        } else {
          await isar.expenseModels.put(expense);
        }
      }
    });
  }

  Future<void> replaceCurrentUser(UserModel user) async {
    await isar.writeTxn(() async {
      await isar.userModels.clear();
      await isar.userModels.put(user);
    });
  }

  Future<UserModel?> getCurrentUserLocal() async {
    return await isar.userModels.where().findFirst();
  }

  Future<UserModel?> updateCurrentUserLocal({String? name}) async {
    UserModel? updated;
    await isar.writeTxn(() async {
      final existing = await isar.userModels.where().findFirst();
      if (existing == null) return;
      if (name != null) existing.name = name;
      existing.updatedAt = DateTime.now();
      await isar.userModels.put(existing);
      updated = existing;
    });
    return updated;
  }

  Future<int> getExpenseCount() async {
    return await isar.expenseModels.count();
  }

  Future<List<ContactModel>> getContactsPage({
    required int offset,
    required int limit,
    String query = '',
  }) async {
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit < 1 ? 25 : limit;
    final trimmedQuery = query.trim();
    final searchTerm = trimmedQuery.toLowerCase();
    final allContacts = await isar.contactModels.filter().idGreaterThan(-1).findAll();

    // Deduplicate by canonical phone number so different formatting variants merge into one entity
    final uniqueMap = <String, ContactModel>{};
    for (final contact in allContacts) {
      final key = PhoneUtils.canonical(contact.phoneNumber);
      if (key.isEmpty) continue;
      final prev = uniqueMap[key];
      if (prev == null) {
        uniqueMap[key] = contact;
      } else {
        final prevScore = (!PhoneUtils.looksLikePhoneName(prev.name) ? 2 : 0) +
            ((prev.contactId?.isNotEmpty ?? false) ? 2 : 0) +
            ((prev.phoneNumber?.startsWith('+') ?? false) ? 1 : 0);
        final currScore = (!PhoneUtils.looksLikePhoneName(contact.name) ? 2 : 0) +
            ((contact.contactId?.isNotEmpty ?? false) ? 2 : 0) +
            ((contact.phoneNumber?.startsWith('+') ?? false) ? 1 : 0);
        if (currScore > prevScore) {
          uniqueMap[key] = contact;
        }
      }
    }

    final deduplicated = uniqueMap.values.toList();

    final filtered = trimmedQuery.isEmpty
        ? deduplicated
        : deduplicated.where((contact) {
            final name = (contact.name ?? '').toLowerCase();
            final phone = (contact.phoneNumber ?? '').toLowerCase();
            return name.contains(searchTerm) || phone.contains(searchTerm);
          }).toList();

    filtered.sort(_compareContactsByLatestDate);

    if (safeOffset >= filtered.length) return <ContactModel>[];
    final end = (safeOffset + safeLimit) > filtered.length
        ? filtered.length
        : (safeOffset + safeLimit);
    return filtered.sublist(safeOffset, end);
  }

  Future<void> deleteContact(int id, {String? contactId, String? phoneNumber}) async {
    await isar.writeTxn(() async {
      await isar.contactModels.delete(id);
      if (contactId != null && contactId.isNotEmpty) {
        final matching = await isar.contactModels.filter().contactIdEqualTo(contactId).findAll();
        for (final m in matching) {
          await isar.contactModels.delete(m.id);
        }
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final key = PhoneUtils.canonical(phoneNumber);
        final all = await isar.contactModels.filter().idGreaterThan(-1).findAll();
        for (final m in all) {
          if (PhoneUtils.canonical(m.phoneNumber ?? '') == key) {
            await isar.contactModels.delete(m.id);
          }
        }
      }
    });
  }

  Future<void> close() async {
    await isar.close();
  }

  Future<void> clearUserData() async {
    await isar.writeTxn(() async {
      await isar.expenseModels.clear();
      await isar.contactModels.clear();
      await isar.userModels.clear();
    });
  }

  Future<void> removeContactsNotInBalances(Set<String> activeIds) async {
    final all = await isar.contactModels.filter().idGreaterThan(-1).findAll();
    final toDelete = all
        .where((c) =>
            c.contactId != null &&
            c.contactId!.isNotEmpty &&
            !activeIds.contains(c.contactId))
        .map((c) => c.id)
        .toList();
    if (toDelete.isEmpty) return;
    await isar.writeTxn(() async {
      await isar.contactModels.deleteAll(toDelete);
    });
  }

  // Upsert contacts from balance response — adds missing, updates existing by canonical phone
  Future<void> upsertBalanceContacts(List<ContactModel> contacts) async {
    if (contacts.isEmpty) return;
    final allExisting = await isar.contactModels.filter().idGreaterThan(-1).findAll();
    final existingByCanonical = <String, ContactModel>{};
    for (final c in allExisting) {
      final key = PhoneUtils.canonical(c.phoneNumber);
      if (key.isNotEmpty) existingByCanonical[key] = c;
    }

    await isar.writeTxn(() async {
      for (final contact in contacts) {
        final rawPhone = PhoneUtils.normalizeRaw(contact.phoneNumber ?? '');
        final key = PhoneUtils.canonical(rawPhone);
        if (key.isEmpty) continue;

        contact.phoneNumber = rawPhone;
        final existing = existingByCanonical[key];
        if (existing == null) {
          contact.updatedAt = DateTime.now();
          await isar.contactModels.put(contact);
          existingByCanonical[key] = contact;
        } else {
          // Merge metadata into existing contact
          if (contact.contactId?.isNotEmpty ?? false) {
            existing.contactId = contact.contactId;
            existing.isRegistered = contact.isRegistered;
          }
          if (rawPhone.startsWith('+')) {
            existing.phoneNumber = rawPhone;
          }
          if (!PhoneUtils.looksLikePhoneName(contact.name)) {
            existing.name = contact.name;
          }
          existing.updatedAt = DateTime.now();
          await isar.contactModels.put(existing);
        }
      }
    });
  }
}
