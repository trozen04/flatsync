import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/app_container.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../presentation/state/contact_provider.dart';
import 'conversation_screen.dart';

class BalancesScreen extends StatefulWidget {
  const BalancesScreen({super.key});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  Map<String, dynamic> _balances = {};
  bool _refreshing = false;
  double _netBalance = 0;
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

  String _canonicalPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

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
      
      if (mounted && balances.isNotEmpty) {
        final contactService = context.read<ContactService>();
        final isar = context.read<IsarService>();
        unawaited(contactService.autoSyncFromBalances(balances, isar));
      }
      
      if (!mounted) return;
      await _loadContactsLookup();

      double net = 0;
      balances.forEach((_, amount) => net += (amount as num).toDouble());

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

  Color _getBalanceColor(double amount) {
    if (amount > 0) return AppColors.success;
    if (amount < 0) return AppColors.error;
    return AppColors.textSecondary;
  }

  String _getBalanceText(double amount) {
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
          if (_refreshing) const LinearProgressIndicator(minHeight: 2),
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
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Consumer<ContactProvider>(
      builder: (context, contactProvider, _) {
        return RefreshIndicator(
          onRefresh: () => _loadBalances(forceRefresh: true),
          child: Padding(
            padding: AppDimensions.appMargin(context),
            child: Column(
              children: [
                if (_refreshing) const LinearProgressIndicator(minHeight: 2),
                Container(
                  padding: AppDimensions.containerPadding(context),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getBalanceColor(_netBalance).withOpacity(0.15),
                        _getBalanceColor(_netBalance).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getBalanceColor(_netBalance).withOpacity(0.16),
                    ),
                    boxShadow: AppShadows.cardElevated,
                  ),
                  child: Column(
                    children: [
                      Text('Net Balance', style: AppTextStyles.labelLarge(context)),
                      AppDimensions.h10(context),
                      Text(
                        'Rs ${(_netBalance.abs() / _currencyDivisor).toStringAsFixed(2)}',
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
                      final amount = (_balances[key] as num).toDouble();
                      final contact = _getContact(key);
                      final name = contactProvider.getDisplayName(key);

                      return AppContainer(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getBalanceColor(amount).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: _getBalanceColor(amount),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: AppTextStyles.titleMedium(context),
                                  ),
                                  AppDimensions.h5(context),
                                  Text(
                                    _getBalanceText(amount),
                                    style: AppTextStyles.labelLarge(context).copyWith(color: _getBalanceColor(amount)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
