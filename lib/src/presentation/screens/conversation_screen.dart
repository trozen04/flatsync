import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/contact_model.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/detail_dialog.dart';
import '../../core/widgets/shadowed_app_bar.dart';
import '../../utils/money_utils.dart';

class ConversationScreen extends StatefulWidget {
  final ContactModel contact;

  const ConversationScreen({super.key, required this.contact});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<dynamic> _transactions = [];
  bool _syncing = false;
  bool _serverSyncing = false;
  bool _submitting = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  int _balance = 0;
  String? _currentUserId;
  static const double _currencyDivisor = 100.0;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<int>? _updatesSub;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _scrollController.addListener(_onScroll);
    _updatesSub = context.read<ExpenseService>().updates.listen((_) {
      if (mounted) _syncFromServer();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalFirst());
  }

  Future<void> _loadLocalFirst() async {
    developer.log('🔵 _loadLocalFirst: START');
    if (mounted) setState(() => _syncing = true);
    try {
      final contactId = widget.contact.contactId;
      final expenseService = context.read<ExpenseService>();
      List<dynamic> localData;
      
      if (contactId != null && contactId.isNotEmpty) {
        developer.log('🔵 _loadLocalFirst: Loading by contactId=$contactId');
        final page = await expenseService.getTimeline(withUserId: contactId, forceRefresh: false);
        localData = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      } else {
        developer.log('🔵 _loadLocalFirst: Loading by phone=${widget.contact.phoneNumber}');
        localData = await expenseService.getConversationByPhone(widget.contact.phoneNumber ?? '', forceRefresh: false);
      }
      
      developer.log('🔵 _loadLocalFirst: Got ${localData.length} local items');
      
      final balances = await expenseService.getBalances(forceRefresh: false);
      final balance = _resolveContactBalance(balances);
      
      developer.log('🔵 _loadLocalFirst: Balance=$balance');
      
      if (mounted) {
        setState(() {
          _transactions = localData;
          _balance = balance;
          _hasMore = _hasMore || localData.length >= 20;
          _syncing = false;
        });
        developer.log('🔵 _loadLocalFirst: State updated, _syncing=false');
      }
    } catch (e) {
      developer.log('🔴 _loadLocalFirst ERROR: $e');
      if (mounted) setState(() => _syncing = false);
    }
    
    developer.log('🔵 _loadLocalFirst: Calling _syncFromServer');
    _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    developer.log('🟢 _syncFromServer: START, _syncing=$_syncing');
    if (_serverSyncing) {
      developer.log('🟡 _syncFromServer: Already syncing, RETURN');
      return;
    }
    if (mounted) {
      setState(() => _syncing = true);
      developer.log('🟢 _syncFromServer: Set _syncing=true');
    }
    
    _serverSyncing = true;
    try {
      final contactId = widget.contact.contactId;
      final expenseService = context.read<ExpenseService>();
      List<dynamic> serverData;
      
      if (contactId != null && contactId.isNotEmpty) {
        developer.log('🟢 _syncFromServer: Fetching by contactId=$contactId');
        final page = await expenseService.getTimeline(withUserId: contactId, forceRefresh: true);
        serverData = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      } else {
        developer.log('🟢 _syncFromServer: Fetching by phone=${widget.contact.phoneNumber}');
        serverData = await expenseService.getConversationByPhone(widget.contact.phoneNumber ?? '', forceRefresh: true);
      }
      
      developer.log('🟢 _syncFromServer: Got ${serverData.length} server items');
      
      final balances = await expenseService.getBalances(forceRefresh: true);
      final balance = _resolveContactBalance(balances);
      
      developer.log('🟢 _syncFromServer: Balance=$balance');
      
      if (mounted) {
        setState(() {
          _transactions = serverData;
          _balance = balance;
          _hasMore = _hasMore || serverData.length >= 20;
        });
        developer.log('🟢 _syncFromServer: State updated');
      }
    } catch (e) {
      developer.log('🔴 _syncFromServer ERROR: $e');
    } finally {
      _serverSyncing = false;
      if (mounted) {
        setState(() => _syncing = false);
        developer.log('🟢 _syncFromServer: Set _syncing=false, DONE');
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await context.read<AuthService>().getCurrentUserId();
    if (mounted) {
      setState(() => _currentUserId = userId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // List is reversed (newest at bottom). Load older items when reaching the top.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  String _canonicalPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  int _resolveContactBalance(Map<String, dynamic> balances) {
    final contactId = widget.contact.contactId;
    if (contactId != null && contactId.isNotEmpty) {
      final byId = balances[contactId];
      if (byId is num) return byId.round();
    }

    final contactPhone = _canonicalPhone(widget.contact.phoneNumber);
    for (final entry in balances.entries) {
      if (_canonicalPhone(entry.key) == contactPhone && entry.value is num) {
        return (entry.value as num).round();
      }
    }
    return 0;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final contactId = widget.contact.contactId;
      if (contactId == null || contactId.isEmpty) return;

      final expenseService = context.read<ExpenseService>();
      final page = await expenseService.getTimeline(
        withUserId: contactId,
        cursor: _nextCursor,
        forceRefresh: true,
      );
      final conversation = page.items;

      if (!mounted) return;
      setState(() {
        final existingKeys = _transactions.map(_timelineKey).whereType<String>().toSet();
        final filtered = conversation.where((e) {
          final key = _timelineKey(e);
          return key == null || !existingKeys.contains(key);
        }).toList();
        _transactions.addAll(filtered);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      developer.log('Load more error: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String? _timelineKey(dynamic item) {
    if (item is! Map<String, dynamic>) return null;
    final type = item['type']?.toString() ?? '';
    final createdAt = item['createdAt']?.toString() ?? '';
    final expenseId = item['expenseId']?.toString() ?? '';
    return '$type:$expenseId:$createdAt';
  }

  Future<Map<String, dynamic>?> _showEntryDialog({required bool isTransaction}) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isTransaction ? 'Add Transaction' : 'Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs)',
                  hintText: 'e.g. 300',
                ),
              ),
              if (!isTransaction) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Dinner / Grocery / Cab',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amountPaise = parseRupeesToPaise(amountController.text);
                if (amountPaise == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'amountPaise': amountPaise,
                  'description': descriptionController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addExpenseFromChat() async {
    if (_submitting) return;
    final phone = widget.contact.phoneNumber;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact phone missing')),
      );
      return;
    }

    final input = await _showEntryDialog(isTransaction: false);
    if (input == null) return;

    if (mounted) setState(() => _submitting = true);
    try {
      final amount = (input['amountPaise'] as num).toInt();
      final description = (input['description'] as String?)?.trim();
      await context.read<ExpenseService>().createExpense(
            description: (description == null || description.isEmpty) ? 'Expense' : description,
            totalAmount: amount,
            participants: [phone],
          );
      await _syncFromServer();
    } catch (e) {
      developer.log('Add chat expense error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add expense')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addTransactionFromChat() async {
    if (_submitting) return;
    final toUserId = widget.contact.contactId;
    if (toUserId == null || toUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction requires a registered contact')),
      );
      return;
    }

    final input = await _showEntryDialog(isTransaction: true);
    if (input == null) return;

    if (mounted) setState(() => _submitting = true);
    try {
      final amount = (input['amountPaise'] as num).toInt();
      await context.read<ExpenseService>().createTransaction(
            toUserId: toUserId,
            amount: amount,
          );
      await _syncFromServer();
    } catch (e) {
      developer.log('Add chat transaction error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add transaction')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final balanceColor = _balance > 0
        ? AppColors.success
        : _balance < 0
            ? AppColors.error
            : AppColors.textSecondary;
    final balanceLabel = _balance > 0
        ? 'You should receive'
        : _balance < 0
            ? 'You should pay'
            : 'All settled';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ShadowedAppBar(
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(widget.contact.name ?? 'User'),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: balanceColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: balanceColor.withOpacity(0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(balanceLabel, style: AppTextStyles.bodySmall(context)),
                AppDimensions.h5(context),
                Text(
                  'Rs ${formatPaise(_balance)}',
                  style: AppTextStyles.currency(context).copyWith(color: balanceColor),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _syncing ? 36 : 0,
            child: _syncing
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Syncing data...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _transactions.isEmpty && _syncing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Loading conversation...', style: AppTextStyles.bodyMedium(context)),
                      ],
                    ),
                  )
                : _transactions.isEmpty
                ? RefreshIndicator(
                    onRefresh: _syncFromServer,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: AppDimensions.height(context) * 0.2),
                        Center(
                          child: Text('No transactions yet', style: AppTextStyles.bodyMedium(context)),
                        ),
                      ],
                    ),
                  )
                : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _syncFromServer,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(16, _loadingMore ? 56 : 16, 16, 16),
                      reverse: true,
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                            final item = _transactions[index];
                            final type = item['type'];
                            final amount = (item['amount'] as num?)?.round() ?? 0;
                            final totalAmount = (item['totalAmount'] as num?)?.round();
                            final participants = (item['participants'] as num?)?.round() ?? 0;
                            final description = item['description'] ?? '';
                            final direction = item['direction'] as String? ?? '';
                            final date = DateTime.parse(item['createdAt'] as String);
                            final expenseId = (item['expenseId'] ?? item['id']) as String?;
                            final createdBy = item['createdBy'] as String?;
                            final canDelete = type == 'expense' && expenseId != null && createdBy == _currentUserId;
                            final isYouPaid = direction == 'you_paid' || direction == 'sent';
                            final tagText = type == 'expense' ? 'Expense' : 'Transaction';
                            final tagColor = type == 'expense' ? Colors.orange : Colors.blue;
                            
                            developer.log('💬 CHAT ITEM: type=$type, amount=$amount, totalAmount=$totalAmount, participants=$participants, description=$description');

                            return Align(
                              alignment: isYouPaid ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  developer.log('🔵 CHAT DIALOG: type=$type, amount=$amount, totalAmount=$totalAmount');
                                  final items = <DetailItem>[];
                                  
                                  if (type == 'expense') {
                                    items.add(DetailItem(
                                      label: 'Description',
                                      value: description,
                                      icon: Icons.description,
                                    ));
                                    if (totalAmount != null) {
                                      items.add(DetailItem(
                                        label: 'Total Amount',
                                        value: 'Rs ${formatPaise(totalAmount)}',
                                        icon: Icons.account_balance_wallet,
                                        valueColor: AppColors.primary,
                                      ));
                                    }
                                    items.add(DetailItem(
                                      label: 'Your Share',
                                      value: 'Rs ${formatPaise(amount)}',
                                      icon: Icons.person,
                                      valueColor: AppColors.primary,
                                    ));
                                    if (participants > 0) {
                                      items.add(DetailItem(
                                        label: 'Split Between',
                                        value: '${participants + 1} ${participants + 1 == 1 ? "person" : "people"}',
                                        icon: Icons.group,
                                      ));
                                    }
                                  } else {
                                    items.add(DetailItem(
                                      label: 'Description',
                                      value: description,
                                      icon: Icons.description,
                                    ));
                                    items.add(DetailItem(
                                      label: 'Amount',
                                      value: 'Rs ${formatPaise(amount)}',
                                      icon: Icons.payments,
                                      valueColor: isYouPaid ? AppColors.success : AppColors.info,
                                    ));
                                    items.add(DetailItem(
                                      label: 'Type',
                                      value: isYouPaid ? 'You paid' : 'You received',
                                      icon: isYouPaid ? Icons.call_made : Icons.call_received,
                                    ));
                                  }
                                  
                                  items.add(DetailItem(
                                    label: 'Date',
                                    value: '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                    icon: Icons.calendar_today,
                                  ));
                                  
                                  showDialog(
                                    context: context,
                                    builder: (context) => DetailDialog(
                                      title: type == 'expense' ? 'Expense Details' : 'Transaction Details',
                                      items: items,
                                      accentColor: type == 'expense' ? AppColors.primary : (isYouPaid ? AppColors.success : AppColors.info),
                                    ),
                                  );
                                },
                                onLongPress: canDelete ? () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text('Delete Expense'),
                                      content: const Text('Are you sure you want to delete this expense?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true && mounted) {
                                    try {
                                      await context.read<ExpenseService>().deleteExpense(expenseId!);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Expense deleted')),
                                        );
                                        await _syncFromServer();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Failed to delete expense')),
                                        );
                                      }
                                    }
                                  }
                                } : null,
                                child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1,
                                  ),
                                  boxShadow: AppShadows.card,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (type == 'expense' ? AppColors.primary : (isYouPaid ? AppColors.success : AppColors.info)).withOpacity(0.1),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(11),
                                          topRight: Radius.circular(11),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(type == 'expense' ? Icons.receipt_long : Icons.payments,
                                            size: 12, color: type == 'expense' ? AppColors.primary : (isYouPaid ? AppColors.success : AppColors.info)),
                                          const SizedBox(width: 5),
                                          Text(
                                            tagText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: type == 'expense' ? AppColors.primary : (isYouPaid ? AppColors.success : AppColors.info),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${date.day}/${date.month}',
                                            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (description.isNotEmpty) ...[
                                            Text(
                                              description,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                          ],
                                          Text(
                                            'Rs ${formatPaise(amount)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          },
                        ),
                      ),
                if (_loadingMore)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.card,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Loading older...'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_syncing || _submitting) ? null : _addExpenseFromChat,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_syncing || _submitting) ? null : _addTransactionFromChat,
                      icon: const Icon(Icons.payments),
                      label: const Text('Add Transaction'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
