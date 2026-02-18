import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/expense_service.dart';
import '../../presentation/state/contact_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _allTransactions = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  final int _pageSize = 20;
  StreamSubscription<int>? _updatesSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
      _scrollController.addListener(_onScroll);
      _updatesSub = context.read<ExpenseService>().updates.listen((_) {
        if (mounted) _loadHistory();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    
    try {
      final expenseService = context.read<ExpenseService>();
      final expenses = await expenseService.getExpenses(forceRefresh: false);
      
      final startIndex = _currentPage * _pageSize;
      if (startIndex >= expenses.length) {
        if (mounted) setState(() => _loadingMore = false);
        return;
      }
      
      final endIndex = (startIndex + _pageSize).clamp(0, expenses.length);
      final newExpenses = expenses.sublist(startIndex, endIndex);
      
      final newHistory = newExpenses.map((e) => {
        'type': 'expense',
        'description': e.description ?? 'Expense',
        'amount': e.amount,
        'paidBy': e.paidBy,
        'participants': e.participants,
        'createdAt': e.createdAt,
      }).toList();

      if (mounted) {
        setState(() {
          _allTransactions.addAll(newHistory);
          _currentPage++;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _currentPage = 1;
    });
    
    try {
      final expenseService = context.read<ExpenseService>();
      final expenses = await expenseService.getExpenses(forceRefresh: true);
      
      final endIndex = (_pageSize).clamp(0, expenses.length);
      final history = expenses.sublist(0, endIndex).map((e) => {
        'type': 'expense',
        'description': e.description ?? 'Expense',
        'amount': e.amount,
        'paidBy': e.paidBy,
        'participants': e.participants,
        'createdAt': e.createdAt,
      }).toList();

      history.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      if (mounted) setState(() {
        _allTransactions = history;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            AppDimensions.h20(context),
            Text(
              'No history yet',
              style: AppTextStyles.headlineSmall(context),
            ),
            AppDimensions.h10(context),
            Text(
              'Your transaction history will appear here',
              style: AppTextStyles.bodyMedium(context),
            ),
          ],
        ),
      );
    }

    return Consumer<ContactProvider>(
      builder: (context, contactProvider, _) {
        return RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: _allTransactions.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _allTransactions.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final item = _allTransactions[index];
              final type = item['type'] as String;
              final amount = (item['amount'] as int) / 100;
              final description = item['description'] as String;
              final paidBy = item['paidBy'] as String;
              final date = item['createdAt'] as DateTime;
              final displayName = contactProvider.getDisplayName(paidBy);
              final amountColor = type == 'expense' ? AppColors.warning : AppColors.info;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: type == 'expense' ? Colors.orange.shade50 : Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                          child: Icon(
                            type == 'expense' ? Icons.receipt_long : Icons.payment,
                          color: type == 'expense' ? Colors.orange.shade600 : Colors.blue.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: AppTextStyles.titleMedium(context),
                            ),
                            AppDimensions.h5(context),
                            Text(
                              displayName,
                              style: AppTextStyles.bodySmall(context),
                            ),
                            AppDimensions.h5(context),
                            Text(
                              '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                              style: AppTextStyles.caption(context),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs ${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

