import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../constants/app_shadows.dart';
import '../constants/app_text_styles.dart';

class AppInquiryDialog extends StatelessWidget {
  static const String email = 'hello@thetrozen.com';
  static const String phone = '+918887692942';
  static const String whatsappNumber = '918887692942';

  const AppInquiryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const AppInquiryDialog(),
    );
  }

  static Future<void> showBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AppInquirySheet(),
    );
  }

  static Future<void> launchEmail({String? customSubject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': customSubject ?? 'FlatSync App Inquiry / Custom Development',
        'body':
            'Hi The Trozen Team,\n\nI am interested in buying the FlatSync app or getting custom development done (App / Web / Desktop).\n\nDetails:\n',
      },
    );
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(Uri.parse('mailto:$email'));
      } catch (_) {
        await Clipboard.setData(const ClipboardData(text: email));
      }
    }
  }

  static Future<void> launchCall() async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: phone));
    }
  }

  static Future<void> launchWhatsApp() async {
    const text =
        'Hi, I saw the FlatSync app and I am interested in buying it or getting custom App/Web/Desktop development done.';
    final uri = Uri.parse(
        'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(text)}');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: phone));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.cardElevated,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    Color(0xFF6366F1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.amberAccent,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'THE TROZEN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Want to Buy this App or Build Custom Software?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Get this complete ready-to-launch app source code or build custom Mobile, Web, & Desktop apps.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content & Service Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What We Build & Offer:',
                    style: AppTextStyles.labelSmall(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ServicePill(
                        icon: Icons.phone_android_rounded,
                        label: 'Android & iOS Apps',
                        isDark: isDark,
                      ),
                      _ServicePill(
                        icon: Icons.language_rounded,
                        label: 'Websites & Web Apps',
                        isDark: isDark,
                      ),
                      _ServicePill(
                        icon: Icons.laptop_mac_rounded,
                        label: 'Desktop Software',
                        isDark: isDark,
                      ),
                      _ServicePill(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Buy FlatSync App',
                        isDark: isDark,
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Contact Actions
                  _ContactActionTile(
                    icon: Icons.chat_rounded,
                    title: 'WhatsApp Us',
                    subtitle: '+91 88876 92942',
                    badge: 'Fast Reply',
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Navigator.of(context).pop();
                      launchWhatsApp();
                    },
                  ),
                  const SizedBox(height: 8),
                  _ContactActionTile(
                    icon: Icons.email_rounded,
                    title: 'Email Us',
                    subtitle: email,
                    badge: 'Official Inquiry',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      launchEmail();
                    },
                  ),
                  const SizedBox(height: 8),
                  _ContactActionTile(
                    icon: Icons.phone_in_talk_rounded,
                    title: 'Call Directly',
                    subtitle: '+91 88876 92942',
                    badge: 'Voice Call',
                    color: const Color(0xFF0284C7),
                    onTap: () {
                      Navigator.of(context).pop();
                      launchCall();
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInquirySheet extends StatelessWidget {
  const _AppInquirySheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.cardElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Development & Buy App',
                            style: AppTextStyles.titleMedium(context).copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Powered by The Trozen',
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to scale your idea?',
                      style: AppTextStyles.titleSmall(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Whether you want to buy this complete expense splitting app or need custom Android/iOS apps, modern websites, or desktop software, we build high-performance products tailored to your needs.',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ServicePill(
                          icon: Icons.phone_android_rounded,
                          label: 'Mobile Apps (Flutter/Native)',
                          isDark: isDark,
                        ),
                        _ServicePill(
                          icon: Icons.language_rounded,
                          label: 'Full-Stack Web Apps & APIs',
                          isDark: isDark,
                        ),
                        _ServicePill(
                          icon: Icons.desktop_windows_rounded,
                          label: 'Windows / Mac Desktop Apps',
                          isDark: isDark,
                        ),
                        _ServicePill(
                          icon: Icons.code_rounded,
                          label: 'Complete Source Code Purchase',
                          isDark: isDark,
                          highlight: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Contact Directly:',
                      style: AppTextStyles.labelSmall(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _ContactActionTile(
                      icon: Icons.chat_rounded,
                      title: 'Chat on WhatsApp',
                      subtitle: '+91 88876 92942',
                      badge: 'Instant',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        Navigator.of(context).pop();
                        AppInquiryDialog.launchWhatsApp();
                      },
                    ),
                    const SizedBox(height: 8),
                    _ContactActionTile(
                      icon: Icons.email_rounded,
                      title: 'Send Email',
                      subtitle: AppInquiryDialog.email,
                      badge: 'Official',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.of(context).pop();
                        AppInquiryDialog.launchEmail();
                      },
                    ),
                    const SizedBox(height: 8),
                    _ContactActionTile(
                      icon: Icons.phone_in_talk_rounded,
                      title: 'Phone Call',
                      subtitle: '+91 88876 92942',
                      badge: 'Direct Call',
                      color: const Color(0xFF0284C7),
                      onTap: () {
                        Navigator.of(context).pop();
                        AppInquiryDialog.launchCall();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool highlight;

  const _ServicePill({
    required this.icon,
    required this.label,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight
                  ? (isDark ? const Color(0xFF93C5FD) : AppColors.primaryDark)
                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final VoidCallback onTap;

  const _ContactActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleSmall(context).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
