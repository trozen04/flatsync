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
import '../../widgets/banner_ad_widget.dart';
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
  }) {
    final summaryName = _stringValue(summary?['name']);
    if (summaryName.isNotEmpty) return summaryName;

    final summaryPhone = _stringValue(summary?['phoneNumber']);
    if (summaryPhone.isNotEmpty) return summaryPhone;

    final contact = contactProvider.getContactById(fallback) ??
        contactProvider.getContactByPhone(fallback);
    if (contact != null) {
      final name = _stringValue(contact.name);
      if (name.isNotEmpty) return name;
      final phone = _stringValue(contact.phoneNumber);
      if (phone.isNotEmpty) return phone;
    }

    final fallbackText = _stringValue(fallback);
    return fallbackText.isNotEmpty ? fallbackText : 'Unknown';
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
        if (counterparty is Map) {
          item['counterparty'] =
              counterparty.map((k, v) => MapEntry(k.toString(), v));
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
                                  _searchQuery = '';
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
                                      content: Text('Export failed')),
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
                child: _filtered.isEmpty
                    ? ListView(
                        children: [
                          AppDimensions.h100(context),
                          Center(
                            child: Text('No results',
                                style: AppTextStyles.bodyMedium(context)),
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
                                padding: AppDimensions.fieldPadding(context),
                                child: const CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (_isNativeAdSlot(index)) {
                            return const NativeAdWidget();
                          }

                          final item =
                              _filtered[_realItemIndexForDisplayIndex(index)];
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
                          final counterpartyRaw = item['counterparty'];
                          final counterpartySummary =
                              counterpartyRaw is Map<String, dynamic>
                                  ? counterpartyRaw
                                  : null;
                          final counterparty =
                              counterpartySummary?['_id']?.toString();
                          final direction = item['direction'] as String?;
                          final date = item['createdAt'] as DateTime;

                          developer.log(
                              '📊 HISTORY ITEM: type=$type, amount=$amountPaise, description=$description');

                          final formattedDate = AppDateUtils.formatDate(date);
                          final formattedTime = AppDateUtils.formatTime(date);

                          String displayName;
                          String subtitle;

                          if (type == 'transaction') {
                            final isReceivedByMe = direction == 'received';
                            displayName = _displayLabelForUser(
                              contactProvider,
                              summary: counterpartySummary,
                              fallback: counterparty,
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

                          return AppCard(
                            type: AppCardType.elevated,
                            margin: EdgeInsets.only(
                              bottom: AppDimensions.compactCardMargin(context)
                                  .bottom,
                            ),
                            padding: AppDimensions.compactCardPadding(context),
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
                                    value: formatMinorUnits(totalAmountPaise,
                                        currencyCode: preferredCurrencyCode),
                                    icon: Icons.account_balance_wallet,
                                    valueColor: AppColors.primary,
                                  ));
                                }
                                items.add(DetailItem(
                                  label: 'Your Share',
                                  value: formatMinorUnits(amountPaise,
                                      currencyCode: preferredCurrencyCode),
                                  icon: Icons.person,
                                  valueColor: AppColors.primary,
                                ));
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
                                      currencyCode: preferredCurrencyCode),
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
                                value: '$formattedDate at $formattedTime',
                                icon: Icons.calendar_today,
                              ));
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
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        amountColor.withValues(alpha: 0.18),
                                        amountColor.withValues(alpha: 0.07),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          amountColor.withValues(alpha: 0.22),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    type == 'expense'
                                        ? Icons.receipt_long_rounded
                                        : (direction == 'received'
                                            ? Icons.call_received_rounded
                                            : Icons.call_made_rounded),
                                    color: amountColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        description,
                                        style: AppTextStyles.titleSmall(context)
                                            .copyWith(
                                                fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        style: AppTextStyles.bodySmall(context),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$formattedDate · $formattedTime',
                                        style: AppTextStyles.caption(context),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        formatMinorUnits(amountPaise,
                                            currencyCode:
                                                preferredCurrencyCode),
                                        style: AppTextStyles.labelLarge(context)
                                            .copyWith(
                                          color: amountColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            amountColor.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: amountColor.withValues(
                                              alpha: 0.25),
                                        ),
                                      ),
                                      child: Text(
                                        type == 'expense'
                                            ? 'Your share'
                                            : (direction == 'received'
                                                ? 'Received'
                                                : 'Sent'),
                                        style: AppTextStyles.labelSmall(context)
                                            .copyWith(
                                          color: amountColor,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
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


            // Banner Ad
            // const BannerAdWidget(),
          ],
        );
      },
    );
  }
}
