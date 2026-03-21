import 'package:flutter/material.dart';

import '../screens/contacts/contact_selection_screen.dart';

class AppRoutes {
  static const String contactSelection = '/contact-selection';

  static Map<String, WidgetBuilder> get routes => {
        contactSelection: (_) => const ContactSelectionScreen(),
      };
}
