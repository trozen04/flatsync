import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_container.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../utils/custom_snackbar.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  List<ContactModel> _contacts = [];
  final List<String> _selectedParticipants = [];
  List<int> _recentAmountsPaise = [];

  bool _loadingContacts = true;
  bool _submitting = false;
  StreamSubscription<int>? _expenseUpdatesSub;
  StreamSubscription<int>? _contactUpdatesSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLocalContacts();
        _loadRecentAmounts();
        _syncContactsFromBalances(forceRefresh: true);
        _expenseUpdatesSub = context.read<ExpenseService>().updates.listen((_) {
          if (mounted) _syncContactsFromBalances(forceRefresh: true);
        });
        _contactUpdatesSub = context.read<ContactService>().updates.listen((_) {
          if (mounted) _loadLocalContacts();
        });
      }
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _expenseUpdatesSub?.cancel();
    _contactUpdatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalContacts({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) {
      setState(() => _loadingContacts = true);
    }

    try {
      final isar = context.read<IsarService>();
      final allContacts = await isar.isar.contactModels.where().findAll();
      allContacts.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      if (mounted) setState(() => _contacts = allContacts);
    } catch (e) {
      developer.log('Load contacts error: $e');
    } finally {
      if (showLoader && mounted) {
        setState(() => _loadingContacts = false);
      }
    }
  }

  Future<void> _syncContactsFromBalances({bool forceRefresh = false}) async {
    try {
      final expenseService = context.read<ExpenseService>();
      final contactService = context.read<ContactService>();
      final isar = context.read<IsarService>();
      final balances = await expenseService.getBalances(forceRefresh: forceRefresh);
      if (balances.isNotEmpty) {
        await contactService.autoSyncFromBalances(balances, isar);
      }
      await _loadLocalContacts(showLoader: false);
    } catch (e) {
      developer.log('Sync contacts from balances error: $e');
      await _loadLocalContacts(showLoader: false);
    }
  }

  Future<void> _loadRecentAmounts() async {
    try {
      final recent = await context.read<ExpenseService>().getRecentAmounts();
      if (!mounted) return;
      setState(() => _recentAmountsPaise = recent);
    } catch (_) {}
  }

  Future<void> _addExpense() async {
    if (_descController.text.trim().isEmpty || _amountController.text.trim().isEmpty) {
      CustomSnackBar.show(context, message: 'Fill all fields', isError: true);
      return;
    }

    if (_selectedParticipants.isEmpty) {
      CustomSnackBar.show(context, message: 'Select at least one participant', isError: true);
      return;
    }

    final amountValue = double.tryParse(_amountController.text.trim());
    if (amountValue == null || amountValue <= 0) {
      CustomSnackBar.show(context, message: 'Enter a valid amount', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      await context.read<ExpenseService>().createExpense(
            description: _descController.text.trim(),
            totalAmount: (amountValue * 100).toInt(),
            participants: List<String>.from(_selectedParticipants),
          );

      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Expense added successfully');
      _descController.clear();
      _amountController.clear();
      await _loadRecentAmounts();
      setState(() {
        _selectedParticipants.clear();
      });
    } catch (e) {
      developer.log('Add expense error: $e');
      if (mounted) {
        CustomSnackBar.show(context, message: 'Failed to add expense', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final perPerson =
        _selectedParticipants.isEmpty ? 0 : totalAmount / (_selectedParticipants.length + 1);

    if (_loadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLocalContacts,
        child: ListView(
          children: [
            AppDimensions.h100(context),
            const Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary),
            AppDimensions.h20(context),
            Center(
              child: Text(
                'No contacts',
                style: AppTextStyles.headlineSmall(context),
              ),
            ),
            AppDimensions.h10(context),
            Center(
              child: Text(
                'Add contacts to split expenses',
                style: AppTextStyles.bodyMedium(context),
              ),
            ),
            AppDimensions.h20(context),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/contact-selection');
                  if (result != null) {
                    await _loadLocalContacts();
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Import Contacts'),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        body: SafeArea(
          child: Column(
            children: [
              if (_submitting) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadLocalContacts,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppDimensions.appMargin(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixText: 'Rs  ',
                            hintText: '0.00',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}(\.\d{0,2})?')),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: AppTextStyles.currencyLarge(context),
                        ),
                        if (_recentAmountsPaise.isNotEmpty) ...[
                          AppDimensions.h10(context),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _recentAmountsPaise.map((paise) {
                              final rupees = paise / 100;
                              return ActionChip(
                                label: Text('Rs ${rupees.toStringAsFixed(2)}'),
                                onPressed: () {
                                  _amountController.text = rupees.toStringAsFixed(2);
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        AppDimensions.h20(context),
                        TextField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          maxLength: 50,
                        ),
                        AppDimensions.h20(context),
                        if (totalAmount > 0 && _selectedParticipants.isNotEmpty)
                          Container(
                            padding: AppDimensions.containerPadding(context),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total:', style: AppTextStyles.labelLarge(context)),
                                    Text(
                                      'Rs ${totalAmount.toStringAsFixed(2)}',
                                      style: AppTextStyles.currency(context),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Split ${_selectedParticipants.length + 1} ways',
                                      style: AppTextStyles.bodySmall(context),
                                    ),
                                    Text(
                                      'Rs ${perPerson.toStringAsFixed(2)}/person',
                                      style: AppTextStyles.labelLarge(context).copyWith(color: AppColors.success),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        AppDimensions.h20(context),
                        Text(
                          'Select Participants',
                          style: AppTextStyles.titleMedium(context),
                        ),
                        AppDimensions.h10(context),
                        ..._contacts.map((contact) {
                          final phone = contact.phoneNumber;
                          final selected = phone != null && _selectedParticipants.contains(phone);
                          return AppContainer(
                            margin: EdgeInsets.only(bottom: AppDimensions.height(context) * 0.012),
                            radius: 16,
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.28)
                                  : Colors.transparent,
                            ),
                            shadows: [
                              BoxShadow(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.16)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: selected ? 16 : 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            color: selected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.09)
                                : Theme.of(context).colorScheme.surface,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: phone == null
                                  ? null
                                  : () {
                                      setState(() {
                                        if (selected) {
                                          _selectedParticipants.remove(phone);
                                        } else {
                                          _selectedParticipants.add(phone);
                                        }
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                                      child: Text(
                                        (contact.name?.isNotEmpty ?? false)
                                            ? contact.name![0].toUpperCase()
                                            : '?',
                                        style: AppTextStyles.labelLarge(context).copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact.name ?? 'Unknown',
                                            style: AppTextStyles.labelLarge(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact.phoneNumber ?? '',
                                            style: AppTextStyles.bodySmall(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: selected
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outlineVariant,
                                          width: 1.6,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        AppDimensions.h50(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.width(context) * 0.04),
          child: AppButton(
            text: 'Add Expense',
            onPressed: _addExpense,
            isLoading: _submitting,
            fullWidth: true,
            size: AppButtonSize.large,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
