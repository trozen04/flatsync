import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contact_model.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/isar_service.dart';
import '../../services/app_preferences_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/money_utils.dart';

class ContactDetailsScreen extends StatefulWidget {
  final ContactModel contact;
  final int balance;
  final int transactionCount;

  const ContactDetailsScreen({
    super.key,
    required this.contact,
    required this.balance,
    this.transactionCount = 0,
  });

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  bool _isDeleting = false;

  Future<void> _makePhoneCall() async {
    final phone = widget.contact.phoneNumber;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _confirmAndDelete() async {
    final overlay = Overlay.of(context);
    final currencyCode =
        context.read<AppPreferencesService>().preferredCurrencyCode;

    if (widget.balance != 0) {
      final formattedBal = formatMinorUnits(
        widget.balance.abs(),
        currencyCode: currencyCode,
      );
      final direction =
          widget.balance > 0 ? 'they owe you' : 'you owe them';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cannot Delete Contact',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'You have an unsettled balance of $formattedBal ($direction) with this contact.\n\nPlease settle up all balances before deleting this contact.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final contactService = context.read<ContactService>();
    final isar = context.read<IsarService>();

    final pin = await AppPinDialog.show(
      context,
      title: 'Delete Contact',
      subtitle:
          'Enter your PIN to remove ${widget.contact.name ?? 'this contact'} from your list.',
    );
    if (pin == null || pin.isEmpty || !mounted) return;

    final isValid = await authService.loginOffline(pin);
    if (!isValid) {
      if (mounted) {
        CustomSnackBar.showOnOverlay(overlay,
            message: 'Incorrect PIN', isError: true);
      }
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await contactService.deleteContact(isar, widget.contact);

      if (!mounted) return;
      CustomSnackBar.showOnOverlay(
        overlay,
        message: 'Contact deleted successfully',
      );
      Navigator.of(context).pop(true); // Return deleted = true
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        CustomSnackBar.showOnOverlay(
          overlay,
          message: 'Failed to delete contact: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode =
        context.watch<AppPreferencesService>().preferredCurrencyCode;
    final displayName = widget.contact.name ?? widget.contact.phoneNumber ?? 'Contact';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final balanceColor = widget.balance > 0
        ? AppColors.success
        : widget.balance < 0
            ? AppColors.error
            : AppColors.textSecondary;

    final balanceLabel = widget.balance > 0
        ? 'They owe you'
        : widget.balance < 0
            ? 'You owe them'
            : 'All settled up';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GradientAppBar(
        title: 'Contact Details',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: AppTextStyles.heading1(context),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.contact.phoneNumber != null &&
                      widget.contact.phoneNumber!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.contact.phoneNumber!,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Registration Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.contact.isRegistered
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.contact.isRegistered
                              ? Icons.verified_rounded
                              : Icons.person_outline_rounded,
                          size: 14,
                          color: widget.contact.isRegistered
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.contact.isRegistered
                              ? 'Registered on FairChop'
                              : 'Unregistered (Manual/SMS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.contact.isRegistered
                              ? AppColors.success
                              : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Financial Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ledger Overview',
                    style: AppTextStyles.heading2(context),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            balanceLabel,
                            style: AppTextStyles.bodySmall(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatMinorUnits(
                              widget.balance.abs(),
                              currencyCode: currencyCode,
                            ),
                            style: AppTextStyles.heading2(context).copyWith(
                              color: balanceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (widget.transactionCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Records',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${widget.transactionCount}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if (widget.contact.phoneNumber != null &&
                      widget.contact.phoneNumber!.isNotEmpty) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Call Contact',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        widget.contact.phoneNumber!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onTap: _makePhoneCall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Delete Contact Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppColors.error.withValues(alpha: 0.04),
                ),
                onPressed: _isDeleting ? null : _confirmAndDelete,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 22),
                label: Text(
                  _isDeleting ? 'Deleting...' : 'Delete Contact',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.balance != 0
                  ? 'Note: Contact can only be deleted once the balance is settled (₹0.00).'
                  : 'Removing this contact will remove it from your contact list.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
