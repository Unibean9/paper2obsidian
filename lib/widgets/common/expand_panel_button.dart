import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

class ExpandPanelButton extends StatefulWidget {
  const ExpandPanelButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.isLeft,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isLeft;

  @override
  State<ExpandPanelButton> createState() => _ExpandPanelButtonState();
}

class _ExpandPanelButtonState extends State<ExpandPanelButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isHovered ? 28 : 20,
            height: 64,
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.accent : AppColors.accent.withValues(alpha: 0.85),
              borderRadius: widget.isLeft
                  ? const BorderRadius.only(
                      topRight: Radius.circular(AppRadius.md),
                      bottomRight: Radius.circular(AppRadius.md),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(AppRadius.md),
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: Offset(widget.isLeft ? 2 : -2, 2),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class ExpandPanelButtonVertical extends StatefulWidget {
  const ExpandPanelButtonVertical({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  State<ExpandPanelButtonVertical> createState() => _ExpandPanelButtonVerticalState();
}

class _ExpandPanelButtonVerticalState extends State<ExpandPanelButtonVertical> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 64,
            height: _isHovered ? 28 : 20,
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.accent : AppColors.accent.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }
}
