import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_currencies.dart';
import '../../constants/app_text_styles.dart';
import '../../bloc/contact_provider.dart';
import '../../models/contact_model.dart';
import '../../services/app_preferences_service.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../../constants/app_shadows.dart';
import '../../widgets/detail_dialog.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/loading_indicator.dart';
import '../../utils/money_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/phone_utils.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/network_error_handler.dart';
import '../../services/interstitial_ad_service.dart';
import '../../widgets/app_dialog.dart';
import '../../constants/app_info.dart';
import 'package:share_plus/share_plus.dart';
import 'contact_details_screen.dart';

class ConversationScreen extends StatefulWidget {
  final ContactModel contact;

  const ConversationScreen({super.key, required this.contact});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<dynamic> _transactions = [];
  bool _initialLoading = true;
  bool _syncing = false;
  bool _serverSyncing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  int _balance = 0;
  String? _currentUserId;
  late final InterstitialAdService _interstitialAd;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<int>? _updatesSub;

  @override
  void initState() {
    super.initState();
    _interstitialAd = context.read<InterstitialAdService>();
    _loadCurrentUserId();
    _scrollController.addListener(_onScroll);
    _updatesSub = context.read<ExpenseService>().updates.listen((_) {
      if (mounted) _syncFromServer();
    });
    _loadLocalFirst();
  }

