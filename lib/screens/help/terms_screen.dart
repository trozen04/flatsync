import 'package:flutter/material.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/help_content.dart';
import '../../widgets/gradient_app_bar.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Terms & Conditions'),
      body: SafeArea(
        child: ListView(
          padding: AppDimensions.appMargin(context).copyWith(
            bottom: AppDimensions.height(context) * 0.08,
          ),
          children: [
            const HelpHeroCard(
              icon: Icons.description_rounded,
              title: 'Terms for using SplitEasy',
              subtitle:
                  'These terms explain how the app should be used and what users are responsible for.',
            ),
            AppDimensions.h20(context),
            Text('1. Acceptable use', style: AppTextStyles.titleMedium(context)),
            AppDimensions.h10(context),
            const HelpBulletCard(
              bullets: [
                'Use the app for lawful personal, household, trip, or group expense tracking.',
                'Do not enter false, abusive, or unlawful content.',
                'Respect the privacy of other people whose data you add.',
              ],
            ),
            AppDimensions.h20(context),
            Text('2. User responsibility',
                style: AppTextStyles.titleMedium(context)),
            AppDimensions.h10(context),
            const HelpBulletCard(
              bullets: [
                'You are responsible for the accuracy of names, phone numbers, amounts, and splits you enter.',
                'Balances, settlements, and history are based on the data stored in the app.',
                'Always verify amounts before recording a payment or settlement.',
              ],
            ),
            AppDimensions.h20(context),
            Text('3. App features', style: AppTextStyles.titleMedium(context)),
            AppDimensions.h10(context),
            const HelpBulletCard(
              bullets: [
                'Some features may require internet access, device permissions, or sign-in.',
                'We may update, add, or remove features at any time.',
                'Notifications, contact sync, and device security features depend on your device settings.',
              ],
            ),
            AppDimensions.h20(context),
            Text('4. Changes', style: AppTextStyles.titleMedium(context)),
            AppDimensions.h10(context),
            const HelpBulletCard(
              bullets: [
                'We may revise these terms when the app changes.',
                'Continued use of the app means you accept the updated terms.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
