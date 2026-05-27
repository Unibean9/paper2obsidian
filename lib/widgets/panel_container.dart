import 'package:flutter/material.dart';

/// Reusable card-style container used for all three columns in the workspace.
/// Extracted from the `_buildPanel` helper in the original main.dart.
class PanelContainer extends StatelessWidget {
  const PanelContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // The outer Container paints the white background, rounded corners, and shadow.
    // The inner Material(transparent) provides a proper Material surface so that
    // any ListTile / InkWell descendant can paint its ink splash correctly.
    // Without this, ListTile's ink splash would be hidden behind the DecoratedBox.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
