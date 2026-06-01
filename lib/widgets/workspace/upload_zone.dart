import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../project/new_project_card.dart';

class HoverUploadZone extends StatefulWidget {
  const HoverUploadZone({
    super.key,
    required this.onTap,
    required this.zoteroAvailable,
    required this.onZoteroTap,
  });

  final VoidCallback? onTap;
  final bool zoteroAvailable;
  final VoidCallback onZoteroTap;

  @override
  State<HoverUploadZone> createState() => _HoverUploadZoneState();
}

class _HoverUploadZoneState extends State<HoverUploadZone> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.surfaceLight.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _isHovered ? AppShadows.subtle : AppShadows.none,
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: _isHovered ? AppColors.primary : AppColors.border,
            radius: AppRadius.md,
            strokeWidth: 1.5,
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xxl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: _isHovered ? AppColors.primary : AppColors.surfaceNeutral,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      size: AppSpacing.xxl,
                      color: _isHovered ? AppColors.textInverse : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Select Research Paper',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Drag PDF here or click to browse',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.zoteroAvailable) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      '— OR —',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: widget.onZoteroTap,
                      icon: const Icon(Icons.link_outlined, size: 14),
                      label: const Text('Import from Zotero', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
