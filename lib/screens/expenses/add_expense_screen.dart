import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_shadows.dart';
import '../../widgets/custom_button.dart';
import '../../models/contact_model.dart';
import '../../services/isar_service.dart';
import '../../services/expense_service.dart';
import '../../services/contact_service.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/money_utils.dart';
import '../../widgets/contact_identity_details.dart';
import '../contacts/contact_selection_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  final Map<String, ContactModel> _contactsByPhone = {};
  final List<String> _selectedParticipants = [];
  List<int> _recentAmountsPaise = [];

  bool _hasContacts = false;
  bool _loadingContacts = true;
  bool _submitting = false;
  StreamSubscription<int>? _expenseUpdatesSub;
  StreamSubscription<int>? _contactUpdatesSub;
  Future<void>? _contactsLoadInFlight;
  DateTime? _lastBalanceContactSyncAt;
  static const int _previewContactsPageSize = 40;

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
    return _contactsByPhone[phone];
  }

  Future<void> _openParticipantPicker() async {
    final picked = await showModalBottomSheet<List<ContactModel>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return _ParticipantPickerSheet(
          initiallySelected: _selectedParticipants,
          initiallySelectedContacts: _selectedParticipants
              .map((phone) => _contactsByPhone[phone])
              .whereType<ContactModel>()
              .toList(),
          onAddContacts: () async {
            Navigator.pop(ctx, null);
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactSelectionScreen()),
            );
            await _loadLocalContacts();
            if (mounted) _openParticipantPicker();
          },
        );
      },
    );

    if (!mounted || picked == null) return;
    final phones = <String>[];
    for (final contact in picked) {
      final phone = contact.phoneNumber;
      if (phone == null || phone.isEmpty) continue;
      _contactsByPhone[phone] = contact;
      phones.add(phone);
    }
    setState(() {
      _selectedParticipants
        ..clear()
        ..addAll(phones);
    });
  }

  Future<void> _loadLocalContacts({bool showLoader = true}) async {
    if (!mounted) return;
    if (_contactsLoadInFlight != null) {
      return _contactsLoadInFlight!;
    }
    if (showLoader) {
      setState(() => _loadingContacts = true);
    }

    final future = (() async {
      try {
        final previewContacts = await context.read<IsarService>().getContactsPage(
          offset: 0,
          limit: _previewContactsPageSize,
        );
        if (mounted) {
          setState(() {
            _hasContacts = previewContacts.isNotEmpty;
            for (final contact in previewContacts) {
              final phone = contact.phoneNumber;
              if (phone == null || phone.isEmpty) continue;
              _contactsByPhone[phone] = contact;
            }
          });
        }
      } catch (e) {
        developer.log('Load contacts error: $e');
      } finally {
        if (showLoader && mounted) {
          setState(() => _loadingContacts = false);
        }
      }
    })();
    _contactsLoadInFlight = future;
    await future;
    if (identical(_contactsLoadInFlight, future)) {
      _contactsLoadInFlight = null;
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

    if (!_hasContacts) {
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
  final List<String> initiallySelected;
  final List<ContactModel> initiallySelectedContacts;
  final VoidCallback onAddContacts;

  const _ParticipantPickerSheet({
    required this.initiallySelected,
    required this.initiallySelectedContacts,
    required this.onAddContacts,
  });

  @override
  State<_ParticipantPickerSheet> createState() => _ParticipantPickerSheetState();
}

class _ParticipantPickerSheetState extends State<_ParticipantPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, ContactModel> _selectedContactsByPhone = {};
  final List<ContactModel> _contacts = [];
  String _query = '';
  late final List<String> _selected = List<String>.from(widget.initiallySelected);
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadInProgress = false;
  bool _pendingResetAfterLoad = false;
  bool _hasMore = true;
  int _offset = 0;

  static const int _pageSize = 40;

  @override
  void initState() {
    super.initState();
    for (final contact in widget.initiallySelectedContacts) {
      final phone = contact.phoneNumber;
      if (phone != null && phone.isNotEmpty) {
        _selectedContactsByPhone[phone] = contact;
      }
    }
    _scrollController.addListener(_onScroll);
    unawaited(_loadContacts(reset: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      unawaited(_loadContacts());
    }
  }

  Future<void> _loadContacts({bool reset = false}) async {
    if (_loadInProgress) {
      if (reset) {
        _pendingResetAfterLoad = true;
        if (mounted) {
          setState(() => _loading = true);
        }
      }
      return;
    }
    final requestQuery = _query;
    final int nextOffset = reset ? 0 : _offset;
    if (!reset && !_hasMore) return;
    _loadInProgress = true;

    if (mounted) {
      setState(() {
        if (reset) {
          _loading = true;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final page = await context.read<IsarService>().getContactsPage(
        offset: nextOffset,
        limit: _pageSize,
        query: requestQuery,
      );
      if (!mounted) return;
      if (_pendingResetAfterLoad && !reset) return;
      if (requestQuery != _query) return;
      setState(() {
        if (reset) {
          _contacts
            ..clear()
            ..addAll(page);
        } else {
          _contacts.addAll(page);
        }
        _offset = nextOffset + page.length;
        _hasMore = page.length == _pageSize;
      });
    } finally {
      _loadInProgress = false;
      if (_pendingResetAfterLoad) {
        _pendingResetAfterLoad = false;
        if (mounted) {
          unawaited(_loadContacts(reset: true));
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _toggleSelection(ContactModel contact) {
    final phone = contact.phoneNumber;
    if (phone == null || phone.isEmpty) return;
    setState(() {
      if (_selected.contains(phone)) {
        _selected.remove(phone);
        _selectedContactsByPhone.remove(phone);
      } else {
        _selected.add(phone);
        _selectedContactsByPhone[phone] = contact;
      }
    });
  }

  List<ContactModel> _buildSelectionResult() {
    return _selected
        .map(
          (phone) => _selectedContactsByPhone[phone] ??
              _contacts.firstWhere(
                (contact) => contact.phoneNumber == phone,
                orElse: () => ContactModel(phoneNumber: phone, name: phone),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

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
                    onPressed: () => Navigator.pop(context, _buildSelectionResult()),
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
                            unawaited(_loadContacts(reset: true));
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (v) {
                  setState(() => _query = v);
                  unawaited(_loadContacts(reset: true));
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 48,
                                color: AppColors.textTertiary,
                              ),
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
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _contacts.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _contacts.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final contact = _contacts[index];
                            final phone = contact.phoneNumber;
                            final selected = phone != null && _selected.contains(phone);

                            final bg = selected ? scheme.primaryContainer : scheme.surface;
                            final fg = selected
                                ? scheme.onPrimaryContainer
                                : AppColors.textPrimary;
                            final secondaryFg = selected
                                ? scheme.onPrimaryContainer
                                : AppColors.textSecondary;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                ),
                                boxShadow: AppShadows.card,
                              ),
                              child: InkWell(
                                onTap: phone == null ? null : () => _toggleSelection(contact),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? scheme.primary
                                            : scheme.primaryContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (contact.name?.isNotEmpty ?? false)
                                              ? contact.name![0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: selected
                                                ? scheme.onPrimary
                                                : scheme.onPrimaryContainer,
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
                                        nameStyle: AppTextStyles.titleMedium(context)
                                            .copyWith(fontSize: 15, color: fg),
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
                                        color: selected
                                            ? scheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: selected
                                              ? scheme.primary
                                              : scheme.outlineVariant,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: selected
                                          ? Icon(
                                              Icons.check,
                                              size: 16,
                                              color: scheme.onPrimary,
                                            )
                                          : null,
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
