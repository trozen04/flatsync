import 'package:flutter/material.dart';

import '../../constants/app_dimensions.dart';
import '../../widgets/help_content.dart';
import '../../widgets/gradient_app_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Privacy Policy'),
      body: SafeArea(
        child: ListView(
          padding: AppDimensions.appMargin(context).copyWith(
            bottom: AppDimensions.height(context) * 0.08,
          ),
          children: [
            HelpHeroCard(
              icon: Icons.privacy_tip_rounded,
              title: 'How SplitEasy handles your data',
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
                'Support email: bhoopendrablog@gmail.com',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

