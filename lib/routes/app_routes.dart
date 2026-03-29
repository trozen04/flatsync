import 'package:flutter/material.dart';

import '../screens/contacts/contact_selection_screen.dart';
import '../screens/help/help_guide_screen.dart';
import '../screens/help/privacy_screen.dart';
import '../screens/help/terms_screen.dart';

class AppRoutes {
  static const String contactSelection = '/contact-selection';
  static const String helpGuide = '/help-guide';
  static const String terms = '/terms';
  static const String privacy = '/privacy';

  static Map<String, WidgetBuilder> get routes => {
        contactSelection: (_) => const ContactSelectionScreen(),
        helpGuide: (_) => const HelpGuideScreen(),
        terms: (_) => const TermsScreen(),
        privacy: (_) => const PrivacyScreen(),
      };
}
