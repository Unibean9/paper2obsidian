import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

class HoverProjectCard extends StatefulWidget {
  const HoverProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.pathBadge,
    required this.metaChip,
  });

  final Project project;
  final VoidCallback onTap;
  final Widget pathBadge;
  final Widget metaChip;

  @override
  State<HoverProjectCard> createState() => _HoverProjectCardState();
}

class _HoverProjectCardState extends State<HoverProjectCard> {
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
        transform: Matrix4.translationValues(0.0, _isHovered ? -5.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceLight : AppColors.surfaceNeutral,
          border: Border.all(
            color: _isHovered ? AppColors.primary : AppColors.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _isHovered ? AppShadows.medium : AppShadows.subtle,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: AppSpacing.sectionLarge,
                      height: AppSpacing.sectionLarge,
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? AppColors.surfaceNeutral
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.folder_open,
                        size: AppSpacing.xl,
                        color: _isHovered ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: _isHovered ? AppColors.primary : Colors.transparent,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.project.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Cormorant Garamond',
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    widget.pathBadge,
                    widget.metaChip,
                  ],
                ),
                const Spacer(),
                Text(
                  widget.project.vaultPath,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
