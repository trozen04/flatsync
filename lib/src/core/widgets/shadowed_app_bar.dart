import 'package:flutter/material.dart';

import '../theme/app_shadows.dart';

class ShadowedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;

  const ShadowedAppBar({super.key, required this.child});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Only the shadow is needed; AppBar paints its own background.
              boxShadow: AppShadows.appBar,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
