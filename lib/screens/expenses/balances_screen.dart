import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_shadows.dart';
import '../../widgets/loading_indicator.dart';
import '../../models/contact_model.dart';
import '../../services/isar_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../bloc/contact_provider.dart';
import '../../utils/money_utils.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/contact_identity_details.dart';
import '../contacts/conversation_screen.dart';

class BalancesScreen extends StatefulWidget {
  final VoidCallback onNavigateToAddExpense;

  const BalancesScreen({super.key, required this.onNavigateToAddExpense});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  Map<String, dynamic> _balances = {};
  bool _refreshing = false;
  int _netBalance = 0;
  static const double _currencyDivisor = 100.0;

  StreamSubscription<int>? _updatesSub;
  StreamSubscription<int>? _contactUpdatesSub;
  Map<String, ContactModel> _contactsById = {};
  Map<String, ContactModel> _contactsByPhone = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadBalances(forceRefresh: false));
      _updatesSub = context.read<ExpenseService>().updates.listen((_) {
        if (mounted) _loadBalances(forceRefresh: true);
      });
      _contactUpdatesSub = context.read<ContactService>().updates.listen((_) async {
        if (!mounted) return;
        await _loadContactsLookup();
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _contactUpdatesSub?.cancel();
    super.dispose();
  }

  String _canonicalPhone(String value) => PhoneUtils.canonical(value);

  Future<void> _loadContactsLookup() async {
    final isar = context.read<IsarService>();
    final all = await isar.isar.contactModels.where().findAll();

    _contactsById = {
      for (final c in all)
        if (c.contactId != null && c.contactId!.isNotEmpty) c.contactId!: c,
    };

    _contactsByPhone = {
      for (final c in all)
        if (c.phoneNumber != null && c.phoneNumber!.isNotEmpty)
          _canonicalPhone(c.phoneNumber!): c,
    };
  }

  Future<void> _loadBalances({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _refreshing = true);

    try {
      if (!mounted) return;
      final expenseService = context.read<ExpenseService>();
      final balances = await expenseService.getBalances(forceRefresh: forceRefresh);
      
      if (!mounted) return;
      await _loadContactsLookup();

      int net = 0;
      balances.forEach((_, amount) => net += (amount as num).round());

      if (mounted) setState(() {
        _balances = balances;
        _netBalance = net;
      });
    } catch (e) {
      developer.log('Load balances error: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  ContactModel? _getContact(String userIdOrPhone) {
    final byId = _contactsById[userIdOrPhone];
    if (byId != null) return byId;
    return _contactsByPhone[_canonicalPhone(userIdOrPhone)];
  }

  Color _getBalanceColor(int amount) {
    if (amount > 0) return AppColors.success;
    if (amount < 0) return AppColors.error;
    return AppColors.textSecondary;
  }

  String _getBalanceText(int amount) {
    final rupees = amount.abs() / _currencyDivisor;
    if (amount > 0) return 'owes you Rs ${rupees.toStringAsFixed(2)}';
    if (amount < 0) return 'you owe Rs ${rupees.toStringAsFixed(2)}';
    return 'settled';
  }

  @override
  Widget build(BuildContext context) {
    if (_balances.isEmpty) {
      return Column(
        children: [
          LoadingIndicator(isLoading: _refreshing),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadBalances(forceRefresh: true),
              child: ListView(
                children: [
                  AppDimensions.h100(context),
                  const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.textTertiary),
                  AppDimensions.h20(context),
                  Center(
                    child: Text(
                      'No balances yet',
                      style: AppTextStyles.headlineSmall(context),
                    ),
                  ),
                  AppDimensions.h10(context),
                  Center(
                    child: Text('Add expenses to see balances', style: AppTextStyles.bodyMedium(context)),
                  ),
                  AppDimensions.h20(context),
                  Center(
                    child: FilledButton.icon(
                      onPressed: widget.onNavigateToAddExpense,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Consumer<ContactProvider>(
      builder: (context, contactProvider, _) {
        return Stack(
          children: [
            Column(
              children: [
                LoadingIndicator(isLoading: _refreshing),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadBalances(forceRefresh: true),
                    child: Padding(
                      padding: AppDimensions.appMargin(context),
                      child: Column(
              children: [
                Container(
                  padding: AppDimensions.containerPadding(context),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getBalanceColor(_netBalance).withValues(alpha: 0.16),
                    ),
                    boxShadow: AppShadows.cardElevated,
                  ),
                  child: Column(
                    children: [
                      Text('Net Balance', style: AppTextStyles.labelLarge(context)),
                      AppDimensions.h10(context),
                      Text(
                        'Rs ${formatPaise(_netBalance)}',
                        style: AppTextStyles.currencyLarge(context).copyWith(color: _getBalanceColor(_netBalance)),
                      ),
                      AppDimensions.h5(context),
                      Text(
                        _netBalance > 0 ? 'You are owed' : _netBalance < 0 ? 'You owe' : 'All settled',
                        style: AppTextStyles.bodySmall(context),
                      ),
                    ],
                  ),
                ),
                AppDimensions.h20(context),
                Expanded(
                  child: ListView.builder(
                    itemCount: _balances.length,
                    itemBuilder: (context, index) {
                      final key = _balances.keys.elementAt(index);
                      final amount = (_balances[key] as num).round();
                      final contact = _getContact(key);
                      final name = contactProvider.getDisplayName(key);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.card,
                        ),
                        child: InkWell(
                          onTap: contact == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ConversationScreen(contact: contact),
                                    ),
                                  ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _getBalanceColor(amount).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: _getBalanceColor(amount),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ContactIdentityDetails(
                                  name: name,
                                  phoneNumber: contact?.phoneNumber ?? key,
                                  isVerified: contact?.isRegistered ?? false,
                                  nameStyle: AppTextStyles.titleMedium(context).copyWith(fontSize: 15),
                                  phoneStyle: AppTextStyles.bodySmall(context).copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  extra: Text(
                                    _getBalanceText(amount),
                                    style: AppTextStyles.labelLarge(context).copyWith(
                                      color: _getBalanceColor(amount),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

