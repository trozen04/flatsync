import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_info.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/custom_snackbar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/help_content.dart';
import '../../widgets/gradient_app_bar.dart';

class HelpGuideScreen extends StatefulWidget {
  const HelpGuideScreen({super.key});

  @override
  State<HelpGuideScreen> createState() => _HelpGuideScreenState();
}

class _HelpGuideScreenState extends State<HelpGuideScreen> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _openExternal(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      CustomSnackBar.show(context, message: 'Could not open link', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Help & Guide'),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: _packageInfoFuture,
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? 'Loading...';
            final buildNumber = snapshot.data?.buildNumber ?? '';
            final fullVersion =
                buildNumber.isEmpty ? version : '$version+$buildNumber';

            return ListView(
              padding: AppDimensions.appMargin(context).copyWith(
                bottom: AppDimensions.height(context) * 0.08,
              ),
              children: [
                HelpHeroCard(
                  icon: Icons.help_center_rounded,
                  title: AppInfo.appName,
                  subtitle:
                      'Quick help, app details, support, and access to other apps.',
                  badges: [
                    HelpBadge(
                      icon: Icons.verified_rounded,
                      label: 'Version $fullVersion',
                    ),
                    HelpBadge(
                      icon: Icons.code_rounded,
                      label: 'Developed by ${AppInfo.developer}',
                    ),
                  ],
                ),
                AppDimensions.h20(context),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openExternal(
                          context,
                          Uri.parse('mailto:${AppInfo.supportEmail}'),
                        ),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Contact support'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openExternal(
                          context,
                          Uri.parse(AppInfo.developerPageUrl),
                        ),
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text('More apps'),
                      ),
                    ),
                  ],
                ),
                AppDimensions.h20(context),
                Text('How to use', style: AppTextStyles.titleMedium(context)),
                AppDimensions.h10(context),
                const HelpBulletCard(
                  title: 'How to use',
                  bullets: [
                    'Add people before splitting expenses.',
                    'Enter the amount, select participants, and save.',
                    'Track balances and settle payments later.',
                    'Review expenses and transactions in one place.',
                  ],
                ),
                AppDimensions.h20(context),
                Text('App info', style: AppTextStyles.titleMedium(context)),
                AppDimensions.h10(context),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        HelpInfoRow(
                          icon: Icons.mail_outline_rounded,
                          title: 'Support email',
                          value: AppInfo.supportEmail,
                          trailing: TextButton(
                            onPressed: () => _openExternal(
                              context,
                              Uri.parse('mailto:${AppInfo.supportEmail}'),
                            ),
                            child: const Text('Email'),
                          ),
                        ),
                        const Divider(height: 1),
                        HelpInfoRow(
                          icon: Icons.storefront_rounded,
                          title: 'Developer page',
                          value: 'View more apps on Google Play',
                          trailing: TextButton(
                            onPressed: () => _openExternal(
                              context,
                              Uri.parse(AppInfo.developerPageUrl),
                            ),
                            child: const Text('Open'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppDimensions.h20(context),
                Text('Need help fast?', style: AppTextStyles.titleMedium(context)),
                AppDimensions.h10(context),
                AppCard(
                  type: AppCardType.outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'If something looks wrong, send your app version and a screenshot to support. That helps us resolve issues faster.',
                        style: AppTextStyles.bodyMedium(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version shown on this device: $fullVersion',
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
