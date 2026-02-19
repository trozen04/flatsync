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
  bool _syncing = false;
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
        localData = await expenseService.getConversation(contactId, forceRefresh: false, page: 1);
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
          _hasMore = localData.length >= 20;
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
    if (_syncing) {
      developer.log('🟡 _syncFromServer: Already syncing, RETURN');
      return;
    }
    if (mounted) {
      setState(() => _syncing = true);
      developer.log('🟢 _syncFromServer: Set _syncing=true');
    }
    
    try {
      final contactId = widget.contact.contactId;
      final expenseService = context.read<ExpenseService>();
      List<dynamic> serverData;
      
      if (contactId != null && contactId.isNotEmpty) {
        developer.log('🟢 _syncFromServer: Fetching by contactId=$contactId');
        serverData = await expenseService.getConversation(contactId, forceRefresh: true, page: 1);
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
          _currentPage = 1;
          _hasMore = serverData.length >= 20;
        });
        developer.log('🟢 _syncFromServer: State updated');
      }
    } catch (e) {
      developer.log('🔴 _syncFromServer ERROR: $e');
    } finally {
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
    if (_scrollController.position.pixels <= _scrollController.position.minScrollExtent + 200) {
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

    setState(() => _syncing = true);
    try {
      final amount = ((input['amount'] as double) * 100).toInt();
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
      if (mounted) setState(() => _syncing = false);
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

    setState(() => _syncing = true);
    try {
      final amount = ((input['amount'] as double) * 100).toInt();
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
      if (mounted) setState(() => _syncing = false);
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
                if (_loadingMore)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                      onPressed: _syncing ? null : _addExpenseFromChat,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _syncing ? null : _addTransactionFromChat,
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
