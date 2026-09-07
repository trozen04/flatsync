import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../widgets/help_content.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../utils/custom_snackbar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const String privacyPolicyText = '''
Privacy Policy for FairChop

How FairChop handles your data:
We collect only what is needed for the app to work and to keep your account and shared expenses synced.

1. Information we collect:
- Profile details such as your name and phone number.
- Shared expense data, balances, and transactions you save.
- Contacts you choose to use for splitting expenses.
- Device and notification permissions when you enable them.

2. How we use it:
- To create and manage your account.
- To split expenses, track balances, and show history.
- To sync your data across devices and keep notifications working.
- To improve app reliability and support requests.

3. Storage and security:
- Some data is stored locally on your device for offline use.
- Account and sync data may be stored on our backend so your app can work across devices.
- We use standard security practices to protect the app and its data.

4. Sharing and access:
- We do not sell your personal data.
- Shared expense data is visible to people you add for expense tracking.
- We may share data only when required by law or to operate the service.

5. Your choices:
- You can update your profile details inside the app.
- You can disable notifications or revoke permissions from device settings.
- You can request account or data help through support.

6. Contact:
- Email: hello@thetrozen.com
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Privacy Policy',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(38, 38),
              ),
              icon: const Icon(
                Icons.copy_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Copy Privacy Policy',
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: privacyPolicyText));
                CustomSnackBar.show(context,
                    message: 'Privacy policy copied to clipboard');
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppDimensions.appMargin(context).copyWith(
            bottom: AppDimensions.height(context) * 0.08,
          ),
          children: [
            const HelpHeroCard(
              icon: Icons.privacy_tip_rounded,
              title: 'How FairChop handles your data',
              subtitle:
                  'We collect only what is needed for the app to work and to keep your account and shared expenses synced.',
            ),
            AppDimensions.h20(context),
            const HelpBulletCard(
              title: 'Information we collect',
              bullets: [
                'Profile details such as your name and phone number.',
                'Shared expense data, balances, and transactions you save.',
                'Contacts you choose to use for splitting expenses.',
                'Device and notification permissions when you enable them.',
              ],
            ),
            AppDimensions.h20(context),
            const HelpBulletCard(
              title: 'How we use it',
              bullets: [
                'To create and manage your account.',
                'To split expenses, track balances, and show history.',
                'To sync your data across devices and keep notifications working.',
                'To improve app reliability and support requests.',
              ],
            ),
            AppDimensions.h20(context),
            const HelpBulletCard(
              title: 'Storage and security',
              bullets: [
                'Some data is stored locally on your device for offline use.',
                'Account and sync data may be stored on our backend so your app can work across devices.',
                'We use standard security practices to protect the app and its data.',
              ],
            ),
            AppDimensions.h20(context),
            const HelpBulletCard(
              title: 'Sharing and access',
              bullets: [
                'We do not sell your personal data.',
                'Shared expense data is visible to people you add for expense tracking.',
                'We may share data only when required by law or to operate the service.',
              ],
            ),
            AppDimensions.h20(context),
            const HelpBulletCard(
              title: 'Your choices',
              bullets: [
                'You can update your profile details inside the app.',
                'You can disable notifications or revoke permissions from device settings.',
                'You can request account or data help through support.',
              ],
            ),
            AppDimensions.h20(context),
            const HelpBulletCard(
              title: 'Contact',
              bullets: [
                'Support email: hello@thetrozen.com',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
