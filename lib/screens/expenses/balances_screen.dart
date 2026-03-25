import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_shadows.dart';
import '../../widgets/loading_indicator.dart';
import '../../models/contact_model.dart';
import '../../services/app_preferences_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../bloc/contact_provider.dart';
import '../../utils/money_utils.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/contact_identity_details.dart';
import '../contacts/conversation_screen.dart';

class _Settlement {
  final String fromKey;
  final String toKey;
  final int amount;
  const _Settlement(this.fromKey, this.toKey, this.amount);
}

List<_Settlement> _computeSettlements(Map<String, dynamic> balances) {
  final credits = <MapEntry<String, int>>[];
  final debts = <MapEntry<String, int>>[];

  balances.forEach((key, value) {
    final amt = (value as num).round();
    if (amt > 0) credits.add(MapEntry(key, amt));
    if (amt < 0) debts.add(MapEntry(key, amt.abs()));
  });

  credits.sort((a, b) => b.value.compareTo(a.value));
  debts.sort((a, b) => b.value.compareTo(a.value));

  final result = <_Settlement>[];
  int i = 0, j = 0;
  final creditAmts = credits.map((e) => e.value).toList();
  final debtAmts = debts.map((e) => e.value).toList();

  while (i < credits.length && j < debts.length) {
    final settle = creditAmts[i] < debtAmts[j] ? creditAmts[i] : debtAmts[j];
    result.add(_Settlement(debts[j].key, credits[i].key, settle));
    creditAmts[i] -= settle;
    debtAmts[j] -= settle;
    if (creditAmts[i] == 0) i++;
    if (debtAmts[j] == 0) j++;
  }
  return result;
}

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
        await _loadContactsLookup(context.read<ExpenseService>().getCachedBalanceContacts());
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

  Future<void> _loadContactsLookup(List<ContactModel> all) async {
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
      await _loadContactsLookup(expenseService.getCachedBalanceContacts());
      int net = 0;
      balances.forEach((_, amount) => net += (amount as num).round());
      if (mounted) {
        setState(() {
          _balances = balances;
          _netBalance = net;
        });
      }
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

  String _getBalanceText(int amount, String currencyCode) {
    final formatted = formatMinorUnits(
      amount,
      currencyCode: currencyCode,
      absolute: true,
    );
    if (amount > 0) return 'Owes you $formatted';
    if (amount < 0) return 'You owe $formatted';
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
                    child: Text('No balances yet', style: AppTextStyles.headlineSmall(context)),
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
        final preferredCurrencyCode =
            context.watch<AppPreferencesService>().preferredCurrencyCode;
        final settlements = _computeSettlements(_balances);
        return Column(
          children: [
            LoadingIndicator(isLoading: _refreshing),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadBalances(forceRefresh: true),
                child: ListView(
                  padding: AppDimensions.appMargin(context),
                  children: [
                    // Net balance card
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
                            formatMinorUnits(
                              _netBalance,
                              currencyCode: preferredCurrencyCode,
                            ),
                            style: AppTextStyles.currencyLarge(context).copyWith(
                              color: _getBalanceColor(_netBalance),
                            ),
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
                    // Settlement suggestions
                    if (settlements.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Suggested Settlements',
                            style: AppTextStyles.labelLarge(context).copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      AppDimensions.h10(context),
                      ...settlements.map((s) {
                        final fromContact = _getContact(s.fromKey);
                        final toContact = _getContact(s.toKey);
                        final fromName = fromContact?.name?.isNotEmpty == true ? fromContact!.name! : s.fromKey;
                        final toName = toContact?.name?.isNotEmpty == true ? toContact!.name! : s.toKey;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_forward, size: 14, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$fromName pays $toName',
                                  style: AppTextStyles.bodySmall(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatMinorUnits(
                                  s.amount,
                                  currencyCode: preferredCurrencyCode,
                                ),
                                style: AppTextStyles.labelLarge(context).copyWith(color: AppColors.success),
                              ),
                            ],
                          ),
                        );
                      }),
                      AppDimensions.h10(context),
                    ],
                    // Balances list
                    ..._balances.entries.map((entry) {
                      final key = entry.key;
                      final amount = (entry.value as num).round();
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
                                    _getBalanceText(amount, preferredCurrencyCode),
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
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