  Future<void> _loadLocalFirst() async {
    try {
      final expenseService = context.read<ExpenseService>();
      final contactId = widget.contact.contactId;

      final timelineFuture = (contactId != null && contactId.isNotEmpty)
          ? expenseService.getTimeline(
              withUserId: contactId,
              withUserPhone: widget.contact.phoneNumber,
              forceRefresh: false,
            )
          : expenseService.getConversationByPhone(
              widget.contact.phoneNumber ?? '',
              forceRefresh: false,
            );

      final balancesFuture = expenseService.getBalances(forceRefresh: false);

      final results = await Future.wait([timelineFuture, balancesFuture]);
      final timelineResult = results[0];
      final balancesResult = results[1] as Map<String, dynamic>;

      final List<dynamic> localData;
      if (timelineResult is TimelinePage) {
        localData = timelineResult.items;
        _nextCursor = timelineResult.nextCursor;
        _hasMore = timelineResult.hasMore;
      } else if (timelineResult is List<dynamic>) {
        localData = timelineResult;
      } else {
        localData = const [];
      }

      final sanitizedLocalData = localData.map((e) {
        if (e is Map && e['status'] == 'syncing') {
          final created = DateTime.tryParse(e['createdAt']?.toString() ?? '');
          if (created != null &&
              DateTime.now().toUtc().difference(created).inSeconds > 30) {
            final copy = Map<String, dynamic>.from(e);
            copy['status'] = 'failed';
            return copy;
          }
        }
        return e;
      }).toList();

      final balance = _resolveContactBalance(balancesResult);

      if (mounted) {
        setState(() {
          _transactions = sanitizedLocalData;
          _balance = balance;
          _hasMore = _hasMore || localData.length >= 20;
          _initialLoading = false;
          _syncing = false;
        });
      }
    } catch (e) {
      developer.log('Load local conversation error: $e');
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _syncing = false;
        });
      }
    }

    // Trigger background silent synchronization
    _syncFromServer();
  }

  List<dynamic> _mergeServerDataWithOptimistic(List<dynamic> serverItems) {
    final serverIds = <String>{};
    for (final item in serverItems) {
      if (item is Map) {
        final id = (item['id'] ??
                item['_id'] ??
                item['expenseId'] ??
                item['transactionId'])
            ?.toString();
        if (id != null && id.isNotEmpty) serverIds.add(id);
        final clientUuid = item['clientUuid']?.toString();
        if (clientUuid != null && clientUuid.isNotEmpty) {
          serverIds.add(clientUuid);
        }
      }
    }

    final pendingItems = <dynamic>[];
    for (final e in _transactions) {
      if (e is! Map) continue;
      final id = (e['id'] ??
              e['_id'] ??
              e['expenseId'] ??
              e['transactionId'])
          ?.toString() ??
          '';
      final clientUuid = e['clientUuid']?.toString() ?? '';

      // Direct ID match against server list
      if (id.isNotEmpty && serverIds.contains(id)) continue;
      if (clientUuid.isNotEmpty && serverIds.contains(clientUuid)) continue;

      final status = e['status']?.toString();
      final isTemp = clientUuid.startsWith('temp_') || id.startsWith('temp_');

      if (!isTemp && status != 'syncing' && status != 'failed') {
        continue;
      }

      // Check if server already includes this entry (fuzzy content/time matching)
      final eType = e['type']?.toString();
      final eDir = e['direction']?.toString();
      final eAmt = (e['totalAmount'] ?? e['amount']) as num?;
      final eCreated = DateTime.tryParse(e['createdAt']?.toString() ?? '');

      final alreadyOnServer = serverItems.any((s) {
        if (s is! Map) return false;
        final sType = s['type']?.toString();
        final sDir = s['direction']?.toString();
        final sAmt = (s['totalAmount'] ?? s['amount']) as num?;
        if (sType != eType || sDir != eDir || sAmt != eAmt) return false;

        if (eCreated != null) {
          final sCreated = DateTime.tryParse(s['createdAt']?.toString() ?? '');
          if (sCreated != null) {
            final diff = sCreated.difference(eCreated).abs();
            if (diff.inMinutes <= 5) return true;
          }
        }
        return false;
      });

      if (alreadyOnServer) {
        // Entry already acknowledged and present in server data
        continue;
      }

      if (status == 'syncing') {
        if (eCreated != null &&
            DateTime.now().toUtc().difference(eCreated).inSeconds > 30) {
          final copy = Map<String, dynamic>.from(e);
          copy['status'] = 'failed';
          pendingItems.add(copy);
        } else {
          pendingItems.add(e);
        }
      } else if (status == 'failed') {
        pendingItems.add(e);
      } else if (isTemp) {
        if (eCreated != null &&
            DateTime.now().toUtc().difference(eCreated).inSeconds < 30) {
          pendingItems.add(e);
        }
      }
    }

    return [...pendingItems, ...serverItems];
  }

  String _itemIdentifier(dynamic item) {
    if (item is! Map<String, dynamic>) return '';
    return (item['clientUuid'] ??
            item['id'] ??
            item['expenseId'] ??
            item['transactionId'] ??
            '')
        .toString();
  }

  Future<void> _syncFromServer() async {
    if (_serverSyncing) return;
    if (_transactions.isEmpty && mounted) setState(() => _syncing = true);

    _serverSyncing = true;
    try {
      final expenseService = context.read<ExpenseService>();
      final contactId = await _ensureResolvedContactId();
      late final List<dynamic> serverData;

      if (contactId != null && contactId.isNotEmpty) {
        final page = await expenseService.getTimeline(
          withUserId: contactId,
          withUserPhone: widget.contact.phoneNumber,
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
          _transactions = _mergeServerDataWithOptimistic(serverData);
          _balance = balance;
          _hasMore = _hasMore || serverData.length >= 20;
        });
      }
    } catch (e) {
      developer.log('Sync conversation error: $e');
    } finally {
      _serverSyncing = false;
      if (mounted) {
        setState(() {
          _syncing = false;
          _initialLoading = false;
        });
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
    final isar = context.read<IsarService>();
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
      final expenseService = context.read<ExpenseService>();
      final contactId = await _ensureResolvedContactId();
      if (contactId == null || contactId.isEmpty) return;
      final page = await expenseService.getTimeline(
        withUserId: contactId,
        withUserPhone: widget.contact.phoneNumber,
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
    if (sameDay) return 'Seen today at ${AppDateUtils.formatTime(seenAt)}';
    return 'Seen on ${AppDateUtils.formatDate(seenAt)}';
  }

  Color _entryAccentColor(String type, String direction) {
    if (type == 'expense') return AppColors.primary;
    return direction == 'sent' ? AppColors.success : AppColors.info;
  }

  Widget _buildBubblePill({
    required IconData icon,
    required String label,
    required Color color,
    bool shrink = false,
  }) {
    return Container(
      constraints: shrink ? const BoxConstraints(maxWidth: 160) : null,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
    final expenseService = context.read<ExpenseService>();
    final overlay = Overlay.of(context);
    // Warn if multiple participants
    if (participantsCount > 1) {
      final proceed = await AppConfirmDialog.show(
        context,
        title: 'Update for Everyone?',
        message:
            'This expense is shared with $participantsCount people. Editing will update the amount for all of them.',
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
      await expenseService.updateExpense(
        expenseId: expenseId,
        description: input['description'] as String,
        totalAmount: input['amountPaise'] as int,
      );
      if (!mounted) return;
      CustomSnackBar.showOnOverlay(overlay, message: 'Expense updated');
      await _syncFromServer();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showOnOverlay(
        overlay,
        message: NetworkErrorHandler.moneyWrite(),
        isError: true,
      );
    }
  }

  Future<void> _handleExpenseDelete(String expenseId,
      {required int participantsCount}) async {
    final expenseService = context.read<ExpenseService>();
    final overlay = Overlay.of(context);
    final message = participantsCount > 1
        ? 'This expense is shared with $participantsCount people. Deleting will remove it for all of them.'
        : 'Are you sure you want to delete this expense?';
    final confirmed = await _confirmDelete(
      title: 'Delete Expense',
      message: message,
    );
    if (!confirmed || !mounted) return;

    try {
      await expenseService.deleteExpense(expenseId);
      if (!mounted) return;
      CustomSnackBar.showOnOverlay(overlay, message: 'Expense deleted');
      await _syncFromServer();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showOnOverlay(
        overlay,
        message: NetworkErrorHandler.moneyWrite(),
        isError: true,
      );
    }
  }

  Future<void> _handleTransactionDelete(String transactionId) async {
    final expenseService = context.read<ExpenseService>();
    final overlay = Overlay.of(context);
    final confirmed = await _confirmDelete(
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete this transaction?',
    );
    if (!confirmed || !mounted) return;

    try {
      await expenseService.deleteTransaction(transactionId);
      if (!mounted) return;
      CustomSnackBar.showOnOverlay(overlay, message: 'Transaction deleted');
      await _syncFromServer();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showOnOverlay(
        overlay,
        message: NetworkErrorHandler.moneyWrite(),
        isError: true,
      );
    }
  }

  void _shareEntry(Map<String, dynamic> item, String currencyCode) {
    final type = item['type'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final amount = (item['amount'] as num?)?.round() ?? 0;
    final totalAmount = (item['totalAmount'] as num?)?.round();
    final direction = item['direction'] as String? ?? '';
    final date = DateTime.parse(item['createdAt'] as String);
    final contactName = widget.contact.name ?? 'Contact';
    final isYouPaid = direction == 'you_paid' || direction == 'sent';

    String text;
    if (type == 'expense') {
      text = '🧾 Expense with $contactName\n'
          '${description.isNotEmpty ? '$description\n' : ''}Your share: ${formatMinorUnits(amount, currencyCode: currencyCode)}'
          '${totalAmount != null ? '\nTotal: ${formatMinorUnits(totalAmount, currencyCode: currencyCode)}' : ''}\n'
          '📅 ${AppDateUtils.formatDateTime(date)}';
    } else {
      text = '💸 Payment with $contactName\n'
          '${description.isNotEmpty ? '$description\n' : ''}'
          '${isYouPaid ? 'You paid' : 'You received'}: ${formatMinorUnits(amount, currencyCode: currencyCode)}\n'
          '📅 ${AppDateUtils.formatDateTime(date)}';
    }
    Share.share('$text\n\n${AppInfo.inviteMessage}');
  }

  Future<void> _shareAll(String currencyCode) async {
    final contactName = widget.contact.name ?? 'Contact';
    final expenseService = context.read<ExpenseService>();

    List<dynamic> allItems = _transactions;
    try {
      final contactId = await _ensureResolvedContactId();
      if (contactId != null && contactId.isNotEmpty) {
        final page = await expenseService.getTimeline(
          withUserId: contactId,
          withUserPhone: widget.contact.phoneNumber,
          forceRefresh: true,
          limit: 9999,
        );
        allItems = page.items;
      }
    } catch (_) {
      // fallback to loaded items
    }

    final buffer = StringBuffer();
    buffer.writeln('📊 Expense Summary with $contactName');
    buffer.writeln(
        'Balance: ${formatMinorUnits(_balance, currencyCode: currencyCode)}');
    buffer.writeln('─────────────────');

    for (final item in allItems.reversed) {
      final type = item['type'] as String? ?? '';
      final description = item['description'] as String? ?? '';
      final amount = (item['amount'] as num?)?.round() ?? 0;
      final direction = item['direction'] as String? ?? '';
      final date = DateTime.parse(item['createdAt'] as String);
      final isYouPaid = direction == 'you_paid' || direction == 'sent';
      final icon = type == 'expense' ? '🧾' : (isYouPaid ? '💸' : '💰');
      buffer.writeln(
        '$icon ${AppDateUtils.formatDate(date)} · ${formatMinorUnits(amount, currencyCode: currencyCode)}'
        '${description.isNotEmpty ? ' · $description' : ''}',
      );
    }
    Share.share('${buffer.toString()}\n\n${AppInfo.inviteMessage}');
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
        await _handleExpenseDelete(entryId,
            participantsCount: participantsCount);
      } else if (onlyAction == 'delete_transaction') {
        await _handleTransactionDelete(entryId);
      }
      return;
    }

    final action = await AppConfirmDialog.show(
      context,
      title: type == 'expense' ? 'Expense Options' : 'Transaction Options',
      icon: type == 'expense'
          ? Icons.receipt_long_outlined
          : Icons.payments_outlined,
      variant: DialogVariant.info,
      confirmLabel: canEditExpense ? 'Edit' : 'Delete',
      cancelLabel:
          canDeleteExpense || canDeleteTransaction ? 'Delete' : 'Cancel',
    ).then((v) {
      if (v == true) {
        return canEditExpense
            ? 'edit_expense'
            : (canDeleteExpense ? 'delete_expense' : 'delete_transaction');
      }
      if (v == false && (canDeleteExpense || canDeleteTransaction)) {
        return canDeleteExpense ? 'delete_expense' : 'delete_transaction';
      }
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
    final currencyCode =
        context.read<AppPreferencesService>().preferredCurrencyCode;
    final currency = AppCurrencies.byCode(currencyCode);
    final amountCtrl = TextEditingController(
      text: formatMinorUnitsValue(currentTotalAmountPaise,
          currencyCode: currencyCode),
    );
    final descCtrl = TextEditingController(text: currentDescription);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppFormDialog(
        title: 'Edit Expense',
        icon: Icons.edit_outlined,
        fields: [
          AppFormField(
              controller: descCtrl, label: 'Description', autofocus: true),
          AppFormField(
            controller: amountCtrl,
            label: 'Total Amount (${currency.code})',
            prefix: currency.symbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
        confirmLabel: 'Save',
        onConfirm: () {
          final v = parseAmountToMinorUnits(amountCtrl.text,
              currencyCode: currencyCode);
          if (v == null) return 'Enter a valid amount';
          return null;
        },
      ),
    );
    if (confirmed != true) return null;
    final amountPaise =
        parseAmountToMinorUnits(amountCtrl.text, currencyCode: currencyCode);
    if (amountPaise == null) return null;
    return {'amountPaise': amountPaise, 'description': descCtrl.text.trim()};
  }

  Future<Map<String, dynamic>?> _showEntryDialog({
    required bool isTransaction,
  }) async {
    final currencyCode =
        context.read<AppPreferencesService>().preferredCurrencyCode;
    final currency = AppCurrencies.byCode(currencyCode);
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String direction = isTransaction ? 'sent' : 'you_paid';
    final contactName = widget.contact.name ?? 'Contact';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isSentOrYouPaid = isTransaction
              ? direction == 'sent'
              : direction == 'you_paid';
          final primaryAccent = isTransaction
              ? (direction == 'sent' ? AppColors.error : AppColors.success)
              : AppColors.primary;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isTransaction
                              ? Icons.payments_outlined
                              : Icons.receipt_long_outlined,
                          color: primaryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isTransaction ? 'Record Payment' : 'Add Expense',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2-Pill Segmented Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() {
                              direction = isTransaction ? 'sent' : 'you_paid';
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSentOrYouPaid ? primaryAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSentOrYouPaid
                                    ? [
                                        BoxShadow(
                                          color: primaryAccent.withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                isTransaction ? '🔴 I Sent' : '🔴 You Paid',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSentOrYouPaid
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() {
                              direction = isTransaction ? 'received' : 'they_paid';
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isSentOrYouPaid ? primaryAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: !isSentOrYouPaid
                                    ? [
                                        BoxShadow(
                                          color: primaryAccent.withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                isTransaction ? '🟢 I Received' : '🔵 $contactName Paid',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: !isSentOrYouPaid
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Field
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Amount (${currency.code})',
                      hintText: 'e.g. 500',
                      prefixText: '${currency.symbol} ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryAccent, width: 1.5),
                      ),
                    ),
                  ),

                  if (!isTransaction) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Dinner / Grocery / Cab',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            final amountPaise = parseAmountToMinorUnits(
                              amountCtrl.text,
                              currencyCode: currencyCode,
                            );
                            if (amountPaise == null || amountPaise <= 0) {
                              return;
                            }
                            Navigator.pop(ctx, {
                              'amountPaise': amountPaise,
                              'description': descCtrl.text.trim(),
                              'direction': direction,
                            });
                          },
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addExpenseFromChat() async {
    final phone = widget.contact.phoneNumber;
    final overlay = Overlay.of(context);
    final expenseService = context.read<ExpenseService>();
    final contactService = context.read<ContactService>();
    final isar = context.read<IsarService>();
    if (phone == null || phone.isEmpty) {
      CustomSnackBar.showOnOverlay(
        overlay,
        message: 'This contact has no phone number.',
        isError: true,
      );
      return;
    }

    final input = await _showEntryDialog(isTransaction: false);
    if (input == null) return;

    final amount = (input['amountPaise'] as num).toInt();
    final direction = (input['direction'] as String?) ?? 'you_paid';
    final isYouPaid = direction == 'you_paid';
    final rawDesc = (input['description'] as String?)?.trim();
    final description = (rawDesc == null || rawDesc.isEmpty) ? 'Expense' : rawDesc;
    final clientUuid = 'temp_${DateTime.now().microsecondsSinceEpoch}';

    final yourShare = amount ~/ 2;
    final signedAmount = isYouPaid ? (amount - yourShare) : -yourShare;

    final optimisticItem = <String, dynamic>{
      'id': clientUuid,
      'clientUuid': clientUuid,
      'expenseId': clientUuid,
      'type': 'expense',
      'amount': yourShare,
      'totalAmount': amount,
      'signedAmount': signedAmount,
      'direction': direction,
      'description': description,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'syncing',
      'createdBy': isYouPaid ? _currentUserId : (widget.contact.contactId ?? phone),
      'addedBy': 'you',
      'addedById': _currentUserId,
      'participantPhones': [phone],
      'participants': 1,
    };

    final contactKey =
        (widget.contact.contactId ?? widget.contact.phoneNumber ?? '').trim();

    if (mounted) {
      setState(() {
        _transactions = [optimisticItem, ..._transactions];
        _balance += signedAmount;
      });
    }

    unawaited(isar
        .touchContactActivity(phone, contactId: widget.contact.contactId)
        .then((_) => contactService.notifyUpdate()));

    unawaited(
        expenseService.saveOptimisticTimelineItem(contactKey, optimisticItem));

    // Detached background synchronization
    unawaited(() async {
      try {
        final model = await expenseService.createExpense(
          description: description,
          totalAmount: amount,
          participants: [phone],
          payerPhone: isYouPaid ? null : phone,
        );
        if (mounted) {
          setState(() {
            final idx = _transactions
                .indexWhere((e) => _itemIdentifier(e) == clientUuid);
            if (idx != -1) {
              final updated =
                  Map<String, dynamic>.from(_transactions[idx] as Map);
              updated['status'] = 'synced';
              updated['expenseId'] = model.uuid;
              updated['id'] = model.uuid;
              _transactions[idx] = updated;
            }
          });
        }
        _interstitialAd.onExpenseAdded();
        await _syncFromServer();
      } catch (e) {
        developer.log('Detached expense sync error: $e');
        if (mounted) {
          setState(() {
            final idx = _transactions
                .indexWhere((e) => _itemIdentifier(e) == clientUuid);
            if (idx != -1) {
              final updated =
                  Map<String, dynamic>.from(_transactions[idx] as Map);
              updated['status'] = 'failed';
              _transactions[idx] = updated;
            }
          });
          CustomSnackBar.showOnOverlay(
            overlay,
            message: 'Could not sync expense with server. Tap entry to retry.',
            isError: true,
          );
        }
      }
    }());
  }

  Future<void> _addTransactionFromChat() async {
    final overlay = Overlay.of(context);
    final expenseService = context.read<ExpenseService>();
    final contactService = context.read<ContactService>();
    final isar = context.read<IsarService>();
    final resolvedId = await _ensureResolvedContactId();
    final toPhone = widget.contact.phoneNumber;

    final isUuid = resolvedId != null &&
        resolvedId.isNotEmpty &&
        !resolvedId.startsWith('+') &&
        RegExp(r'^[0-9a-f-]{36}$').hasMatch(resolvedId);

    final toUserId = isUuid ? resolvedId : null;
    final effectivePhone = !isUuid ? (toPhone ?? resolvedId) : null;

    if (toUserId == null &&
        (effectivePhone == null || effectivePhone.isEmpty)) {
      CustomSnackBar.showOnOverlay(overlay,
          message: 'Contact phone number is missing', isError: true);
      return;
    }

    final input = await _showEntryDialog(isTransaction: true);
    if (input == null) return;

    final amount = (input['amountPaise'] as num).toInt();
    final direction = (input['direction'] as String?) ?? 'sent';
    final isReceived = direction == 'received';
    final signedAmount = isReceived ? -amount : amount;
    final clientUuid = 'temp_${DateTime.now().microsecondsSinceEpoch}';

    final optimisticItem = <String, dynamic>{
      'id': clientUuid,
      'clientUuid': clientUuid,
      'transactionId': clientUuid,
      'type': 'transaction',
      'amount': amount,
      'signedAmount': signedAmount,
      'direction': direction,
      'description': isReceived ? 'Received payment' : 'Sent payment',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'syncing',
      'addedBy': 'you',
      'addedById': _currentUserId,
      'counterparty': {
        if (toUserId != null) '_id': toUserId,
        if (effectivePhone != null) 'phoneNumber': effectivePhone,
      },
    };

    final contactKey =
        (widget.contact.contactId ?? widget.contact.phoneNumber ?? '').trim();

    if (mounted) {
      setState(() {
        _transactions = [optimisticItem, ..._transactions];
        _balance += signedAmount;
      });
    }

    unawaited(isar
        .touchContactActivity(effectivePhone, contactId: toUserId)
        .then((_) => contactService.notifyUpdate()));

    unawaited(
        expenseService.saveOptimisticTimelineItem(contactKey, optimisticItem));

    // Detached background synchronization
    unawaited(() async {
      try {
        developer.log(
            '[ConversationScreen] createTransaction toUserId=$toUserId toPhone=$effectivePhone amount=$amount isReceived=$isReceived');
        await expenseService.createTransaction(
          toUserId: toUserId,
          toPhone: effectivePhone,
          amount: amount,
          isReceived: isReceived,
        );
        if (mounted) {
          setState(() {
            final idx = _transactions
                .indexWhere((e) => _itemIdentifier(e) == clientUuid);
            if (idx != -1) {
              final updated =
                  Map<String, dynamic>.from(_transactions[idx] as Map);
              updated['status'] = 'synced';
              _transactions[idx] = updated;
            }
          });
        }
        _interstitialAd.onExpenseAdded();
        await _syncFromServer();
      } catch (e) {
        developer.log('Detached transaction sync error: $e');
        if (mounted) {
          setState(() {
            final idx = _transactions
                .indexWhere((e) => _itemIdentifier(e) == clientUuid);
            if (idx != -1) {
              final updated =
                  Map<String, dynamic>.from(_transactions[idx] as Map);
              updated['status'] = 'failed';
              _transactions[idx] = updated;
            }
          });
          CustomSnackBar.showOnOverlay(
            overlay,
            message:
                'Could not sync transaction with server. Tap entry to retry.',
            isError: true,
          );
        }
      }
    }());
  }

  Future<void> _retryFailedItem(Map<String, dynamic> item) async {
    final clientUuid = _itemIdentifier(item);
    final type = item['type']?.toString();
    if (clientUuid.isEmpty) return;

    if (mounted) {
      setState(() {
        final idx =
            _transactions.indexWhere((e) => _itemIdentifier(e) == clientUuid);
        if (idx != -1) {
          final updated = Map<String, dynamic>.from(_transactions[idx] as Map);
          updated['status'] = 'syncing';
          _transactions[idx] = updated;
        }
      });
    }

    final expenseService = context.read<ExpenseService>();
    final overlay = Overlay.of(context);

    try {
      if (type == 'expense') {
        final totalAmount = (item['totalAmount'] as num?)?.toInt() ??
            ((item['amount'] as num?)?.toInt() ?? 0) * 2;
        final desc = item['description']?.toString() ?? 'Expense';
        final phone = widget.contact.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          final model = await expenseService.createExpense(
            description: desc,
            totalAmount: totalAmount,
            participants: [phone],
          );
          if (mounted) {
            setState(() {
              final idx = _transactions
                  .indexWhere((e) => _itemIdentifier(e) == clientUuid);
              if (idx != -1) {
                final updated =
                    Map<String, dynamic>.from(_transactions[idx] as Map);
                updated['status'] = 'synced';
                updated['expenseId'] = model.uuid;
                updated['id'] = model.uuid;
                _transactions[idx] = updated;
              }
            });
          }
        }
      } else if (type == 'transaction') {
        final amount = (item['amount'] as num?)?.toInt() ?? 0;
        final resolvedId = await _ensureResolvedContactId();
        final toPhone = widget.contact.phoneNumber;
        final isUuid = resolvedId != null &&
            resolvedId.isNotEmpty &&
            !resolvedId.startsWith('+') &&
            RegExp(r'^[0-9a-f-]{36}$').hasMatch(resolvedId);
        final toUserId = isUuid ? resolvedId : null;
        final effectivePhone = !isUuid ? (toPhone ?? resolvedId) : null;

        final isReceived = item['direction'] == 'received';
        await expenseService.createTransaction(
          toUserId: toUserId,
          toPhone: effectivePhone,
          amount: amount,
          isReceived: isReceived,
        );
        if (mounted) {
          setState(() {
            final idx = _transactions
                .indexWhere((e) => _itemIdentifier(e) == clientUuid);
            if (idx != -1) {
              final updated =
                  Map<String, dynamic>.from(_transactions[idx] as Map);
              updated['status'] = 'synced';
              _transactions[idx] = updated;
            }
          });
        }
      }
      _interstitialAd.onExpenseAdded();
      await _syncFromServer();
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx =
              _transactions.indexWhere((e) => _itemIdentifier(e) == clientUuid);
          if (idx != -1) {
            final updated =
                Map<String, dynamic>.from(_transactions[idx] as Map);
            updated['status'] = 'failed';
            _transactions[idx] = updated;
          }
        });
        CustomSnackBar.showOnOverlay(
          overlay,
          message: 'Retry failed: ${NetworkErrorHandler.message(e)}',
          isError: true,
        );
      }
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: false,
      appBar: GradientAppBar(
        title: widget.contact.name ?? 'Conversation',
        onTitleTap: () async {
          final nav = Navigator.of(context);
          final deleted = await nav.push<bool>(
            MaterialPageRoute(
              builder: (_) => ContactDetailsScreen(
                contact: widget.contact,
                balance: _balance,
                transactionCount: _transactions.length,
              ),
            ),
          );
          if (deleted == true && mounted) {
            nav.pop();
          }
        },
        actions: [
          if (_transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(38, 38),
                ),
                icon: const Icon(
                  Icons.share_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                tooltip: 'Share all',
                onPressed: () => _shareAll(
                  context.read<AppPreferencesService>().preferredCurrencyCode,
                ),
              ),
            ),
        ],
      ),
      body: Column(
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
          LoadingIndicator(isLoading: _syncing && _transactions.isNotEmpty),
          Expanded(
            child: (_initialLoading && _transactions.isEmpty)
                ? _buildSkeletonLoading(context)
                : _transactions.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _syncFromServer,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                                height: AppDimensions.height(context) * 0.2),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 48,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No transactions yet',
                                    style: AppTextStyles.titleMedium(context),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add an expense or payment to get started',
                                    style: AppTextStyles.bodySmall(context),
                                  ),
                                ],
                              ),
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
                                  final addedById = (item['addedById'] ??
                                          item['createdById'] ??
                                          (item['createdBy'] is String
                                              ? item['createdBy']
                                              : null)) as String?;
                                  final addedByName = (item['addedBy'] ??
                                      item['createdByName']) as String?;
                                  final isAddedByMe = (addedById != null &&
                                          _currentUserId != null &&
                                          addedById == _currentUserId) ||
                                      addedByName == 'you';
                                  final isCreatorOrAdder = (createdBy != null &&
                                          _currentUserId != null &&
                                          createdBy == _currentUserId) ||
                                      isAddedByMe;

                                  final String? addedByLabel = isAddedByMe
                                      ? 'Added by you'
                                      : (addedByName != null &&
                                              addedByName.trim().isNotEmpty &&
                                              addedByName.toLowerCase() !=
                                                  'null'
                                          ? 'Added by $addedByName'
                                          : (widget.contact.contactId != null &&
                                                  addedById ==
                                                      widget.contact.contactId
                                              ? 'Added by ${widget.contact.name ?? widget.contact.phoneNumber ?? "friend"}'
                                              : null));

                                  final isDeleted = item['isDeleted'] == true;
                                  final deletedBy =
                                      item['deletedBy'] as String?;
                                  final updatedBy =
                                      item['updatedBy'] as String?;
                                  final canEditExpense = type == 'expense' &&
                                      entryId != null &&
                                      isCreatorOrAdder &&
                                      !isDeleted;
                                  final canDeleteExpense = canEditExpense;
                                  final canDeleteTransaction =
                                      type == 'transaction' &&
                                          entryId != null &&
                                          !isDeleted &&
                                          (direction == 'sent' ||
                                              isCreatorOrAdder);
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
                                  final accentColor =
                                      _entryAccentColor(type, direction);
                                  final formattedDate =
                                      AppDateUtils.formatDate(date);
                                  final formattedTime =
                                      AppDateUtils.formatTime(date);
                                  final amountText = formatMinorUnits(
                                    amount,
                                    currencyCode: preferredCurrencyCode,
                                  );
                                  final metaLabel = isDeleted
                                      ? (deletedBy != null &&
                                              deletedBy.trim().isNotEmpty
                                          ? 'Deleted by $deletedBy'
                                          : 'Deleted record')
                                      : updatedBy != null
                                          ? 'Edited by $updatedBy'
                                          : (isYouPaid && seenByOther
                                              ? _formatSeenLabel(seenAt)
                                              : null);
                                  final metaIcon = isDeleted
                                      ? Icons.delete_outline_rounded
                                      : updatedBy != null
                                          ? Icons.edit_outlined
                                          : Icons.done_all_rounded;
                                  final metaColor = isDeleted
                                      ? AppColors.error
                                      : updatedBy != null
                                          ? AppColors.textSecondary
                                          : AppColors.success;
                                  final syncStatus = item['status'] as String?;

                                  return Padding(
                                      key: ValueKey(_itemIdentifier(item)),
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Align(
                                        alignment: isYouPaid
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (syncStatus == 'failed') {
                                              showModalBottomSheet(
                                                context: context,
                                                backgroundColor:
                                                    AppColors.surface,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              20)),
                                                ),
                                                builder: (ctx) => SafeArea(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Text(
                                                          'Transaction Not Synced',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        const Text(
                                                          'This item could not sync with the server. Would you like to retry or discard it?',
                                                          textAlign: TextAlign
                                                              .center,
                                                        ),
                                                        const SizedBox(
                                                            height: 20),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  OutlinedButton(
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      ctx);
                                                                  setState(() {
                                                                    _transactions
                                                                        .removeWhere((e) =>
                                                                            _itemIdentifier(e) ==
                                                                            _itemIdentifier(item));
                                                                  });
                                                                },
                                                                child:
                                                                    const Text(
                                                                  'Discard',
                                                                  style: TextStyle(
                                                                      color: AppColors
                                                                          .error),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child:
                                                                  ElevatedButton(
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      ctx);
                                                                  _retryFailedItem(
                                                                      item);
                                                                },
                                                                child:
                                                                    const Text(
                                                                        'Retry Sync'),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            final items = <DetailItem>[];
                                            final participantPhonesRaw =
                                                item['participantPhones'];
                                            final participantLabels =
                                                participantPhonesRaw is List
                                                    ? participantPhonesRaw
                                                        .map((e) =>
                                                            e
                                                                ?.toString()
                                                                .trim() ??
                                                            '')
                                                        .where(
                                                            (e) => e.isNotEmpty)
                                                        .map((phone) => context
                                                            .read<
                                                                ContactProvider>()
                                                            .getDisplayName(
                                                                phone))
                                                        .toList()
                                                    : <String>[];

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
                                                  icon: Icons
                                                      .account_balance_wallet,
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
                                              if (participantLabels
                                                  .isNotEmpty) {
                                                items.add(DetailItem(
                                                  label: 'Shared With',
                                                  value: participantLabels
                                                      .join(', '),
                                                  icon: Icons.group_outlined,
                                                ));
                                              }
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
                                                  AppDateUtils.formatDateTime(
                                                      date),
                                              icon: Icons.calendar_today,
                                            ));
                                            if (addedByLabel != null) {
                                              items.add(DetailItem(
                                                label: 'Recorded by',
                                                value: addedByLabel,
                                                icon: Icons.person_outline_rounded,
                                                valueColor: AppColors.textSecondary,
                                              ));
                                            }
                                            if (metaLabel != null) {
                                              items.add(DetailItem(
                                                label: isDeleted
                                                    ? 'Deleted'
                                                    : 'Updated',
                                                value: metaLabel,
                                                icon: metaIcon,
                                                valueColor: metaColor,
                                              ));
                                            }

                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  DetailDialog(
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
                                                    canEditExpense:
                                                        canEditExpense,
                                                    canDeleteExpense:
                                                        canDeleteExpense,
                                                    canDeleteTransaction:
                                                        canDeleteTransaction,
                                                    description: description,
                                                    totalAmount:
                                                        totalAmount ?? amount,
                                                    participantsCount:
                                                        participants,
                                                  )
                                              : null,
                                          child: Opacity(
                                            opacity: isDeleted ? 0.55 : 1.0,
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.78,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: accentColor.withValues(
                                                      alpha: 0.25),
                                                  width: 1,
                                                ),
                                                boxShadow: AppShadows.card,
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Header
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(12, 8, 4, 8),
                                                    color:
                                                        accentColor.withValues(
                                                            alpha: 0.16),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          type == 'expense'
                                                              ? Icons
                                                                  .receipt_long_rounded
                                                              : Icons
                                                                  .payments_rounded,
                                                          size: 13,
                                                          color: accentColor,
                                                        ),
                                                        const SizedBox(
                                                            width: 5),
                                                        Text(
                                                          tagText,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: accentColor,
                                                          ),
                                                        ),
                                                        if (isDeleted) ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .error
                                                                  .withValues(
                                                                      alpha:
                                                                          0.15),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: const Text(
                                                              'Deleted',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: AppColors
                                                                    .error,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                        const Spacer(),
                                                        Text(
                                                          '$formattedDate · $formattedTime',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: accentColor
                                                                .withValues(
                                                                    alpha:
                                                                        0.75),
                                                          ),
                                                        ),
                                                        if (syncStatus ==
                                                            'syncing') ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              SizedBox(
                                                                width: 9,
                                                                height: 9,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      1.5,
                                                                  valueColor:
                                                                      AlwaysStoppedAnimation<
                                                                              Color>(
                                                                          accentColor),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                'Syncing',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: accentColor
                                                                      .withValues(
                                                                          alpha:
                                                                              0.85),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ] else if (syncStatus ==
                                                            'failed') ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          const Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .warning_amber_rounded,
                                                                  size: 11,
                                                                  color: AppColors
                                                                      .error),
                                                              SizedBox(
                                                                  width: 2),
                                                              Text(
                                                                'Failed',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: AppColors
                                                                      .error,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                        if (canManageEntry &&
                                                            syncStatus !=
                                                                'syncing' &&
                                                            syncStatus !=
                                                                'failed')
                                                          PopupMenuButton<
                                                              String>(
                                                            tooltip: 'Options',
                                                            padding:
                                                                EdgeInsets.zero,
                                                            onSelected:
                                                                (value) async {
                                                              final selectedEntryId =
                                                                  entryId;
                                                              if (value ==
                                                                  'share') {
                                                                _shareEntry(
                                                                    item,
                                                                    preferredCurrencyCode);
                                                              } else if (value ==
                                                                  'edit_expense') {
                                                                await _handleExpenseEdit(
                                                                  expenseId:
                                                                      selectedEntryId,
                                                                  description:
                                                                      description,
                                                                  totalAmount:
                                                                      totalAmount ??
                                                                          amount,
                                                                  participantsCount:
                                                                      participants,
                                                                );
                                                              } else if (value ==
                                                                  'delete_expense') {
                                                                await _handleExpenseDelete(
                                                                    selectedEntryId,
                                                                    participantsCount:
                                                                        participants);
                                                              } else if (value ==
                                                                  'delete_transaction') {
                                                                await _handleTransactionDelete(
                                                                    selectedEntryId);
                                                              }
                                                            },
                                                            itemBuilder:
                                                                (context) => [
                                                              const PopupMenuItem<
                                                                  String>(
                                                                value: 'share',
                                                                child: Row(
                                                                    children: [
                                                                      Icon(
                                                                          Icons
                                                                              .share_outlined,
                                                                          size:
                                                                              16),
                                                                      SizedBox(
                                                                          width:
                                                                              8),
                                                                      Text(
                                                                          'Share'),
                                                                    ]),
                                                              ),
                                                              if (canEditExpense)
                                                                const PopupMenuItem<
                                                                        String>(
                                                                    value:
                                                                        'edit_expense',
                                                                    child: Text(
                                                                        'Edit')),
                                                              if (canDeleteExpense)
                                                                const PopupMenuItem<
                                                                        String>(
                                                                    value:
                                                                        'delete_expense',
                                                                    child: Text(
                                                                        'Delete')),
                                                              if (canDeleteTransaction)
                                                                const PopupMenuItem<
                                                                        String>(
                                                                    value:
                                                                        'delete_transaction',
                                                                    child: Text(
                                                                        'Delete')),
                                                            ],
                                                            child:
                                                                const Padding(
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          6),
                                                              child: Icon(
                                                                  Icons
                                                                      .more_vert,
                                                                  size: 16,
                                                                  color: AppColors
                                                                      .textSecondary),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Divider
                                                  Container(
                                                    height: 1,
                                                    color:
                                                        accentColor.withValues(
                                                            alpha: 0.10),
                                                  ),
                                                  // Body
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        12, 10, 12, 10),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (description
                                                            .isNotEmpty) ...[
                                                          Text(
                                                            description,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 14,
                                                              decoration: isDeleted
                                                                  ? TextDecoration
                                                                      .lineThrough
                                                                  : null,
                                                              decorationColor:
                                                                  AppColors
                                                                      .textSecondary,
                                                              color: AppColors
                                                                  .textPrimary,
                                                            ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                        ],
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                type == 'expense'
                                                                    ? (isYouPaid
                                                                        ? 'You covered this split'
                                                                        : 'Shared expense')
                                                                    : (isYouPaid
                                                                        ? 'Payment sent'
                                                                        : 'Payment received'),
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400,
                                                                  color: AppColors
                                                                      .textSecondary,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Text(
                                                              amountText,
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                decoration: isDeleted
                                                                    ? TextDecoration
                                                                        .lineThrough
                                                                    : null,
                                                                decorationColor:
                                                                    AppColors
                                                                        .textSecondary,
                                                                color: isDeleted
                                                                    ? AppColors
                                                                        .textSecondary
                                                                    : accentColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        // Footer pills
                                                        const SizedBox(
                                                            height: 8),
                                                        Container(
                                                          height: 1,
                                                          color: AppColors
                                                              .borderLight,
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Wrap(
                                                          spacing: 5,
                                                          runSpacing: 4,
                                                          children: [
                                                            _buildBubblePill(
                                                              icon: type ==
                                                                      'expense'
                                                                  ? Icons
                                                                      .person_outline_rounded
                                                                  : (isYouPaid
                                                                      ? Icons
                                                                          .north_east_rounded
                                                                      : Icons
                                                                          .south_west_rounded),
                                                              label: type ==
                                                                      'expense'
                                                                  ? 'Your share'
                                                                  : (isYouPaid
                                                                      ? 'Sent'
                                                                      : 'Received'),
                                                              color: isDeleted
                                                                  ? AppColors
                                                                      .textSecondary
                                                                  : accentColor,
                                                            ),
                                                            if (type ==
                                                                    'expense' &&
                                                                totalAmount !=
                                                                    null)
                                                              _buildBubblePill(
                                                                icon: Icons
                                                                    .account_balance_wallet_outlined,
                                                                label:
                                                                    'Total ${formatMinorUnits(totalAmount, currencyCode: preferredCurrencyCode)}',
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                            if (type ==
                                                                    'expense' &&
                                                                participants >
                                                                    0)
                                                              _buildBubblePill(
                                                                icon: Icons
                                                                    .group_outlined,
                                                                label:
                                                                    '${participants + 1} people',
                                                                color: AppColors
                                                                    .textSecondary,
                                                              ),
                                                            if (addedByLabel !=
                                                                null)
                                                              _buildBubblePill(
                                                                icon: Icons
                                                                    .person_outline_rounded,
                                                                label:
                                                                    addedByLabel,
                                                                color: AppColors
                                                                    .textSecondary,
                                                                shrink: true,
                                                              ),
                                                            if (metaLabel !=
                                                                null)
                                                              _buildBubblePill(
                                                                icon: metaIcon,
                                                                label:
                                                                    metaLabel,
                                                                color:
                                                                    metaColor,
                                                                shrink: true,
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ));
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
                padding: EdgeInsets.fromLTRB(
                    12, 8, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addExpenseFromChat,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Add Expense'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _addTransactionFromChat,
                        icon: const Icon(Icons.payments),
                        label: const FittedBox(child: Text('Add Transaction')),
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

  Widget _buildSkeletonLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.09);

    Widget buildBubbleSkeleton({
      required bool isSent,
      required double widthRatio,
      required double height,
    }) {
      return Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: MediaQuery.of(context).size.width * widthRatio,
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSent
                ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSent ? 16 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 16),
            ),
            boxShadow: AppShadows.card,
            border: Border.all(
              color: isSent
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment:
                    isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 12,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment:
                    isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 110,
                    height: 18,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
              Container(
                width: 50,
                height: 10,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        buildBubbleSkeleton(isSent: false, widthRatio: 0.65, height: 85),
        buildBubbleSkeleton(isSent: true, widthRatio: 0.55, height: 80),
        buildBubbleSkeleton(isSent: false, widthRatio: 0.70, height: 90),
        buildBubbleSkeleton(isSent: true, widthRatio: 0.60, height: 85),
      ],
    );
  }
}
