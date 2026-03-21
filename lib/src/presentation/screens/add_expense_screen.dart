import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/custom_button.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/isar_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../utils/custom_snackbar.dart';
import 'contact_selection_screen.dart';
import '../../utils/money_utils.dart';
import '../widgets/contact_identity_details.dart';

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
  DateTime? _lastBalanceContactSyncAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLocalContacts();
        _loadRecentAmounts();
        _syncContactsFromBalances(forceRefresh: false);
        _expenseUpdatesSub = context.read<ExpenseService>().updates.listen((_) {
          // Avoid creating a balances->contacts->balances feedback loop and extra network hits.
          if (mounted) _syncContactsFromBalances(forceRefresh: false);
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

  ContactModel? _contactByPhone(String phone) {
    for (final c in _contacts) {
      if ((c.phoneNumber ?? '') == phone) return c;
    }
    return null;
  }

  Future<void> _openParticipantPicker() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return _ParticipantPickerSheet(
          contacts: _contacts,
          initiallySelected: _selectedParticipants,
          onAddContacts: () async {
            Navigator.pop(ctx, null); // close sheet first
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactSelectionScreen()),
            );
            await _loadLocalContacts();
            if (mounted) _openParticipantPicker(); // re-open with fresh contacts
          },
        );
      },
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selectedParticipants
        ..clear()
        ..addAll(picked);
    });
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
    final now = DateTime.now();
    if (_lastBalanceContactSyncAt != null &&
        now.difference(_lastBalanceContactSyncAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastBalanceContactSyncAt = now;

    try {
      final expenseService = context.read<ExpenseService>();
      final contactService = context.read<ContactService>();
      final isar = context.read<IsarService>();
      final balances = await expenseService.getBalances(forceRefresh: forceRefresh);
      if (balances.isNotEmpty) {
        final contacts = expenseService.getCachedBalanceContacts();
        if (contacts.isNotEmpty) {
          await contactService.upsertContactsByCanonical(isar, contacts);
          contactService.notifyUpdate();
        }
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
    if (_amountController.text.trim().isEmpty) {
      CustomSnackBar.show(context, message: 'Enter an amount', isError: true);
      return;
    }

    if (_selectedParticipants.isEmpty) {
      CustomSnackBar.show(context, message: 'Select at least one participant', isError: true);
      return;
    }

    final amountPaise = parseRupeesToPaise(_amountController.text);
    if (amountPaise == null) {
      CustomSnackBar.show(context, message: 'Enter a valid amount', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final desc = _descController.text.trim();
      await context.read<ExpenseService>().createExpense(
            description: desc.isEmpty ? 'Expense' : desc,
            totalAmount: amountPaise,
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
    final mediaQuery = MediaQuery.of(context);
    final totalPaise = parseRupeesToPaise(_amountController.text) ?? 0;
    final totalAmount = totalPaise / 100.0;
    final perPerson =
        _selectedParticipants.isEmpty ? 0 : totalAmount / (_selectedParticipants.length + 1);
    final bottomClearance = 120.0 + mediaQuery.viewPadding.bottom;

    if (_loadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLocalContacts,
        child: Padding(
          padding: AppDimensions.appMargin(context),
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
                child: CustomButton(
                  text: 'Import Contacts',
                  icon: Icons.person_add,
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/contact-selection');
                    if (result != null) {
                      await _loadLocalContacts();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.35),
        resizeToAvoidBottomInset: true,
        body: RefreshIndicator(
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
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentAmountsPaise.length > 4 ? 4 : _recentAmountsPaise.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final paise = _recentAmountsPaise[index];
                          final rupees = paise / 100;
                          return ActionChip(
                            label: Text('Rs ${rupees.toStringAsFixed(2)}'),
                            onPressed: () {
                              _amountController.text = rupees.toStringAsFixed(2);
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  AppDimensions.h20(context),
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    maxLength: 50,
                  ),
                  AppDimensions.h20(context),
                  Container(
                    padding: AppDimensions.containerPadding(context),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
                      ),
                      boxShadow: AppShadows.card,
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
                              'Split with ${_selectedParticipants.length} ${_selectedParticipants.length == 1 ? "person" : "people"}',
                              style: AppTextStyles.bodySmall(context),
                            ),
                            Text(
                              'Rs ${perPerson.toStringAsFixed(2)}/person',
                              style: AppTextStyles.labelLarge(context).copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        AppDimensions.h10(context),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                label: Text(_selectedParticipants.isEmpty ? 'Choose people' : 'Edit people'),
                                avatar: const Icon(Icons.group_add, size: 18),
                                onPressed: _openParticipantPicker,
                              ),
                              ..._selectedParticipants.take(6).map((phone) {
                                final c = _contactByPhone(phone);
                                final name = (c?.name ?? '').trim();
                                final label = name.isNotEmpty ? name : phone;
                                return InputChip(
                                  label: Text(label, overflow: TextOverflow.ellipsis),
                                  onDeleted: () => setState(() => _selectedParticipants.remove(phone)),
                                );
                              }),
                              if (_selectedParticipants.length > 6)
                                Chip(label: Text('+${_selectedParticipants.length - 6} more')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppDimensions.h20(context),
                  CustomButton(
                    text: 'Add Expense',
                    onPressed: _addExpense,
                    isLoading: _submitting,
                  ),
                  SizedBox(height: bottomClearance),
                ],
              ),
            ),
          ),
      ),
    );
  }
}

class _ParticipantPickerSheet extends StatefulWidget {
  final List<ContactModel> contacts;
  final List<String> initiallySelected;
  final VoidCallback onAddContacts;

  const _ParticipantPickerSheet({
    required this.contacts,
    required this.initiallySelected,
    required this.onAddContacts,
  });

  @override
  State<_ParticipantPickerSheet> createState() => _ParticipantPickerSheetState();
}

class _ParticipantPickerSheetState extends State<_ParticipantPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late final List<String> _selected = List<String>.from(widget.initiallySelected);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final filtered = _query.trim().isEmpty
        ? widget.contacts
        : widget.contacts.where((c) {
            final q = _query.trim().toLowerCase();
            return (c.name ?? '').toLowerCase().contains(q) ||
                (c.phoneNumber ?? '').toLowerCase().contains(q);
          }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose people',
                      style: AppTextStyles.titleMedium(context),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onAddContacts,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text('Done (${_selected.length})'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search participants',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 48, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty ? 'No contacts yet' : 'No results',
                            style: AppTextStyles.bodyMedium(context),
                          ),
                          if (_query.isEmpty) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: widget.onAddContacts,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add Contacts'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final contact = filtered[index];
                  final phone = contact.phoneNumber;
                  final selected = phone != null && _selected.contains(phone);

                  final bg = selected ? scheme.primaryContainer : scheme.surface;
                  final fg = selected ? scheme.onPrimaryContainer : AppColors.textPrimary;
                  final secondaryFg = selected ? scheme.onPrimaryContainer : AppColors.textSecondary;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
                      boxShadow: AppShadows.card,
                    ),
                    child: InkWell(
                      onTap: phone == null
                          ? null
                          : () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(phone);
                                } else {
                                  _selected.add(phone);
                                }
                              });
                            },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected ? scheme.primary : scheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (contact.name?.isNotEmpty ?? false) ? contact.name![0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ContactIdentityDetails(
                              name: contact.name ?? 'Unknown',
                              phoneNumber: contact.phoneNumber,
                              isVerified: contact.isRegistered,
                              nameStyle: AppTextStyles.titleMedium(context).copyWith(fontSize: 15, color: fg),
                              phoneStyle: AppTextStyles.bodySmall(context).copyWith(
                                fontSize: 12,
                                color: secondaryFg,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: selected ? scheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected ? scheme.primary : scheme.outlineVariant,
                                width: 1.5,
                              ),
                            ),
                            child: selected ? Icon(Icons.check, size: 16, color: scheme.onPrimary) : null,
                          ),
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
    );
  }
}
