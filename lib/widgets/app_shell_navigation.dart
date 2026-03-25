import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

class AppShellNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppShellNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double barHeight = 72;

  static const _items = [
    _NavItem(index: 1, label: 'Contacts', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
    _NavItem(index: 2, label: 'Balances', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
    _NavItem(index: 0, label: 'Add', icon: Icons.add_rounded, activeIcon: Icons.add_rounded, isFab: true),
    _NavItem(index: 3, label: 'History', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded),
    _NavItem(index: 4, label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: barHeight + bottomPad,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4), width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Row(
          children: _items.map((item) {
            final isSelected = selectedIndex == item.index;
            if (item.isFab) {
              return Expanded(child: _FabNavItem(isSelected: isSelected, onTap: () {
                HapticFeedback.lightImpact();
                onSelected(item.index);
              }));
            }
            return Expanded(
              child: _RegularNavItem(
                item: item,
                isSelected: isSelected,
                accentColor: scheme.primary,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(item.index);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FabNavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _FabNavItem({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: AppShellNavigation.barHeight,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: isSelected ? 56 : 52,
            height: isSelected ? 56 : 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isSelected ? 0.45 : 0.25),
                  blurRadius: isSelected ? 20 : 12,
                  offset: const Offset(0, 4),
                  spreadRadius: isSelected ? 1 : 0,
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: isSelected ? 30 : 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _RegularNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _RegularNavItem({
    required this.item,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: AppShellNavigation.barHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 22,
                color: isSelected ? accentColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accentColor : AppColors.textSecondary,
                letterSpacing: 0.1,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isFab;

  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isFab = false,
  });
}
