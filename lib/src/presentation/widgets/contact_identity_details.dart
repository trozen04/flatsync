import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

String formatContactPhone(String? rawPhone) {
  final digits = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 10) {
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
  }
  if (digits.length > 10) {
    return '+$digits';
  }
  return digits;
}

class ContactIdentityDetails extends StatelessWidget {
  final String name;
  final String? phoneNumber;
  final bool isVerified;
  final TextStyle? nameStyle;
  final TextStyle? phoneStyle;
  final Widget? extra;

  const ContactIdentityDetails({
    super.key,
    required this.name,
    this.phoneNumber,
    this.isVerified = false,
    this.nameStyle,
    this.phoneStyle,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final formattedPhone = formatContactPhone(phoneNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: nameStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (formattedPhone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  formattedPhone,
                  style: phoneStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
              ],
            ],
          ),
        ],
        if (extra != null) ...[
          const SizedBox(height: 4),
          extra!,
        ],
      ],
    );
  }
}
