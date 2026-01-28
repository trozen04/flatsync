import 'package:flutter/material.dart';

class CustomSnackBar {
  static OverlayEntry? _currentEntry;
  static bool _isAnimating = false;

  /// Show animated snackBar at the top
  static void show(
      BuildContext context, {
        required String message,
        bool isError = false,
        bool persistent = false,
      }) async {
    // If one is still animating → ignore this call
    if (_isAnimating) return;

    // If one is visible → hide first then show new one
    if (_currentEntry != null) {
      await hide();
    }

    _isAnimating = true;

    final overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedBanner(
        message: message,
        isError: isError,
        onClose: hide,
      ),
    );

    _currentEntry = overlayEntry;
    Overlay.of(context).insert(overlayEntry);

    if (!persistent) {
      Future.delayed(const Duration(seconds: 2), () async {
        await hide();
      });
    }
  }

  /// Hide current banner
  static Future<void> hide() async {
    if (_currentEntry == null) return;

    final entry = _currentEntry!;
    _currentEntry = null;

    try {
      final state = entry.opaque as dynamic;
      if (state is _AnimatedBannerState) {
        await state.dismiss();
      }
    } catch (_) {}

    entry.remove();
    _isAnimating = false;
  }
}

/// Internal widget
class _AnimatedBanner extends StatefulWidget {
  final String message;
  final bool isError;
  final Future<void> Function() onClose;

  const _AnimatedBanner({
    required this.message,
    required this.isError,
    required this.onClose,
  });

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  Future<void> dismiss() async {
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: widget.isError ? Colors.red : Colors.green,
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
