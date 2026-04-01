import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppShellNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAddPressed;

  const AppShellNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAddPressed,
  });

  static const _items = [
    _NavItem(icon: Icons.people_alt_rounded, label: 'Contacts'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'History'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive navbar height: taller on bigger screens
    final navHeight = screenWidth < 360 ? 62.0 : 68.0;
    // FAB size responsive
    final fabSize = screenWidth < 360 ? 44.0 : 52.0;
    final fabRadius = screenWidth < 360 ? 14.0 : 18.0;
    final hPadding = screenWidth < 360 ? 10.0 : 16.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPadding, 8, hPadding, 12),
        child: Container(
          height: navHeight,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_items.length, (i) {
                    return Expanded(
                      child: _NavButton(
                        item: _items[i],
                        selected: selectedIndex == i,
                        onTap: () => onSelected(i),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: hPadding - 6),
                child: GestureDetector(
                  onTap: () {
                    onSelected(3);
                    onAddPressed();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: fabSize,
                    height: fabSize,
                    decoration: BoxDecoration(
                      gradient: selectedIndex == 3
                          ? const LinearGradient(
                              colors: [Color(0xFF6EE7B7), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1E3FBF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(fabRadius),
                      boxShadow: [
                        BoxShadow(
                          color: (selectedIndex == 3
                                  ? const Color(0xFF059669)
                                  : AppColors.primary)
                              .withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.add_rounded,
                        color: Colors.white,
                        size: screenWidth < 360 ? 22 : 26),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 360 ? 20.0 : (selected ? 24.0 : 22.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                item.icon,
                key: ValueKey(selected),
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                size: iconSize,
              ),
            ),
            const SizedBox(height: 3),
            // FittedBox ensures label never overflows on small screens
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: screenWidth < 360 ? 9 : 10,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.2,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF6EE7B7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
