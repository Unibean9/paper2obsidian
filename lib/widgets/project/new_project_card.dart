import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

class HoverNewProjectCard extends StatefulWidget {
  const HoverNewProjectCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<HoverNewProjectCard> createState() => _HoverNewProjectCardState();
}

class _HoverNewProjectCardState extends State<HoverNewProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _isHovered ? -6.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _isHovered ? AppShadows.medium : AppShadows.none,
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: _isHovered ? AppColors.accent : AppColors.border,
            radius: AppRadius.md,
            strokeWidth: 1.5,
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Plus Button Ring
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: _isHovered ? 64 : 56,
                    height: _isHovered ? 64 : 56,
                    decoration: BoxDecoration(
                      color: _isHovered
                          ? AppColors.accent
                          : AppColors.surfaceNeutral.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: _isHovered ? AppShadows.glow : AppShadows.subtle,
                    ),
                    child: Icon(
                      Icons.add,
                      size: _isHovered ? 26 : 22,
                      color: _isHovered ? AppColors.textInverse : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Create new project',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _isHovered ? AppColors.accent : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
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

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += length + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
