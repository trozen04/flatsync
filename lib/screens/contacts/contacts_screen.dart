import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_ads.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_shadows.dart';
import '../../constants/app_text_styles.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_page_sections.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/native_ad_widget.dart';
import '../../models/contact_model.dart';
import '../../services/isar_service.dart';
import '../../services/auth_service.dart';
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
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen> {
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
      if (mounted) unawaited(_syncBalancesSilently());
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
    if (mounted) {
      setState(() {
        _refreshing = true;
        _syncing = true;
      });
    }
    try {
      await _loadLocalContacts(reset: true);
      await _loadBalances(forceRefresh: forceRefresh);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _syncing = false;
        });
      }
    }
  }

  Future<void> _syncBalancesSilently() async {
    if (mounted) setState(() => _syncing = true);
    try {
      await _loadBalances(forceRefresh: false);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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
      final contactService = context.read<ContactService>();
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
      developer.log(
          '[ContactsScreen] local contacts loaded: ${contacts.length} (offset=$nextOffset, query="$requestQuery")',
          name: 'ContactsScreen');
      setState(() {
        _contacts = reset ? contacts : [..._contacts, ...contacts];
        _contactsOffset = nextOffset + contacts.length;
        _hasMoreContacts = contacts.length == _pageSize;
      });

      // Non-blocking background reconciliation for contact IDs.
      final shouldReconcile = !_isReconciling &&
          contactService.canAttemptLookup &&
          (_lastReconcileAt == null ||
              DateTime.now().difference(_lastReconcileAt!) >
                  const Duration(minutes: 5));
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
      } else if (mounted) {
        setState(() {
          _refreshing = false;
          _loadingMoreContacts = false;
        });
      }
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

      // Batch match in a single network call instead of looping individual requests
      final payload = unresolved
          .map((c) => {'name': c.name ?? c.phoneNumber!, 'phone': c.phoneNumber!})
          .toList();
      final resolvedList = await contactService.matchContactsList(payload);

      if (resolvedList.isEmpty) return;

      final updated = <ContactModel>[];
      for (final resolved in resolvedList) {
        final contact = unresolved.firstWhere(
          (c) => PhoneUtils.isSameNumber(c.phoneNumber, resolved.phoneNumber),
          orElse: () => ContactModel(),
        );
        if (contact.phoneNumber != null && (resolved.contactId?.isNotEmpty ?? false)) {
          contact.contactId = resolved.contactId;
          contact.isRegistered = resolved.isRegistered;
          if (_looksLikePhoneName(contact.name) && (resolved.name?.isNotEmpty ?? false)) {
            contact.name = resolved.name;
          }
          contact.updatedAt = DateTime.now();
          updated.add(contact);
        }
      }

      if (updated.isNotEmpty) {
        await contactService.upsertContactsByCanonical(isar, updated);
        if (mounted) {
          final isarService = context.read<IsarService>();
          final refreshed = await isarService.getContactsPage(
            offset: 0,
            limit: _contactsOffset > 0 ? _contactsOffset : _pageSize,
            query: _query,
          );
          if (mounted) {
            setState(() {
              _contacts = refreshed;
            });
          }
        }
      }
    } catch (e) {
      developer.log('Reconcile contact IDs error: $e');
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
      developer.log(
          '[ContactsScreen] balances loaded: ${normalized.length} entries, owedToYou=${normalized.values.where((v) => v > 0).fold(0, (a, b) => a + b)}, youOwe=${normalized.values.where((v) => v < 0).fold(0, (a, b) => a + b.abs())}',
          name: 'ContactsScreen');
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

  bool _isNativeAdSlot(int index) {
    const interval = AppAds.nativeAdEveryN;
    return interval > 0 &&
        _contacts.length >= interval &&
        (index + 1) % (interval + 1) == 0;
  }

  int _realItemIndexForDisplayIndex(int displayIndex) {
    const interval = AppAds.nativeAdEveryN;
    if (interval <= 0) return displayIndex;
    final adSlotsBefore = (displayIndex + 1) ~/ (interval + 1);
    return displayIndex - adSlotsBefore;
  }

  int _displayItemCount() {
    const interval = AppAds.nativeAdEveryN;
    final adCount = interval > 0 ? _contacts.length ~/ interval : 0;
    return _contacts.length + adCount + (_loadingMoreContacts ? 1 : 0);
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

  int get owedToYouTotalAmount => _owedToYouTotal();
  int get youOweTotalAmount => _youOweTotal();
  bool get hasActiveBalances => _owedToYouTotal() > 0 || _youOweTotal() > 0;

  void showBalanceSummary() {
    final preferredCurrencyCode =
        context.read<AppPreferencesService>().preferredCurrencyCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BalanceSummaryBottomSheet(
        owedToYouTotal: _owedToYouTotal(),
        youOweTotal: _youOweTotal(),
        preferredCurrencyCode: preferredCurrencyCode,
      ),
    );
  }

  void showAddContactSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddContactBottomSheet(
        onSelectContacts: () {
          Navigator.of(context).pop();
          openContactSelection();
        },
        onAddByPhone: () {
          Navigator.of(context).pop();
          addManualContact();
        },
      ),
    );
  }

  Future<void> openContactSelection() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const ContactSelectionScreen()),
    );

    if (result != null && result > 0) {
      await _refreshData(forceRefresh: true);
    }
  }

  Future<bool?> _confirmDeleteContact(ContactModel contact) async {
    final overlay = Overlay.of(context);
    final authService = context.read<AuthService>();
    final isar = context.read<IsarService>();
    final contactService = context.read<ContactService>();

    final pin = await AppPinDialog.show(
      context,
      title: 'Remove Contact',
      subtitle:
          'Enter your PIN to remove ${contact.name ?? 'this contact'} from your list.',
    );
    if (pin == null || pin.isEmpty) return false;

    final isValid = await authService.loginOffline(pin);
    if (!isValid) {
      if (mounted) {
        CustomSnackBar.showOnOverlay(overlay,
            message: 'Incorrect PIN', isError: true);
      }
      return false;
    }

    try {
      await contactService.deleteContact(isar, contact);
      if (mounted) {
        CustomSnackBar.showOnOverlay(overlay,
            message: '${contact.name ?? 'Contact'} removed');
      }
      return true;
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showOnOverlay(overlay,
            message: 'Could not remove contact. Please try again.',
            isError: true);
      }
      return false;
    }
  }

  Future<void> addManualContact() async {
    final overlay = Overlay.of(context);
    final contactService = context.read<ContactService>();
    final isar = context.read<IsarService>();

    final result = await AppManualContactDialog.show(context);

    if (result == null) return;

    if (mounted) setState(() => _syncing = true);

    try {
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

      await contactService.upsertContactsByCanonical(isar, [contact]);

      contactService.notifyUpdate();

      if (mounted) {
        await _refreshData(forceRefresh: true);
      }

      if (mounted) {
        CustomSnackBar.showOnOverlay(
          overlay,
          message: 'Contact added: ${contact.name}',
        );
      }
    } catch (e) {
      developer.log('Add manual contact error: $e');
      if (mounted) {
        CustomSnackBar.showOnOverlay(
          overlay,
          message: NetworkErrorHandler.message(
            e,
            fallback: 'Could not add contact. Please try again.',
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

    Widget buildEmptyState({
      required String title,
      required String message,
    }) {
      return RefreshIndicator(
        onRefresh: () => _refreshData(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
              bottom: AppDimensions.compactCardMargin(context).bottom),
          children: [
            AppDimensions.h20(context),
            AppEmptyStateCard(
              icon: hasSearch
                  ? Icons.search_off_rounded
                  : Icons.contacts_outlined,
              title: title,
              message: message,
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
              TextField(
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
              AppDimensions.h10(context),
              Expanded(
                child: _contacts.isEmpty && _refreshing
                    ? const Center(child: CircularProgressIndicator())
                    : _contacts.isEmpty
                        ? buildEmptyState(
                            title: hasSearch
                                ? 'No people match your search'
                                : 'No contacts yet',
                            message: hasSearch
                                ? 'Try a different name or phone number.'
                                : 'Sync device contacts or add someone by phone to start splitting bills.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _refreshData(forceRefresh: true),
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 120),
                              itemCount: _displayItemCount(),
                              itemBuilder: (context, index) {
                                if (_loadingMoreContacts &&
                                    index == _displayItemCount() - 1) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppDimensions.compactCardMargin(
                                              context)
                                          .bottom,
                                    ),
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }

                                if (_isNativeAdSlot(index)) {
                                  return const NativeAdWidget();
                                }

                                final contact = _contacts[
                                    _realItemIndexForDisplayIndex(index)];
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

                                return Dismissible(
                                  key: ValueKey(contact.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) =>
                                      _confirmDeleteContact(contact),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin: AppDimensions.compactCardMargin(
                                        context),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.delete_rounded,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  child: AppCard(
                                    type: AppCardType.elevated,
                                    margin: AppDimensions.compactCardMargin(
                                        context),
                                    padding: AppDimensions.compactCardPadding(
                                        context),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ConversationScreen(
                                              contact: contact),
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
                                                balanceColor.withValues(
                                                    alpha: 0.18),
                                                balanceColor.withValues(
                                                    alpha: 0.08),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: balanceColor.withValues(
                                                  alpha: 0.20),
                                              width: 1.5,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initials,
                                            style: AppTextStyles.titleSmall(
                                                    context)
                                                .copyWith(
                                              color: balanceColor,
                                              fontWeight: FontWeight.w800,
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
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: AppTextStyles
                                                          .titleSmall(
                                                        context,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                                PhoneUtils.display(
                                                    contact.phoneNumber),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodySmall(
                                                        context)
                                                    .copyWith(fontSize: 11.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                amountText,
                                                style: AppTextStyles.labelLarge(
                                                        context)
                                                    .copyWith(
                                                  color: balanceColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: balanceColor.withValues(
                                                    alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: balanceColor
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Text(
                                                balanceLabel,
                                                style: AppTextStyles.labelSmall(
                                                        context)
                                                    .copyWith(
                                                  color: balanceColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
      ),
    );
  }
}

class _BalanceSummaryBottomSheet extends StatelessWidget {
  final int owedToYouTotal;
  final int youOweTotal;
  final String preferredCurrencyCode;

  const _BalanceSummaryBottomSheet({
    required this.owedToYouTotal,
    required this.youOweTotal,
    required this.preferredCurrencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final netBalance = owedToYouTotal - youOweTotal;
    final netColor = netBalance > 0
        ? AppColors.success
        : netBalance < 0
            ? AppColors.error
            : AppColors.textSecondary;
    final netLabel = netBalance > 0
        ? "Overall you'll receive ${formatMinorUnits(netBalance, currencyCode: preferredCurrencyCode)}"
        : netBalance < 0
            ? "Overall you'll pay ${formatMinorUnits(netBalance.abs(), currencyCode: preferredCurrencyCode)}"
            : "All settled up 🎉";

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.cardElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance Summary',
                          style: AppTextStyles.titleMedium(context).copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Overall overview across all contacts',
                          style: AppTextStyles.bodySmall(context),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Net Status Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: netColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: netColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      netBalance > 0
                          ? Icons.trending_up_rounded
                          : netBalance < 0
                              ? Icons.trending_down_rounded
                              : Icons.check_circle_outline_rounded,
                      color: netColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        netLabel,
                        style: TextStyle(
                          color: netColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2 Summary Cards
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
                  const SizedBox(width: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _AddContactBottomSheet extends StatelessWidget {
  final VoidCallback onSelectContacts;
  final VoidCallback onAddByPhone;

  const _AddContactBottomSheet({
    required this.onSelectContacts,
    required this.onAddByPhone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.cardElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Contact',
                          style: AppTextStyles.titleMedium(context).copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Choose how to add people to FlatSync',
                          style: AppTextStyles.bodySmall(context),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Option 1
              _ActionTile(
                icon: Icons.contacts_rounded,
                title: 'Select from Phone Contacts',
                subtitle: 'Import one or more people from your phonebook',
                color: AppColors.primary,
                onTap: onSelectContacts,
              ),
              const SizedBox(height: 10),

              // Option 2
              _ActionTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Add by Phone Number',
                subtitle: 'Manually enter a name and phone number',
                color: AppColors.success,
                onTap: onAddByPhone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall(context).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textTertiary,
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
                colors: [
                  color.withValues(alpha: 0.20),
                  color.withValues(alpha: 0.08)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
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
                    formatMinorUnits(amount,
                        currencyCode: currencyCode, absolute: true),
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
