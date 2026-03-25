import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_currencies.dart';
import '../../constants/app_text_styles.dart';
import '../../models/contact_model.dart';
import '../../services/app_preferences_service.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../../constants/app_shadows.dart';
import '../../widgets/detail_dialog.dart';
import '../../widgets/shadowed_app_bar.dart';
import '../../widgets/loading_indicator.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/phone_utils.dart';
import '../../utils/custom_snackbar.dart';
import '../../widgets/contact_identity_details.dart';
import '../../widgets/app_dialog.dart';

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
    if (mounted) setState(() => _syncing = true);
    try {
      final contactId = await _ensureResolvedContactId();
      final expenseService = context.read<ExpenseService>();
      late final List<dynamic> localData;

      if (contactId != null && contactId.isNotEmpty) {
        final page = await expenseService.getTimeline(
          withUserId: contactId,
          forceRefresh: false,
        );
        localData = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      } else {
        localData = await expenseService.getConversationByPhone(
          widget.contact.phoneNumber ?? '',
          forceRefresh: false,
        );
      }

      final balances = await expenseService.getBalances(forceRefresh: false);
      final balance = _resolveContactBalance(balances);

      if (mounted) {
        setState(() {
          _transactions = localData;
          _balance = balance;
          _hasMore = _hasMore || localData.length >= 20;
          _syncing = false;
        });
      }
    } catch (e) {
      developer.log('Load local conversation error: $e');
      if (mounted) setState(() => _syncing = false);
    }

    _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    if (_serverSyncing) return;
    if (mounted) setState(() => _syncing = true);

    _serverSyncing = true;
    try {
      final contactId = await _ensureResolvedContactId();
      final expenseService = context.read<ExpenseService>();
      late final List<dynamic> serverData;

      if (contactId != null && contactId.isNotEmpty) {
        final page = await expenseService.getTimeline(
          withUserId: contactId,
          forceRefresh: true,
        );
        serverData = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      } else {
        serverData = await expenseService.getConversationByPhone(
          widget.contact.phoneNumber ?? '',
          forceRefresh: true,
        );
      }

      final balances = await expenseService.getBalances(forceRefresh: true);
      final balance = _resolveContactBalance(balances);

      if (mounted) {
        setState(() {
          _transactions = serverData;
          _balance = balance;
          _hasMore = _hasMore || serverData.length >= 20;
        });
      }
    } catch (e) {
      developer.log('Sync conversation error: $e');
    } finally {
      _serverSyncing = false;
      if (mounted) setState(() => _syncing = false);
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  String _canonicalPhone(String? value) => PhoneUtils.canonical(value);

Future<String?> _ensureResolvedContactId() async {
    final existing = widget.contact.contactId;
    if (existing != null && existing.isNotEmpty) return existing;

    final phone = widget.contact.phoneNumber;
    if (phone == null || phone.isEmpty) return null;

    final contactService = context.read<ContactService>();
    final resolved = await contactService.addContactByPhone(phone);
    if (resolved == null ||
        resolved.contactId == null ||
        resolved.contactId!.isEmpty) {
      return null;
    }

    widget.contact.contactId = resolved.contactId;
    widget.contact.isRegistered = resolved.isRegistered;
    if ((widget.contact.name == null || widget.contact.name!.trim().isEmpty) &&
        (resolved.name?.trim().isNotEmpty ?? false)) {
      widget.contact.name = resolved.name;
    }
    widget.contact.updatedAt = DateTime.now();

    final isar = context.read<IsarService>();
    await contactService.upsertContactsByCanonical(isar, [widget.contact]);
    contactService.notifyUpdate();
    if (mounted) setState(() {});
    return widget.contact.contactId;
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
      final contactId = await _ensureResolvedContactId();
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
        final existingKeys =
            _transactions.map(_timelineKey).whereType<String>().toSet();
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

  DateTime? _parseTimelineDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _formatSeenLabel(DateTime? seenAt) {
    if (seenAt == null) return 'Seen';
    final now = DateTime.now();
    final sameDay = now.year == seenAt.year &&
        now.month == seenAt.month &&
        now.day == seenAt.day;
    return sameDay
        ? 'Seen ${AppDateUtils.formatTime(seenAt)}'
        : 'Seen ${AppDateUtils.formatShortDate(seenAt)}';
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: title,
      message: message,
      icon: Icons.delete_outline_rounded,
      variant: DialogVariant.danger,
      confirmLabel: 'Delete',
    );
    return confirmed == true;
  }

  Future<void> _handleExpenseEdit({
    required String expenseId,
    required String description,
    required int totalAmount,
    required int participantsCount,
  }) async {
    // Warn if multiple participants
    if (participantsCount > 1) {
      final proceed = await AppConfirmDialog.show(
        context,
        title: 'Update for Everyone?',
        message: 'This expense is shared with $participantsCount people. Editing will update the amount for all of them.',
        icon: Icons.group_outlined,
        variant: DialogVariant.warning,
        confirmLabel: 'Continue',
      );
      if (proceed != true || !mounted) return;
    }
    final input = await _showEditExpenseDialog(
      currentDescription: description,
      currentTotalAmountPaise: totalAmount,
    );
    if (input == null || !mounted) return;

    try {
      await context.read<ExpenseService>().updateExpense(
            expenseId: expenseId,
            description: input['description'] as String,
            totalAmount: input['amountPaise'] as int,
          );
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Expense updated');
      await _syncFromServer();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to update expense',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleExpenseDelete(String expenseId, {required int participantsCount}) async {
    final message = participantsCount > 1
        ? 'This expense is shared with $participantsCount people. Deleting will remove it for all of them.'
        : 'Are you sure you want to delete this expense?';
    final confirmed = await _confirmDelete(
      title: 'Delete Expense',
      message: message,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ExpenseService>().deleteExpense(expenseId);
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Expense deleted');
      await _syncFromServer();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to delete expense',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleTransactionDelete(String transactionId) async {
    final confirmed = await _confirmDelete(
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete this transaction?',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ExpenseService>().deleteTransaction(transactionId);
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Transaction deleted');
      await _syncFromServer();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to delete transaction',
          isError: true,
        );
      }
    }
  }

  Future<void> _openEntryActions({
    required String type,
    required String? entryId,
    required bool canEditExpense,
    required bool canDeleteExpense,
    required bool canDeleteTransaction,
    required String description,
    required int totalAmount,
    required int participantsCount,
  }) async {
    if (entryId == null) return;

    final actions = <String>[
      if (canEditExpense) 'edit_expense',
      if (canDeleteExpense) 'delete_expense',
      if (canDeleteTransaction) 'delete_transaction',
    ];
    if (actions.isEmpty) return;

    if (actions.length == 1) {
      final onlyAction = actions.first;
      if (onlyAction == 'edit_expense') {
        await _handleExpenseEdit(
          expenseId: entryId,
          description: description,
          totalAmount: totalAmount,
          participantsCount: participantsCount,
        );
      } else if (onlyAction == 'delete_expense') {
        await _handleExpenseDelete(entryId, participantsCount: participantsCount);
      } else if (onlyAction == 'delete_transaction') {
        await _handleTransactionDelete(entryId);
      }
      return;
    }

    final action = await AppConfirmDialog.show(
      context,
      title: type == 'expense' ? 'Expense Options' : 'Transaction Options',
      icon: type == 'expense' ? Icons.receipt_long_outlined : Icons.payments_outlined,
      variant: DialogVariant.info,
      confirmLabel: canEditExpense ? 'Edit' : 'Delete',
      cancelLabel: canDeleteExpense || canDeleteTransaction ? 'Delete' : 'Cancel',
    ).then((v) {
      if (v == true) return canEditExpense ? 'edit_expense' : (canDeleteExpense ? 'delete_expense' : 'delete_transaction');
      if (v == false && (canDeleteExpense || canDeleteTransaction)) return canDeleteExpense ? 'delete_expense' : 'delete_transaction';
      return null;
    });

    if (!mounted || action == null) return;
    if (action == 'edit_expense') {
      await _handleExpenseEdit(
        expenseId: entryId,
        description: description,
        totalAmount: totalAmount,
        participantsCount: participantsCount,
      );
    } else if (action == 'delete_expense') {
      await _handleExpenseDelete(entryId, participantsCount: participantsCount);
    } else if (action == 'delete_transaction') {
      await _handleTransactionDelete(entryId);
    }
  }

  Future<Map<String, dynamic>?> _showEditExpenseDialog({
    required String currentDescription,
    required int currentTotalAmountPaise,
  }) async {
    final currencyCode = context.read<AppPreferencesService>().preferredCurrencyCode;
    final currency = AppCurrencies.byCode(currencyCode);
    final amountCtrl = TextEditingController(
      text: formatMinorUnitsValue(currentTotalAmountPaise, currencyCode: currencyCode),
    );
    final descCtrl = TextEditingController(text: currentDescription);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppFormDialog(
        title: 'Edit Expense',
        icon: Icons.edit_outlined,
        fields: [
          AppFormField(controller: descCtrl, label: 'Description', autofocus: true),
          AppFormField(
            controller: amountCtrl,
            label: 'Total Amount (${currency.code})',
            prefix: currency.symbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
        confirmLabel: 'Save',
        onConfirm: () {
          final v = parseAmountToMinorUnits(amountCtrl.text, currencyCode: currencyCode);
          if (v == null) return 'Enter a valid amount';
          return null;
        },
      ),
    );
    if (confirmed != true) return null;
    final amountPaise = parseAmountToMinorUnits(amountCtrl.text, currencyCode: currencyCode);
    if (amountPaise == null) return null;
    return {'amountPaise': amountPaise, 'description': descCtrl.text.trim()};
  }

  Future<Map<String, dynamic>?> _showEntryDialog({required bool isTransaction}) async {
    final currencyCode = context.read<AppPreferencesService>().preferredCurrencyCode;
    final currency = AppCurrencies.byCode(currencyCode);
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppFormDialog(
        title: isTransaction ? 'Add Transaction' : 'Add Expense',
        icon: isTransaction ? Icons.payments_outlined : Icons.receipt_long_outlined,
        accentColor: isTransaction ? AppColors.success : AppColors.primary,
        fields: [
          AppFormField(
            controller: amountCtrl,
            label: 'Amount (${currency.code})',
            hint: 'e.g. 300',
            prefix: currency.symbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          if (!isTransaction)
            AppFormField(
              controller: descCtrl,
              label: 'Description (Optional)',
              hint: 'Dinner / Grocery / Cab',
            ),
        ],
        confirmLabel: 'Save',
        onConfirm: () {
          final v = parseAmountToMinorUnits(amountCtrl.text, currencyCode: currencyCode);
          if (v == null) return 'Enter a valid amount';
          return null;
        },
      ),
    );
    if (confirmed != true) return null;
    final amountPaise = parseAmountToMinorUnits(amountCtrl.text, currencyCode: currencyCode);
    if (amountPaise == null) return null;
    return {'amountPaise': amountPaise, 'description': descCtrl.text.trim()};
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
        description: (description == null || description.isEmpty)
            ? 'Expense'
            : description,
        totalAmount: amount,
        participants: [phone],
      );
      await _syncFromServer();
    } catch (e) {
      developer.log('Add chat expense error: $e');
      if (mounted) {
        CustomSnackBar.show(context,
            message: 'Failed to add expense', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addTransactionFromChat() async {
    if (_submitting) return;
    final toUserId = await _ensureResolvedContactId();
    final toPhone = widget.contact.phoneNumber;

    if ((toUserId == null || toUserId.isEmpty) &&
        (toPhone == null || toPhone.isEmpty)) {
      CustomSnackBar.show(context,
          message: 'Contact phone number is missing', isError: true);
      return;
    }

    final input = await _showEntryDialog(isTransaction: true);
    if (input == null) return;

    if (mounted) setState(() => _submitting = true);
    try {
      final amount = (input['amountPaise'] as num).toInt();
      await context.read<ExpenseService>().createTransaction(
            toUserId:
                (toUserId != null && toUserId.isNotEmpty) ? toUserId : null,
            toPhone: (toUserId == null || toUserId.isEmpty) ? toPhone : null,
            amount: amount,
          );
      await _syncFromServer();
    } catch (e) {
      developer.log('Add chat transaction error: $e');
      if (mounted) {
        CustomSnackBar.show(context,
            message: 'Failed to add transaction', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferredCurrencyCode =
        context.watch<AppPreferencesService>().preferredCurrencyCode;
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
      resizeToAvoidBottomInset: false,
      appBar: ShadowedAppBar(
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          title: ContactIdentityDetails(
            name: widget.contact.name ?? 'User',
            phoneNumber: widget.contact.phoneNumber,
            isVerified: widget.contact.isRegistered,
            nameStyle: AppTextStyles.titleMedium(context).copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
            phoneStyle: AppTextStyles.bodySmall(context).copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.1),
                border: Border(
                  bottom:
                      BorderSide(color: balanceColor.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(balanceLabel, style: AppTextStyles.bodySmall(context)),
                  AppDimensions.h5(context),
                  Text(
                    formatMinorUnits(
                      _balance,
                      currencyCode: preferredCurrencyCode,
                    ),
                    style: AppTextStyles.currency(context)
                        .copyWith(color: balanceColor),
                  ),
                ],
              ),
            ),
            LoadingIndicator(isLoading: _syncing),
            Expanded(
              child: _transactions.isEmpty && _syncing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Loading conversation...',
                              style: AppTextStyles.bodyMedium(context)),
                        ],
                      ),
                    )
                  : _transactions.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _syncFromServer,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                  height: AppDimensions.height(context) * 0.2),
                              Center(
                                child: Text('No transactions yet',
                                    style: AppTextStyles.bodyMedium(context)),
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
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                    16, _loadingMore ? 56 : 16, 16, 16),
                                reverse: true,
                                itemCount: _transactions.length,
                                itemBuilder: (context, index) {
                                  final item = _transactions[index];
                                  final type = item['type'];
                                  final amount =
                                      (item['amount'] as num?)?.round() ?? 0;
                                  final totalAmount =
                                      (item['totalAmount'] as num?)?.round();
                                  final participants =
                                      (item['participants'] as num?)?.round() ??
                                          0;
                                  final description = item['description'] ?? '';
                                  final direction =
                                      item['direction'] as String? ?? '';
                                  final date = DateTime.parse(
                                      item['createdAt'] as String);
                                  final entryId = (item['expenseId'] ??
                                      item['id']) as String?;
                                  final createdBy =
                                      item['createdBy'] as String?;
                                  final isDeleted = item['isDeleted'] == true;
                                  final deletedBy = item['deletedBy'] as String?;
                                  final updatedBy = item['updatedBy'] as String?;
                                  final canEditExpense = type == 'expense' &&
                                      entryId != null &&
                                      createdBy == _currentUserId &&
                                      !isDeleted;
                                  final canDeleteExpense = canEditExpense;
                                  final canDeleteTransaction =
                                      type == 'transaction' &&
                                          entryId != null &&
                                          direction == 'sent';
                                  final canManageEntry = canEditExpense ||
                                      canDeleteExpense ||
                                      canDeleteTransaction;
                                  final isYouPaid = direction == 'you_paid' ||
                                      direction == 'sent';
                                  final seenByOther =
                                      item['seenByOther'] == true;
                                  final seenAt =
                                      _parseTimelineDate(item['seenAt']);
                                  final tagText = type == 'expense'
                                      ? 'Expense'
                                      : 'Transaction';

                                  return Align(
                                    alignment: isYouPaid
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: GestureDetector(
                                      onTap: () {
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
                                              value: formatMinorUnits(
                                                totalAmount,
                                                currencyCode:
                                                    preferredCurrencyCode,
                                              ),
                                              icon:
                                                  Icons.account_balance_wallet,
                                              valueColor: AppColors.primary,
                                            ));
                                          }
                                          items.add(DetailItem(
                                            label: 'Your Share',
                                            value: formatMinorUnits(
                                              amount,
                                              currencyCode:
                                                  preferredCurrencyCode,
                                            ),
                                            icon: Icons.person,
                                            valueColor: AppColors.primary,
                                          ));
                                          if (participants > 0) {
                                            items.add(DetailItem(
                                              label: 'Split Between',
                                              value:
                                                  '${participants + 1} ${participants + 1 == 1 ? "person" : "people"}',
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
                                            value: formatMinorUnits(
                                              amount,
                                              currencyCode:
                                                  preferredCurrencyCode,
                                            ),
                                            icon: Icons.payments,
                                            valueColor: isYouPaid
                                                ? AppColors.success
                                                : AppColors.info,
                                          ));
                                          items.add(DetailItem(
                                            label: 'Type',
                                            value: isYouPaid
                                                ? 'You paid'
                                                : 'You received',
                                            icon: isYouPaid
                                                ? Icons.call_made
                                                : Icons.call_received,
                                          ));
                                        }

                                        items.add(DetailItem(
                                          label: 'Date',
                                          value:
                                              AppDateUtils.formatDateTime(date),
                                          icon: Icons.calendar_today,
                                        ));

                                        showDialog(
                                          context: context,
                                          builder: (context) => DetailDialog(
                                            title: type == 'expense'
                                                ? 'Expense Details'
                                                : 'Transaction Details',
                                            items: items,
                                            accentColor: type == 'expense'
                                                ? AppColors.primary
                                                : (isYouPaid
                                                    ? AppColors.success
                                                    : AppColors.info),
                                          ),
                                        );
                                      },
                                      onLongPress: canManageEntry
                                          ? () => _openEntryActions(
                                                type: type,
                                                entryId: entryId,
                                                canEditExpense: canEditExpense,
                                                canDeleteExpense: canDeleteExpense,
                                                canDeleteTransaction: canDeleteTransaction,
                                                description: description,
                                                totalAmount: totalAmount ?? amount,
                                                participantsCount: participants,
                                              )
                                          : null,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.75),
                                        decoration: BoxDecoration(
                                          color: isDeleted
                                              ? AppColors.error.withValues(alpha: 0.04)
                                              : Theme.of(context).colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDeleted
                                                ? AppColors.error.withValues(alpha: 0.25)
                                                : AppColors.border,
                                            width: 1,
                                          ),
                                          boxShadow: AppShadows.card,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: (type == 'expense'
                                                        ? AppColors.primary
                                                        : (isYouPaid
                                                            ? AppColors.success
                                                            : AppColors.info))
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(11),
                                                  topRight: Radius.circular(11),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      type == 'expense'
                                                          ? Icons.receipt_long
                                                          : Icons.payments,
                                                      size: 12,
                                                      color: type == 'expense'
                                                          ? AppColors.primary
                                                          : (isYouPaid
                                                              ? AppColors
                                                                  .success
                                                              : AppColors
                                                                  .info)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    tagText,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: type == 'expense'
                                                          ? AppColors.primary
                                                          : (isYouPaid
                                                              ? AppColors
                                                                  .success
                                                              : AppColors.info),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (canManageEntry)
                                                    PopupMenuButton<String>(
                                                      tooltip: 'Options',
                                                      padding: EdgeInsets.zero,
                                                      onSelected:
                                                          (value) async {
                                                        final selectedEntryId =
                                                            entryId;
                                                        if (value == 'edit_expense') {
                                                          await _handleExpenseEdit(
                                                            expenseId: selectedEntryId,
                                                            description: description,
                                                            totalAmount: totalAmount ?? amount,
                                                            participantsCount: participants,
                                                          );
                                                        } else if (value == 'delete_expense') {
                                                          await _handleExpenseDelete(selectedEntryId, participantsCount: participants);
                                                        } else if (value ==
                                                            'delete_transaction') {
                                                          await _handleTransactionDelete(
                                                              selectedEntryId);
                                                        }
                                                      },
                                                      itemBuilder: (context) =>
                                                          [
                                                        if (canEditExpense)
                                                          const PopupMenuItem<
                                                              String>(
                                                            value:
                                                                'edit_expense',
                                                            child: Text('Edit'),
                                                          ),
                                                        if (canDeleteExpense)
                                                          const PopupMenuItem<
                                                              String>(
                                                            value:
                                                                'delete_expense',
                                                            child:
                                                                Text('Delete'),
                                                          ),
                                                        if (canDeleteTransaction)
                                                          const PopupMenuItem<
                                                              String>(
                                                            value:
                                                                'delete_transaction',
                                                            child:
                                                                Text('Delete'),
                                                          ),
                                                      ],
                                                      child: const Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 4),
                                                        child: Icon(
                                                          Icons.more_vert,
                                                          size: 16,
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  Text(
                                                    AppDateUtils
                                                        .formatDate(date),
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (description
                                                      .isNotEmpty) ...[
                                                    Text(
                                                      description,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                        decoration: isDeleted
                                                            ? TextDecoration.lineThrough
                                                            : null,
                                                        color: isDeleted
                                                            ? AppColors.textSecondary
                                                            : null,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 5),
                                                  ],
                                                  Text(
                                                    formatMinorUnits(
                                                      amount,
                                                      currencyCode:
                                                          preferredCurrencyCode,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDeleted
                                                          ? AppColors.textSecondary
                                                          : AppColors.textPrimary,
                                                      decoration: isDeleted
                                                          ? TextDecoration.lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                  if (isDeleted) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.delete_outline, size: 11, color: AppColors.error),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          deletedBy != null
                                                              ? 'Deleted by $deletedBy'
                                                              : 'Deleted',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors.error,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ] else if (updatedBy != null) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.edit_outlined, size: 11, color: AppColors.textSecondary),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          'Edited by $updatedBy',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors.textSecondary,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ] else if (isYouPaid && seenByOther) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _formatSeenLabel(seenAt),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
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
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
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
                padding: EdgeInsets.fromLTRB(12, 8, 12,
                    12 + MediaQuery.of(context).viewInsets.bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_syncing || _submitting)
                            ? null
                            : _addExpenseFromChat,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Add Expense'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_syncing || _submitting)
                            ? null
                            : _addTransactionFromChat,
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
      ),
    );
  }
}
