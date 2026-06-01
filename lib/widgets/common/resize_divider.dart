import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ResizeDivider extends StatefulWidget {
  const ResizeDivider({
    super.key,
    required this.isLeft,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool isLeft;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<ResizeDivider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          widget.onDragUpdate(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          widget.onDragEnd();
        },
        child: Container(
          width: 12,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: Colors.transparent, // Đảm bảo toàn bộ vùng 12px nhận được tương tác drag
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isHovered ? 3.0 : 1.5,
              height: double.infinity,
              decoration: BoxDecoration(
                color: _isHovered ? AppColors.accent : AppColors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
