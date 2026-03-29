import 'package:flutter/material.dart';

import '../contacts/contacts_screen.dart';

class BalancesScreen extends StatelessWidget {
  final VoidCallback onNavigateToAddExpense;

  const BalancesScreen({super.key, required this.onNavigateToAddExpense});

  @override
  Widget build(BuildContext context) {
    return const ContactsScreen();
  }
}
