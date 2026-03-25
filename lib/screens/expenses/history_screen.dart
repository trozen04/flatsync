import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/detail_dialog.dart';
import '../../widgets/loading_indicator.dart';
import '../../bloc/contact_provider.dart';
import '../../services/app_preferences_service.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../constants/app_shadows.dart';
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

  StreamSubscription<int>? _updatesSub;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = _allTransactions.where((item) {
        final type = (item['type'] as String?) ?? '';
        final description = ((item['description'] as String?) ?? '').toLowerCase();
        if (_typeFilter != 'all' && type != _typeFilter) return false;
        if (q.isNotEmpty && !description.contains(q)) return false;
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

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  List<Map<String, dynamic>> _normalizeTimeline(List<Map<String, dynamic>> rows) {
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
          item['counterparty'] = counterparty['_id']?.toString();
        }
      }
      return item;
    }).toList();
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final pageRows = await context.read<ExpenseService>().getTimeline(
            limit: _pageSize,
            forceRefresh: true,
            cursor: _nextCursor,
          );
      final normalized = _normalizeTimeline(pageRows.items);
      if (!mounted) return;
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
      final pageRows = await context.read<ExpenseService>().getTimeline(
            limit: _pageSize,
            forceRefresh: forceRefresh,
          );
      final normalized = _normalizeTimeline(pageRows.items);
      if (!mounted) return;
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
        if (_allTransactions.isEmpty && !_refreshing) {
          return Column(
            children: [
              LoadingIndicator(isLoading: _refreshing),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                      AppDimensions.h20(context),
                      Text('No history yet', style: AppTextStyles.headlineSmall(context)),
                      AppDimensions.h10(context),
                      Text(
                        'Your transaction history will appear here',
                        style: AppTextStyles.bodyMedium(context),
                      ),
                      AppDimensions.h20(context),
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
            // AppBar row with export
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
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
                                  _applyFilter();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) {
                        _searchQuery = v;
                        _applyFilter();
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
                              try {
                                await ExportUtils.exportAndShare(_filtered);
                              } catch (_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Export failed')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _exporting = false);
                              }
                            },
                    ),
                ],
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  for (final f in [
                    ('all', 'All'),
                    ('expense', 'Expenses'),
                    ('transaction', 'Transactions'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f.$2),
                        selected: _typeFilter == f.$1,
                        onSelected: (_) {
                          _typeFilter = f.$1;
                          _applyFilter();
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadHistory(forceRefresh: true),
                child: _filtered.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text('No results', style: AppTextStyles.bodyMedium(context)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filtered.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final item = _filtered[index];
                          final type = (item['type'] as String?) ?? '';
                          final amountPaise = (item['amount'] as num?)?.round() ?? 0;
                          final totalAmountPaise = (item['totalAmount'] as num?)?.round();
                          final participants = (item['participants'] as num?)?.round() ?? 0;
                          final description = (item['description'] as String?) ?? '';
                          final paidBy = item['paidBy'] as String?;
                          final counterpartyRaw = item['counterparty'];
                          final counterparty = counterpartyRaw is String
                              ? counterpartyRaw
                              : (counterpartyRaw is Map ? counterpartyRaw['_id']?.toString() : null);
                          final direction = item['direction'] as String?;
                          final date = item['createdAt'] as DateTime;

                          developer.log('📊 HISTORY ITEM: type=$type, amount=$amountPaise, description=$description');

                          final formattedDate = AppDateUtils.formatDate(date);
                          final formattedTime = AppDateUtils.formatTime(date);

                          String displayName;
                          String subtitle;

                          if (type == 'transaction') {
                            final isReceivedByMe = direction == 'received';
                            displayName = contactProvider.getDisplayName(counterparty);
                            subtitle = isReceivedByMe
                                ? 'Received from $displayName'
                                : 'Sent to $displayName';
                          } else {
                            final isCreatedByMe = paidBy == _currentUserId;
                            subtitle = isCreatedByMe
                                ? 'You paid for expense'
                                : '${contactProvider.getDisplayName(paidBy)} paid for expense';
                          }

                          final amountColor = type == 'expense'
                              ? AppColors.primary
                              : (direction == 'received' ? AppColors.success : AppColors.error);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppShadows.card,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final items = <DetailItem>[];
                                if (type == 'expense') {
                                  items.add(DetailItem(label: 'Description', value: description, icon: Icons.description));
                                  if (totalAmountPaise != null) {
                                    items.add(DetailItem(
                                      label: 'Total Amount',
                                      value: formatMinorUnits(
                                        totalAmountPaise,
                                        currencyCode: preferredCurrencyCode,
                                      ),
                                      icon: Icons.account_balance_wallet,
                                      valueColor: AppColors.primary,
                                    ));
                                  }
                                  items.add(DetailItem(
                                    label: 'Your Share',
                                    value: formatMinorUnits(
                                      amountPaise,
                                      currencyCode: preferredCurrencyCode,
                                    ),
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
                                  items.add(DetailItem(label: subtitle, value: '', icon: Icons.info_outline));
                                } else {
                                  items.add(DetailItem(label: 'Description', value: description, icon: Icons.description));
                                  items.add(DetailItem(
                                    label: 'Amount',
                                    value: formatMinorUnits(
                                      amountPaise,
                                      currencyCode: preferredCurrencyCode,
                                    ),
                                    icon: Icons.payments,
                                    valueColor: amountColor,
                                  ));
                                  items.add(DetailItem(
                                    label: 'Type',
                                    value: subtitle,
                                    icon: direction == 'received' ? Icons.call_received : Icons.call_made,
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
                                    title: type == 'expense' ? 'Expense Details' : 'Transaction Details',
                                    items: items,
                                    accentColor: amountColor,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: type == 'expense'
                                            ? AppColors.primary.withValues(alpha: 0.12)
                                            : (direction == 'received'
                                                ? AppColors.success.withValues(alpha: 0.12)
                                                : AppColors.error.withValues(alpha: 0.12)),
                                        shape: BoxShape.circle,
                                        boxShadow: AppShadows.subtle,
                                      ),
                                      child: Icon(
                                        type == 'expense'
                                            ? Icons.receipt_long
                                            : (direction == 'received' ? Icons.call_received : Icons.call_made),
                                        color: type == 'expense'
                                            ? AppColors.primary
                                            : (direction == 'received' ? AppColors.success : AppColors.error),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            description,
                                            style: AppTextStyles.titleMedium(context).copyWith(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: AppTextStyles.bodySmall(context).copyWith(fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$formattedDate at $formattedTime',
                                            style: AppTextStyles.caption(context).copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatMinorUnits(
                                            amountPaise,
                                            currencyCode: preferredCurrencyCode,
                                          ),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: amountColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: amountColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: amountColor.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            type == 'expense'
                                                ? 'Your share'
                                                : (direction == 'received' ? 'Received' : 'Sent'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: amountColor,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
