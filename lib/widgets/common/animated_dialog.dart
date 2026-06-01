import 'package:flutter/material.dart';

/// Displays a premium dialog with organic fade and springy scale (zoom-in) entrance transitions.
///
/// On exit, it provides a fast and clean fade out with subtle scaling down to remain highly responsive.
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss Dialog',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return child;
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Springy elastic curve for opening, clean ease-in for closing
      final scaleAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInQuad,
      );

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );

      return ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(scaleAnimation),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(fadeAnimation),
          child: child,
        ),
      );
    },
  );
}
