import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_sections.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_indicator.dart';
import '../../models/contact_model.dart';
import '../../services/isar_service.dart';
import '../../services/contact_service.dart';
import '../../services/expense_service.dart';
import '../../utils/money_utils.dart';
import '../../utils/phone_utils.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/network_error_handler.dart';
import 'contact_selection_screen.dart';
import 'conversation_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  static String persistedQuery = '';

  static void resetPersistedState() {
    persistedQuery = '';
  }

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactModel> _contacts = [];
  Map<String, int> _balances = {};
  Map<String, int> _balancesByCanonicalPhone = {};

  bool _refreshing = false;
  bool _syncing = false;
  bool _loadingMoreContacts = false;
  bool _hasMoreContacts = true;
  int _contactsOffset = 0;
  bool _contactsLoadInProgress = false;
  bool _pendingResetAfterLoad = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  Timer? _searchDebounce;

  StreamSubscription<int>? _updatesSub;
  StreamSubscription<int>? _contactUpdatesSub;
  static const int _pageSize = 40;
  bool _isReconciling = false;
  DateTime? _lastReconcileAt;

  @override
  void initState() {
    super.initState();
    _query = ContactsScreen.persistedQuery;
    _searchController.text = ContactsScreen.persistedQuery;
    _scrollController.addListener(_onScroll);
    unawaited(_refreshData(forceRefresh: false));
    _updatesSub = context.read<ExpenseService>().updates.listen((_) {
      if (mounted) _loadBalances(forceRefresh: true);
    });
    // Listen to contact updates
    _contactUpdatesSub = context.read<ContactService>().updates.listen((_) {
      if (mounted) {
        _loadLocalContacts(reset: true);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _updatesSub?.cancel();
    _contactUpdatesSub?.cancel();
    super.dispose();
  }

  String _canonicalPhone(String? phone) => PhoneUtils.canonical(phone);
  bool _looksLikePhoneName(String? value) =>
      PhoneUtils.looksLikePhoneName(value);

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loadingMoreContacts ||
        !_hasMoreContacts) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_loadLocalContacts());
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _query = value;
      ContactsScreen.persistedQuery = value;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        unawaited(_loadLocalContacts(reset: true));
      }
    });
  }

  Future<void> _refreshData({bool forceRefresh = false}) async {
    if (mounted) setState(() => _refreshing = true);
    await _loadLocalContacts(reset: true);
    await _loadBalances(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _loadLocalContacts({bool reset = false}) async {
    if (_contactsLoadInProgress) {
      if (reset) {
        _pendingResetAfterLoad = true;
        if (mounted) {
          setState(() => _refreshing = true);
        }
      }
      return;
    }
    try {
      final isarService = context.read<IsarService>();
      final requestQuery = _query;
      final int nextOffset = reset ? 0 : _contactsOffset;
      if (!reset && !_hasMoreContacts) return;
      _contactsLoadInProgress = true;

      if (mounted) {
        setState(() {
          if (reset) {
            _refreshing = true;
          } else {
            _loadingMoreContacts = true;
          }
        });
      }

      final contacts = await isarService.getContactsPage(
        offset: nextOffset,
        limit: _pageSize,
        query: requestQuery,
      );
      if (!mounted) return;
      if (_pendingResetAfterLoad && !reset) return;
      if (requestQuery != _query) return;
      setState(() {
        _contacts = reset ? contacts : [..._contacts, ...contacts];
        _contactsOffset = nextOffset + contacts.length;
        _hasMoreContacts = contacts.length == _pageSize;
      });

      // Non-blocking background reconciliation for contact IDs.
      final shouldReconcile = !_isReconciling &&
          (context.read<ContactService>().canAttemptLookup) &&
          (_lastReconcileAt == null ||
              DateTime.now().difference(_lastReconcileAt!) >
                  const Duration(seconds: 30));
      if (shouldReconcile) {
        _lastReconcileAt = DateTime.now();
        unawaited(_reconcileContactIds(contacts));
      }
    } catch (e) {
      developer.log('Load local contacts error: $e');
    } finally {
      _contactsLoadInProgress = false;
      if (_pendingResetAfterLoad) {
        _pendingResetAfterLoad = false;
        if (mounted) {
          unawaited(_loadLocalContacts(reset: true));
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _loadingMoreContacts = false;
      });
    }
  }

  Future<void> _reconcileContactIds(List<ContactModel> contacts) async {
    _isReconciling = true;
    try {
      final unresolved = contacts
          .where((c) =>
              (c.contactId == null || c.contactId!.isEmpty) &&
              (c.phoneNumber?.isNotEmpty ?? false))
          .toList();

      if (unresolved.isEmpty) return;

      final contactService = context.read<ContactService>();
      final isar = context.read<IsarService>();
      final updated = <ContactModel>[];

      for (final contact in unresolved) {
        final resolved =
            await contactService.addContactByPhone(contact.phoneNumber!);
        if (resolved != null && resolved.isRegistered) {
          contact.contactId = resolved.contactId;
          contact.isRegistered = resolved.isRegistered;
          contact.name =
              contact.name?.isNotEmpty == true ? contact.name : resolved.name;
          contact.updatedAt = DateTime.now();
          updated.add(contact);
        }
      }

      if (updated.isNotEmpty) {
        await contactService.upsertContactsByCanonical(isar, updated);
        await _loadLocalContacts(reset: true);
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
      final normalizedByCanonicalPhone = <String, int>{};
      raw.forEach((k, v) {
        final key = k.toString();
        final amount = (v as num).round();
        normalized[key] = amount;
        final canonicalPhone = _canonicalPhone(key);
        if (canonicalPhone.isNotEmpty) {
          normalizedByCanonicalPhone.putIfAbsent(canonicalPhone, () => amount);
        }
      });
      if (!mounted) return;
      setState(() {
        _balances = normalized;
        _balancesByCanonicalPhone = normalizedByCanonicalPhone;
      });
    } catch (e) {
      developer.log('Load contact balances error: $e');
    }
  }

  int _balanceForContact(ContactModel c) {
    final byId = c.contactId != null ? _balances[c.contactId!] : null;
    if (byId != null) return byId;

    final phoneKey = _canonicalPhone(c.phoneNumber);
    return _balancesByCanonicalPhone[phoneKey] ?? 0;
  }

  Color _balanceColor(int amount) {
    if (amount > 0) return AppColors.success;
    if (amount < 0) return AppColors.error;
    return AppColors.textSecondary;
  }

  int _owedToYouTotal() {
    return _balances.values.fold<int>(0, (sum, value) {
      final amount = (value as num).round();
      return amount > 0 ? sum + amount : sum;
    });
  }

  int _youOweTotal() {
    return _balances.values.fold<int>(0, (sum, value) {
      final amount = (value as num).round();
      return amount < 0 ? sum + amount.abs() : sum;
    });
  }

  String _balanceLabel(int amount) {
    if (amount > 0) return "You’ll get";
    if (amount < 0) return "You’ll pay";
    return 'Settled';
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
          CustomSnackBar.show(context,
              message: 'No contacts found', isError: true);
        }
      } else {
        final isar = context.read<IsarService>();
        await contactService.upsertContactsByCanonical(isar, matchedContacts);

        // Notify all screens about contact updates
        contactService.notifyUpdate();

        await _refreshData(forceRefresh: true);

        if (mounted) {
          CustomSnackBar.show(context,
              message: 'Synced ${matchedContacts.length} contacts');
        }
      }
    } catch (e) {
      developer.log('Sync contacts error: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: NetworkErrorHandler.message(
            e,
            fallback: 'Failed to sync contacts',
          ),
          isError: true,
        );
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
                decoration: const InputDecoration(
                    labelText: 'Name', hintText: 'John Doe'),
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
                Navigator.pop(context,
                    {'name': nameController.text, 'phone': phoneNumber});
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
      final registered =
          await contactService.addContactByPhone(result['phone']!);

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
        CustomSnackBar.show(
          context,
          message: NetworkErrorHandler.message(
            e,
            fallback: 'Failed to add contact',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferredCurrencyCode =
        context.watch<AppPreferencesService>().preferredCurrencyCode;
    final hasSearch = _query.trim().isNotEmpty;
    final owedToYouTotal = _owedToYouTotal();
    final youOweTotal = _youOweTotal();

    Widget buildEmptyState({
      required String title,
      required String message,
      required bool showActions,
    }) {
      return RefreshIndicator(
        onRefresh: () => _refreshData(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: AppDimensions.compactCardMargin(context).bottom),
          children: [
            AppDimensions.h20(context),
            AppEmptyStateCard(
              icon: hasSearch ? Icons.search_off_rounded : Icons.contacts_outlined,
              title: title,
              message: message,
              action: showActions
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: AppDimensions.appMargin(context),
          child: Column(
            children: [
              LoadingIndicator(isLoading: _syncing || _refreshing),
              AppCard(
                type: AppCardType.outlined,
                padding: AppDimensions.fieldPadding(context),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search people or phone numbers',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              AppDimensions.h10(context),
              Row(
                children: [
                  Expanded(
                    child: _CompactSummaryCard(
                      label: "You'll get",
                      amount: owedToYouTotal,
                      currencyCode: preferredCurrencyCode,
                      color: AppColors.success,
                      icon: Icons.call_received_rounded,
                    ),
                  ),
                  AppDimensions.w10(context),
                  Expanded(
                    child: _CompactSummaryCard(
                      label: "You'll pay",
                      amount: youOweTotal,
                      currencyCode: preferredCurrencyCode,
                      color: AppColors.error,
                      icon: Icons.call_made_rounded,
                    ),
                  ),
                ],
              ),
              AppDimensions.h20(context),
              AppSectionHeader(
                title: 'People',
                subtitle: 'Each card shows the current balance and quick status.',
                action: TextButton.icon(
                  onPressed: _openContactSelection,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add contact'),
                  style: TextButton.styleFrom(
                    padding: AppDimensions.buttonMargin(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              AppDimensions.h10(context),
              Expanded(
                child: _contacts.isEmpty
                    ? buildEmptyState(
                        title: hasSearch
                            ? 'No people match your search'
                            : 'No contacts yet',
                        message: hasSearch
                            ? 'Try a different name or phone number.'
                            : 'Sync device contacts or add someone by phone to start splitting bills.',
                        showActions: !hasSearch,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _refreshData(forceRefresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount:
                              _contacts.length + (_loadingMoreContacts ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _contacts.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppDimensions.compactCardMargin(context).bottom,
                                ),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final contact = _contacts[index];
                            final balance = _balanceForContact(contact);
                            final displayName =
                                contact.name?.trim().isNotEmpty == true
                                    ? contact.name!.trim()
                                    : 'Unknown';
                            final amountText = formatMinorUnits(
                              balance.abs(),
                              currencyCode: preferredCurrencyCode,
                            );
                            final balanceLabel = _balanceLabel(balance);
                            final balanceColor = _balanceColor(balance);
                            final initials = displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?';

                            return AppCard(
                              type: AppCardType.elevated,
                              margin: AppDimensions.compactCardMargin(context),
                              padding: AppDimensions.compactCardPadding(context),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ConversationScreen(contact: contact),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          balanceColor.withValues(alpha: 0.18),
                                          balanceColor.withValues(alpha: 0.08),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: balanceColor.withValues(alpha: 0.20),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: AppTextStyles.titleSmall(context).copyWith(
                                        color: balanceColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.titleSmall(
                                                  context,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (contact.isRegistered) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.verified_rounded,
                                                size: 15,
                                                color: AppColors.success,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          contact.phoneNumber ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodySmall(context)
                                              .copyWith(fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          amountText,
                                          style: AppTextStyles.labelLarge(context).copyWith(
                                            color: balanceColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: balanceColor.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: balanceColor.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Text(
                                          balanceLabel,
                                          style: AppTextStyles.labelSmall(context).copyWith(
                                            color: balanceColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactSummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final String currencyCode;
  final Color color;
  final IconData icon;

  const _CompactSummaryCard({
    required this.label,
    required this.amount,
    required this.currencyCode,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: AppCardType.elevated,
      padding: AppDimensions.compactCardPadding(context),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall(context).copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMinorUnits(amount, currencyCode: currencyCode, absolute: true),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge(context).copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
