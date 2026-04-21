import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_ads.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/detail_dialog.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/native_ad_widget.dart';
import '../../bloc/contact_provider.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/export_utils.dart';
import '../../utils/money_utils.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToAddExpense;

  const HistoryScreen({super.key, this.onNavigateToAddExpense});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _allTransactions = [];
  List<dynamic> _filtered = [];
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _exporting = false;
  final int _pageSize = 20;
  bool _hasMore = true;
  String? _nextCursor;
  String? _currentUserId;
  String _typeFilter = 'all';
  String _searchQuery = '';
  Timer? _searchDebounce;

  StreamSubscription<int>? _updatesSub;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  void _applyFilter() {
    setState(() {
      _filtered = _allTransactions.where((item) {
        final type = (item['type'] as String?) ?? '';
        if (_typeFilter != 'all' && type != _typeFilter) return false;
        return true;
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUserId();
      _loadHistory(forceRefresh: false);
      _scrollController.addListener(_onScroll);
      _updatesSub = context.read<ExpenseService>().updates.listen((_) {
        if (mounted) _loadHistory(forceRefresh: false);
      });
    });
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await context.read<AuthService>().getCurrentUserId();
    if (mounted) setState(() => _currentUserId = userId);
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _displayLabelForUser(
    ContactProvider contactProvider, {
    Map<String, dynamic>? summary,
    String? fallback,
    Map<String, dynamic>? item,
    String? direction,
  }) {
    void logResolution(String source, String value) {
      developer.log(
        '[HistoryScreen] resolvedLabel="$value" via=$source direction=$direction summaryName=${_stringValue(summary?['name'])} summaryPhone=${_stringValue(summary?['phoneNumber'])} summaryId=${_stringValue(summary?['_id'])} fallback=$fallback fromUserId=${_stringValue(item?['fromUserId'])} fromPhone=${_stringValue(item?['fromPhone'])} toUserId=${_stringValue(item?['toUserId'])} toPhone=${_stringValue(item?['toPhone'])}',
        name: 'HistoryScreen',
      );
    }

    final summaryCandidates = <String>[
      _stringValue(summary?['name']),
      _stringValue(summary?['phoneNumber']),
      _stringValue(summary?['_id']),
    ];

    for (final candidate in summaryCandidates) {
      if (candidate.isEmpty) continue;
      final contact = contactProvider.getContactById(candidate) ??
          contactProvider.getContactByPhone(candidate);
      if (contact != null) {
        final name = _stringValue(contact.name);
        if (name.isNotEmpty) {
          logResolution('summary-contact-name', name);
          return name;
        }
        final phone = _stringValue(contact.phoneNumber);
        if (phone.isNotEmpty) {
          logResolution('summary-contact-phone', phone);
          return phone;
        }
      }
      logResolution('summary-raw', candidate);
      return candidate;
    }

    final candidates = <String?>[
      fallback,
      if (item != null) ...[
        if (direction == 'received') _stringValue(item['fromUserId']),
        if (direction == 'received') _stringValue(item['fromPhone']),
        if (direction == 'sent') _stringValue(item['toUserId']),
        if (direction == 'sent') _stringValue(item['toPhone']),
        _stringValue(item['fromUserId']),
        _stringValue(item['toUserId']),
        _stringValue(item['fromPhone']),
        _stringValue(item['toPhone']),
      ],
    ];

    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value.isEmpty) continue;
      final contact = contactProvider.getContactById(value) ??
          contactProvider.getContactByPhone(value);
      if (contact != null) {
        final name = _stringValue(contact.name);
        if (name.isNotEmpty) {
          logResolution('fallback-contact-name', name);
          return name;
        }
        final phone = _stringValue(contact.phoneNumber);
        if (phone.isNotEmpty) {
          logResolution('fallback-contact-phone', phone);
          return phone;
        }
      }
      logResolution('fallback-raw', value);
      return value;
    }

    final bestFromItem = item == null
        ? ''
        : _stringValue(item['fromPhone']).isNotEmpty
            ? _stringValue(item['fromPhone'])
            : _stringValue(item['toPhone']).isNotEmpty
                ? _stringValue(item['toPhone'])
                : _stringValue(item['fromUserId']).isNotEmpty
                    ? _stringValue(item['fromUserId'])
                    : _stringValue(item['toUserId']);
    final resolved = bestFromItem.isNotEmpty ? bestFromItem : 'Unknown';
    logResolution('item-fallback', resolved);
    return resolved;
  }

  Map<String, dynamic>? _normalizeCounterparty(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return <String, dynamic>{'_id': raw.trim()};
    }
    return null;
  }

  Map<String, dynamic>? _normalizeUserSummary(dynamic raw) {
    final summary = _normalizeCounterparty(raw);
    if (summary == null) return null;

    final normalized = <String, dynamic>{};
    final id = _stringValue(summary['_id']);
    final name = _stringValue(summary['name']);
    final phone = _stringValue(summary['phoneNumber']);

    if (id.isNotEmpty) normalized['_id'] = id;
    if (name.isNotEmpty) normalized['name'] = name;
    if (phone.isNotEmpty) normalized['phoneNumber'] = phone;
    return normalized.isEmpty ? null : normalized;
  }

  List<String> _participantLabelsForExpense(
    ContactProvider contactProvider,
    Map<String, dynamic> item,
  ) {
    final rawPhones = item['participantPhones'];
    final phones = rawPhones is List
        ? rawPhones
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    return phones
        .map((phone) => contactProvider.getDisplayName(phone))
        .toList();
  }

  Widget _buildChip(String label, {IconData? icon, Color? color}) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  bool _isNativeAdSlot(int index) {
    const interval = AppAds.nativeAdEveryN;
    return interval > 0 &&
        _filtered.length >= interval &&
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
    final adCount = interval > 0 ? _filtered.length ~/ interval : 0;
    return _filtered.length + adCount + (_loadingMore ? 1 : 0);
  }

  List<Map<String, dynamic>> _normalizeTimeline(
      List<Map<String, dynamic>> rows) {
    return rows.map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final createdAt = item['createdAt'];
      if (createdAt is String) {
        item['createdAt'] = DateTime.tryParse(createdAt) ?? DateTime.now();
      }
      if (item['type'] == 'expense') {
        item['paidBy'] ??= item['createdBy'];
      } else if (item['type'] == 'transaction') {
        final counterparty = item['counterparty'];
        final normalizedCounterparty = _normalizeCounterparty(counterparty);
        if (normalizedCounterparty != null) {
          item['counterparty'] = normalizedCounterparty;
        } else {
          final direction = (item['direction'] as String?)?.trim();
          final preferredUser = direction == 'received'
              ? _normalizeUserSummary(item['fromUser'])
              : _normalizeUserSummary(item['toUser']);
          final secondaryUser = direction == 'received'
              ? _normalizeUserSummary(item['toUser'])
              : _normalizeUserSummary(item['fromUser']);
          final fallbackSummary =
              preferredUser ?? secondaryUser ?? <String, dynamic>{};

          if (fallbackSummary.isEmpty) {
            final preferredId =
                direction == 'received' ? item['fromUserId'] : item['toUserId'];
            final preferredPhone =
                direction == 'received' ? item['fromPhone'] : item['toPhone'];
            final secondaryId =
                direction == 'received' ? item['toUserId'] : item['fromUserId'];
            final secondaryPhone =
                direction == 'received' ? item['toPhone'] : item['fromPhone'];

            if (preferredId != null &&
                preferredId.toString().trim().isNotEmpty) {
              fallbackSummary['_id'] = preferredId.toString();
            } else if (secondaryId != null &&
                secondaryId.toString().trim().isNotEmpty) {
              fallbackSummary['_id'] = secondaryId.toString();
            }

            if (preferredPhone != null &&
                preferredPhone.toString().trim().isNotEmpty) {
              fallbackSummary['phoneNumber'] = preferredPhone.toString();
            } else if (secondaryPhone != null &&
                secondaryPhone.toString().trim().isNotEmpty) {
              fallbackSummary['phoneNumber'] = secondaryPhone.toString();
            }
          }

          if (fallbackSummary.isNotEmpty) {
            item['counterparty'] = fallbackSummary;
          }
        }
      }
      return item;
    }).toList();
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final requestSearch = _searchQuery.trim();
      final pageRows = await context.read<ExpenseService>().getTimeline(
            limit: _pageSize,
            forceRefresh: true,
            cursor: _nextCursor,
            search: requestSearch,
          );
      final normalized = _normalizeTimeline(pageRows.items);
      if (!mounted) return;
      if (requestSearch != _searchQuery.trim()) return;
      setState(() {
        _allTransactions.addAll(normalized);
        _nextCursor = pageRows.nextCursor;
        _hasMore = pageRows.hasMore;
      });
      _applyFilter();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _refreshing = true);
    try {
      final requestSearch = _searchQuery.trim();
      final pageRows = await context.read<ExpenseService>().getTimeline(
            limit: _pageSize,
            forceRefresh: forceRefresh,
            search: requestSearch,
          );
      final normalized = _normalizeTimeline(pageRows.items);
      if (!mounted) return;
      if (requestSearch != _searchQuery.trim()) return;
      setState(() {
        _allTransactions = normalized;
        _nextCursor = pageRows.nextCursor;
        _hasMore = pageRows.hasMore;
      });
      _applyFilter();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactProvider>(
      builder: (context, contactProvider, _) {
        final preferredCurrencyCode =
            context.watch<AppPreferencesService>().preferredCurrencyCode;
        final pageMargin = AppDimensions.appMargin(context);
        final displayCount = _displayItemCount();

        if (_allTransactions.isEmpty && !_refreshing) {
          final hasSearch = _searchQuery.trim().isNotEmpty;
          return Column(
            children: [
              LoadingIndicator(isLoading: _refreshing),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: Colors.grey.shade400),
                      AppDimensions.h20(context),
                      Text(
                        hasSearch ? 'No results' : 'No history yet',
                        style: AppTextStyles.headlineSmall(context),
                      ),
                      AppDimensions.h10(context),
                      Text(
                        hasSearch
                            ? 'Try a different search term'
                            : 'Your transaction history will appear here',
                        style: AppTextStyles.bodyMedium(context),
                      ),
                      AppDimensions.h20(context),
                      if (!hasSearch)
                        FilledButton.icon(
                          onPressed: widget.onNavigateToAddExpense,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Expense'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            LoadingIndicator(isLoading: _refreshing),
            // Search bar
            Padding(
              padding: AppDimensions.appMargin(context),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by description...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadHistory(forceRefresh: true);
                                },
                              )
                            : null,
                        contentPadding: AppDimensions.fieldPadding(context),
                      ),
                      onChanged: (v) {
                        _searchDebounce?.cancel();
                        setState(() => _searchQuery = v);
                        _searchDebounce =
                            Timer(const Duration(milliseconds: 250), () {
                          if (mounted) _loadHistory(forceRefresh: true);
                        });
                      },
                    ),
                  ),
                  if (_filtered.isNotEmpty)
                    IconButton(
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      tooltip: 'Export CSV',
                      onPressed: _exporting
                          ? null
                          : () async {
                              setState(() => _exporting = true);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final allPage = await context
                                    .read<ExpenseService>()
                                    .getTimeline(
                                      limit: 9999,
                                      forceRefresh: true,
                                      search: _searchQuery.trim(),
                                    );
                                final allItems =
                                    _normalizeTimeline(allPage.items)
                                        .where((item) {
                                  final type = (item['type'] as String?) ?? '';
                                  return _typeFilter == 'all' ||
                                      type == _typeFilter;
                                }).toList();
                                await ExportUtils.exportAndShare(allItems);
                              } catch (_) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not export. Please try again.')),
                                );
                              } finally {
                                if (mounted) setState(() => _exporting = false);
                              }
                            },
                    ),
                ],
              ),
            ),
            // AppDimensions.h10(context),

            // Filter chips
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 20,
              runSpacing: 4, // vertical space
              children: [
                for (final f in [
                  ('all', 'All'),
                  ('expense', 'Expenses'),
                  ('transaction', 'Transactions'),
                ])
                  FilterChip(
                    label: Text(f.$2),
                    selected: _typeFilter == f.$1,
                    onSelected: (_) {
                      setState(() => _typeFilter = f.$1);
                      _applyFilter();
                    },
                  ),
              ],
            ),

            // AppDimensions.h10(context),
            // Transaction list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadHistory(forceRefresh: true),
                child: _refreshing && _filtered.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? ListView(
                            children: [
                              AppDimensions.h100(context),
                              Center(
                                child: Text(
                                  _searchQuery.trim().isNotEmpty
                                      ? 'No results'
                                      : 'No history yet',
                                  style: AppTextStyles.bodyMedium(context),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              pageMargin.left,
                              pageMargin.top,
                              pageMargin.right,
                              120,
                            ),
                            itemCount: displayCount,
                            itemBuilder: (context, index) {
                              if (_loadingMore && index == displayCount - 1) {
                                return Center(
                                  child: Padding(
                                    padding:
                                        AppDimensions.fieldPadding(context),
                                    child: const CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (_isNativeAdSlot(index)) {
                                return const NativeAdWidget();
                              }

                              final item = _filtered[
                                  _realItemIndexForDisplayIndex(index)];
                              final type = (item['type'] as String?) ?? '';
                              final amountPaise =
                                  (item['amount'] as num?)?.round() ?? 0;
                              final totalAmountPaise =
                                  (item['totalAmount'] as num?)?.round();
                              final participants =
                                  (item['participants'] as num?)?.round() ?? 0;
                              final description =
                                  (item['description'] as String?) ?? '';
                              final paidBy = item['paidBy'] as String?;
                              final participantLabels =
                                  _participantLabelsForExpense(
                                contactProvider,
                                item,
                              );
                              final counterpartyRaw = item['counterparty'];
                              final counterpartySummary =
                                  _normalizeUserSummary(counterpartyRaw) ??
                                      _normalizeUserSummary(item['toUser']) ??
                                      _normalizeUserSummary(item['fromUser']) ??
                                      _normalizeCounterparty(counterpartyRaw);
                              final counterparty =
                                  counterpartySummary?['_id']?.toString() ??
                                      (counterpartyRaw is String
                                          ? counterpartyRaw.trim()
                                          : null);
                              final direction = item['direction'] as String?;
                              final date = item['createdAt'] as DateTime;
                              final isDeleted = item['isDeleted'] == true;
                              final deletedBy =
                                  (item['deletedBy'] as String?)?.trim();
                              final updatedBy =
                                  (item['updatedBy'] as String?)?.trim();

                              // developer.log('📊 HISTORY ITEM: type=$type, amount=$amountPaise, description=$description');

                              final formattedDate =
                                  AppDateUtils.formatDate(date);
                              final formattedTime =
                                  AppDateUtils.formatTime(date);

                              String subtitle;

                              if (type == 'transaction') {
                                final isReceivedByMe = direction == 'received';
                                final displayName = _displayLabelForUser(
                                  contactProvider,
                                  summary: counterpartySummary,
                                  fallback: counterparty,
                                  item: item,
                                  direction: direction,
                                );
                                subtitle = isReceivedByMe
                                    ? 'Received from $displayName'
                                    : 'Sent to $displayName';
                              } else {
                                final isCreatedByMe = paidBy == _currentUserId;
                                final payerName = _displayLabelForUser(
                                  contactProvider,
                                  summary: counterpartySummary,
                                  fallback: paidBy,
                                  item: item,
                                );
                                subtitle = isCreatedByMe
                                    ? 'You paid for expense'
                                    : '$payerName paid for expense';
                              }

                              final amountColor = type == 'expense'
                                  ? AppColors.primary
                                  : (direction == 'received'
                                      ? AppColors.success
                                      : AppColors.error);
                              final metaLabel = isDeleted
                                  ? (deletedBy != null && deletedBy.isNotEmpty
                                      ? 'Deleted by $deletedBy'
                                      : 'Deleted record')
                                  : updatedBy != null && updatedBy.isNotEmpty
                                      ? 'Edited by $updatedBy'
                                      : null;
                              final entryTitle = description.isNotEmpty
                                  ? description
                                  : (type == 'expense'
                                      ? 'Expense'
                                      : 'Transaction');
                              final amountLabel = type == 'expense'
                                  ? 'Your share'
                                  : (direction == 'received'
                                      ? 'Received'
                                      : 'Sent');
                              final amountText = formatMinorUnits(
                                amountPaise,
                                currencyCode: preferredCurrencyCode,
                              );

                              return Opacity(
                                  opacity: isDeleted ? 0.55 : 1.0,
                                  child: AppCard(
                                    type: AppCardType.elevated,
                                    margin: EdgeInsets.only(
                                      bottom: AppDimensions.compactCardMargin(
                                              context)
                                          .bottom,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    backgroundColor: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    shadowColor: amountColor,
                                    onTap: () {
                                      final items = <DetailItem>[];
                                      if (type == 'expense') {
                                        items.add(DetailItem(
                                            label: 'Description',
                                            value: description,
                                            icon: Icons.description));
                                        if (totalAmountPaise != null) {
                                          items.add(DetailItem(
                                            label: 'Total Amount',
                                            value: formatMinorUnits(
                                                totalAmountPaise,
                                                currencyCode:
                                                    preferredCurrencyCode),
                                            icon: Icons.account_balance_wallet,
                                            valueColor: AppColors.primary,
                                          ));
                                        }
                                        items.add(DetailItem(
                                          label: 'Your Share',
                                          value: formatMinorUnits(amountPaise,
                                              currencyCode:
                                                  preferredCurrencyCode),
                                          icon: Icons.person,
                                          valueColor: AppColors.primary,
                                        ));
                                        if (participantLabels.isNotEmpty) {
                                          items.add(DetailItem(
                                            label: 'Shared With',
                                            value: participantLabels.join(', '),
                                            icon: Icons.group_outlined,
                                          ));
                                        }
                                        if (participants > 0) {
                                          items.add(DetailItem(
                                            label: 'Split Between',
                                            value: '${participants + 1} people',
                                            icon: Icons.group,
                                          ));
                                        }
                                        items.add(DetailItem(
                                            label: subtitle,
                                            value: '',
                                            icon: Icons.info_outline));
                                      } else {
                                        items.add(DetailItem(
                                            label: 'Description',
                                            value: description,
                                            icon: Icons.description));
                                        items.add(DetailItem(
                                          label: 'Amount',
                                          value: formatMinorUnits(amountPaise,
                                              currencyCode:
                                                  preferredCurrencyCode),
                                          icon: Icons.payments,
                                          valueColor: amountColor,
                                        ));
                                        items.add(DetailItem(
                                          label: 'Type',
                                          value: subtitle,
                                          icon: direction == 'received'
                                              ? Icons.call_received
                                              : Icons.call_made,
                                        ));
                                      }
                                      items.add(DetailItem(
                                        label: 'Date & Time',
                                        value:
                                            '$formattedDate at $formattedTime',
                                        icon: Icons.calendar_today,
                                      ));
                                      if (metaLabel != null) {
                                        items.add(DetailItem(
                                          label:
                                              isDeleted ? 'Deleted' : 'Updated',
                                          value: metaLabel,
                                          icon: isDeleted
                                              ? Icons.delete_outline_rounded
                                              : Icons.edit_outlined,
                                          valueColor: isDeleted
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                        ));
                                      }
                                      showDialog(
                                        context: context,
                                        builder: (context) => DetailDialog(
                                          title: type == 'expense'
                                              ? 'Expense Details'
                                              : 'Transaction Details',
                                          items: items,
                                          accentColor: amountColor,
                                        ),
                                      );
                                    },
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Icon
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: amountColor.withValues(
                                                alpha: 0.10),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            type == 'expense'
                                                ? Icons.receipt_long_rounded
                                                : (direction == 'received'
                                                    ? Icons
                                                        .call_received_rounded
                                                    : Icons.call_made_rounded),
                                            color: amountColor,
                                            size: 19,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Middle content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      entryTitle,
                                                      style: AppTextStyles
                                                              .titleSmall(
                                                                  context)
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        decoration: isDeleted
                                                            ? TextDecoration
                                                                .lineThrough
                                                            : null,
                                                        decorationColor:
                                                            AppColors
                                                                .textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isDeleted) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.error
                                                            .withValues(
                                                                alpha: 0.10),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        'Deleted',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              AppColors.error,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: AppTextStyles.caption(
                                                        context)
                                                    .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 5),
                                              Wrap(
                                                spacing: 5,
                                                runSpacing: 3,
                                                children: [
                                                  _buildChip(
                                                    '$formattedDate · $formattedTime',
                                                    icon:
                                                        Icons.schedule_rounded,
                                                  ),
                                                  if (type == 'expense' &&
                                                      totalAmountPaise != null)
                                                    _buildChip(
                                                      'Total ${formatMinorUnits(totalAmountPaise, currencyCode: preferredCurrencyCode)}',
                                                      icon: Icons
                                                          .account_balance_wallet_outlined,
                                                      color: AppColors.primary,
                                                    ),
                                                  if (type == 'expense' &&
                                                      participants > 0)
                                                    _buildChip(
                                                      '${participants + 1} people',
                                                      icon:
                                                          Icons.group_outlined,
                                                    ),
                                                  if (!isDeleted &&
                                                      metaLabel != null)
                                                    _buildChip(
                                                      metaLabel,
                                                      icon: Icons.edit_outlined,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Amount
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              amountText,
                                              style: AppTextStyles.titleSmall(
                                                      context)
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
                                                decoration: isDeleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                decorationColor:
                                                    AppColors.textSecondary,
                                                color: isDeleted
                                                    ? AppColors.textSecondary
                                                    : amountColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildChip(
                                              amountLabel,
                                              icon: type == 'expense'
                                                  ? Icons.person_outline_rounded
                                                  : (direction == 'received'
                                                      ? Icons.south_west_rounded
                                                      : Icons
                                                          .north_east_rounded),
                                              color: isDeleted
                                                  ? AppColors.textSecondary
                                                  : amountColor,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ));
                            },
                          ),
              ),
            ),

            // Banner Ad
            // const BannerAdWidget(),
          ],
        );
      },
    );
  }
}
