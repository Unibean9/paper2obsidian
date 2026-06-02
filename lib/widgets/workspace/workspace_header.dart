import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.showHome,
    required this.activeProject,
    required this.onBackHome,
  });

  final bool showHome;
  final Project? activeProject;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    if (showHome || activeProject == null) {
      return _buildHomeHeader(context);
    }
    return _buildWorkspaceHeader(context, activeProject!);
  }

  Widget _buildHomeHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'hyperdatalab',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: 'Cormorant Garamond',
            letterSpacing: AppSpacing.xs,
            height: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'PAPER TO OBSIDIAN',
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 10,
            letterSpacing: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceHeader(BuildContext context, Project project) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium back arrow icon button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onBackHome,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // Home Breadcrumb
        InkWell(
          onTap: onBackHome,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'Home',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),

        // Slash Separator
        Text(
          '/',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w300,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),

        // Active Notebook / Project Name
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceNeutral,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                project.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // Sleek Path Badge
        Flexible(child: PathBadge(path: project.vaultPath)),
      ],
    );
  }
}

class PathBadge extends StatelessWidget {
  const PathBadge({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              path.trim().isNotEmpty ? path.trim() : 'Vault path not configured',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceHeaderActions extends StatelessWidget {
  const WorkspaceHeaderActions({
    super.key,
    required this.showHome,
    required this.hasProject,
    required this.isZoteroConfigured,
    required this.activeCollectionKey,
    required this.isLoading,
    required this.onNewProject,
    required this.onZotero,
    required this.onSettings,
  });

  final bool showHome;
  final bool hasProject;
  final bool isZoteroConfigured;
  final String? activeCollectionKey;
  final bool isLoading;
  final VoidCallback onNewProject;
  final VoidCallback onZotero;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1000;

    final actions = <Widget>[
      // New project button with premium capsule styling
      OutlinedButton.icon(
        onPressed: onNewProject,
        icon: const Icon(Icons.add, size: 15),
        label: Text(isCompact ? 'New' : 'New Project'),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    ];

    if (!showHome && hasProject) {
      actions.add(const SizedBox(width: AppSpacing.sm));

      // 3-Level smart status indicator configuration for Zotero
      final IconData zoteroIcon;
      final String zoteroLabel;
      final Color? zoteroColor;
      final Color? zoteroBg;
      final VoidCallback? zoteroPress;
      final bool zoteroReady = isZoteroConfigured && activeCollectionKey != null;

      if (!isZoteroConfigured) {
        // State 1: Unconfigured API
        zoteroIcon = Icons.cloud_off_outlined;
        zoteroLabel = isCompact ? 'Zotero' : 'Zotero (No API)';
        zoteroColor = AppColors.textMuted;
        zoteroBg = null;
        zoteroPress = onSettings; // Clicking opens settings to configure
      } else if (activeCollectionKey == null) {
        // State 2: Configured globally but no collection linked to this project
        zoteroIcon = Icons.sync_problem_outlined;
        zoteroLabel = isCompact ? 'Zotero' : 'Zotero (No Collection)';
        zoteroColor = AppColors.warning;
        zoteroBg = AppColors.warningSurface.withValues(alpha: 0.4);
        zoteroPress = onZotero; // Clicking opens project-specific key linking dialog
      } else {
        // State 3: Fully configured, linked, and ready
        zoteroIcon = Icons.cloud_done_outlined;
        zoteroLabel = isCompact ? 'Zotero' : 'Zotero Active';
        zoteroColor = AppColors.success;
        zoteroBg = AppColors.successSurface.withValues(alpha: 0.4);
        zoteroPress = isLoading ? null : onZotero;
      }

      actions.add(
        OutlinedButton.icon(
          onPressed: zoteroPress,
          icon: Icon(
            zoteroIcon,
            size: 15,
            color: zoteroColor,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                zoteroLabel,
                style: TextStyle(
                  color: zoteroPress == null ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (zoteroReady && !isCompact) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            backgroundColor: zoteroBg,
            side: BorderSide(
              color: zoteroColor != AppColors.textMuted
                  ? zoteroColor.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      );
    }

    actions.add(const SizedBox(width: AppSpacing.sm));
    actions.add(
      FilledButton.icon(
        onPressed: onSettings,
        icon: const Icon(Icons.settings_outlined, size: 16),
        label: const Text('Settings'),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textInverse,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }
}
