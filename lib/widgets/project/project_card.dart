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
  });

  final Project project;
  final VoidCallback onTap;

  @override
  State<HoverProjectCard> createState() => _HoverProjectCardState();
}

class _HoverProjectCardState extends State<HoverProjectCard> {
  bool _isHovered = false;

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastOpened = _formatDate(widget.project.lastOpenedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _isHovered ? -6.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceLight : AppColors.surfaceNeutral.withValues(alpha: 0.5),
          border: Border.all(
            color: _isHovered ? AppColors.accent : AppColors.border,
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
                // Top Row: Premium Folder Icon + Hover Indicator Arrow
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: _isHovered ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.folder_open_outlined,
                        size: 20,
                        color: _isHovered ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Project Title
                Text(
                  widget.project.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Last Opened Metadata Row
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Opened $lastOpened',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),

                // Bottom Row: Clean Vault Path Link
                Row(
                  children: [
                    Icon(
                      Icons.link_outlined,
                      size: 12,
                      color: _isHovered ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.project.vaultPath.isNotEmpty
                            ? widget.project.vaultPath
                            : 'Vault path not configured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
