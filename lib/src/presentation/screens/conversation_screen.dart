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

class ConversationScreen extends StatefulWidget {
  final ContactModel contact;

  const ConversationScreen({super.key, required this.contact});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<dynamic> _transactions = [];
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  double _balance = 0;
  String? _currentUserId;
  static const double _currencyDivisor = 100.0;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<int>? _updatesSub;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversation(forceRefresh: false));
    _loadCurrentUserId();
    _scrollController.addListener(_onScroll);
    _updatesSub = context.read<ExpenseService>().updates.listen((_) {
      if (mounted) _loadConversation(forceRefresh: true);
    });
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

  double _resolveContactBalance(Map<String, dynamic> balances) {
    final contactId = widget.contact.contactId;
    if (contactId != null && contactId.isNotEmpty) {
      final byId = balances[contactId];
      if (byId is num) return byId.toDouble();
    }

    final contactPhone = _canonicalPhone(widget.contact.phoneNumber);
    for (final entry in balances.entries) {
      if (_canonicalPhone(entry.key) == contactPhone && entry.value is num) {
        return (entry.value as num).toDouble();
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
      final conversation = await expenseService.getConversation(
        contactId,
        page: _currentPage + 1,
        forceRefresh: true,
      );

      if (!mounted) return;
      setState(() {
        _transactions.addAll(conversation);
        _currentPage++;
        _hasMore = conversation.length >= 20;
      });
    } catch (e) {
      developer.log('Load more error: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
                    labelText: 'Description',
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
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(context, {
                  'amount': amount,
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
    final phone = widget.contact.phoneNumber;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact phone missing')),
      );
      return;
    }

    final input = await _showEntryDialog(isTransaction: false);
    if (input == null) return;

    setState(() => _refreshing = true);
    try {
      final amount = ((input['amount'] as double) * 100).toInt();
      final description = (input['description'] as String?)?.trim();
      await context.read<ExpenseService>().createExpense(
            description: (description == null || description.isEmpty) ? 'Expense' : description,
            totalAmount: amount,
            participants: [phone],
          );
      await _loadConversation(forceRefresh: true);
    } catch (e) {
      developer.log('Add chat expense error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add expense')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _addTransactionFromChat() async {
    final toUserId = widget.contact.contactId;
    if (toUserId == null || toUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction requires a registered contact')),
      );
      return;
    }

    final input = await _showEntryDialog(isTransaction: true);
    if (input == null) return;

    setState(() => _refreshing = true);
    try {
      final amount = ((input['amount'] as double) * 100).toInt();
      await context.read<ExpenseService>().createTransaction(
            toUserId: toUserId,
            amount: amount,
          );
      await _loadConversation(forceRefresh: true);
    } catch (e) {
      developer.log('Add chat transaction error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add transaction')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadConversation({bool forceRefresh = false}) async {
    setState(() => _refreshing = true);

    try {
      final contactId = widget.contact.contactId;
      final expenseService = context.read<ExpenseService>();
      List<dynamic> conversation;
      if (contactId != null && contactId.isNotEmpty) {
        try {
          conversation = await expenseService.getConversation(
            contactId,
            forceRefresh: forceRefresh,
            page: 1,
          );
        } catch (_) {
          // Fallback to local expense-derived timeline if network/API conversation fetch fails.
          conversation = await expenseService.getConversationByPhone(
            widget.contact.phoneNumber ?? '',
            forceRefresh: false,
          );
        }
      } else {
        conversation = await expenseService.getConversationByPhone(
          widget.contact.phoneNumber ?? '',
          forceRefresh: forceRefresh,
        );
      }

      final balances = await expenseService.getBalances(forceRefresh: forceRefresh);
      final balance = _resolveContactBalance(balances);

      if (mounted) setState(() {
        _transactions = conversation;
        _balance = balance;
        _currentPage = 1;
        _hasMore = conversation.length >= 20;
      });
    } catch (e) {
      developer.log('Load conversation error: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
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
      appBar: AppBar(
        title: Text(widget.contact.name ?? 'User'),
      ),
      body: Column(
        children: [
          if (_refreshing) const LinearProgressIndicator(minHeight: 2),
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
                  'Rs ${(_balance.abs() / _currencyDivisor).toStringAsFixed(2)}',
                  style: AppTextStyles.currency(context).copyWith(color: balanceColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: _transactions.isEmpty
                ? RefreshIndicator(
                    onRefresh: () => _loadConversation(forceRefresh: true),
                    child: ListView(
                      children: [
                        SizedBox(height: AppDimensions.height(context) * 0.2),
                        Center(
                          child: Text('No transactions yet', style: AppTextStyles.bodyMedium(context)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadConversation(forceRefresh: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      reverse: true,
                      itemCount: _transactions.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                            if (index == _transactions.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final item = _transactions[index];
                            final type = item['type'];
                            final amount = (item['amount'] as num).toDouble();
                            final description = item['description'] ?? '';
                            final direction = item['direction'] as String? ?? '';
                            final date = DateTime.parse(item['createdAt'] as String);
                            final expenseId = item['expenseId'] as String?;
                            final createdBy = item['createdBy'] as String?;
                            final canDelete = type == 'expense' && expenseId != null && createdBy == _currentUserId;
                            final isYouPaid = direction == 'you_paid' || direction == 'sent';
                            final tagText = type == 'expense' ? 'Expense' : 'Transaction';
                            final tagColor = type == 'expense' ? Colors.orange : Colors.blue;

                            return Align(
                              alignment: isYouPaid ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
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
                                        await _loadConversation(forceRefresh: true);
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
                                margin: const EdgeInsets.only(bottom: 12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isYouPaid ? 16 : 4),
                                    bottomRight: Radius.circular(isYouPaid ? 4 : 16),
                                  ),
                                  border: Border.all(
                                    color: isYouPaid
                                        ? Colors.green.withOpacity(0.25)
                                        : Colors.blue.withOpacity(0.22),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isYouPaid
                                            ? Colors.green.withOpacity(0.08)
                                            : tagColor.withOpacity(0.08),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(15),
                                          topRight: Radius.circular(15),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(type == 'expense' ? Icons.receipt_long : Icons.payments,
                                            size: 14, color: tagColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            tagText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: tagColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${date.day}/${date.month}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            description,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Rs  ${(amount / _currencyDivisor).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
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
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _refreshing ? null : _addExpenseFromChat,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _refreshing ? null : _addTransactionFromChat,
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
