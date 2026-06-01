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
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }

  Widget _buildWorkspaceHeader(BuildContext context, Project project) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onBackHome,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back'),
        ),
        const SizedBox(width: AppSpacing.md),
        InkWell(
          onTap: onBackHome,
          child: Text(
            'Home',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          project.name,
          style: theme.textTheme.titleLarge?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
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
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceNeutral,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        path.trim().isNotEmpty ? path.trim() : 'Vault path not configured',
        style: theme.textTheme.labelSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: onNewProject,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('NEW'),
      ),
    ];

    if (!showHome && hasProject) {
      actions.add(const SizedBox(width: AppSpacing.sm));
      actions.add(
        OutlinedButton.icon(
          onPressed: isZoteroConfigured && activeCollectionKey != null && !isLoading
              ? onZotero
              : null,
          icon: const Icon(Icons.link_outlined, size: 16),
          label: const Text('ZOTERO'),
        ),
      );
    }

    actions.add(const SizedBox(width: AppSpacing.sm));
    actions.add(
      FilledButton.icon(
        onPressed: onSettings,
        icon: const Icon(Icons.settings, size: 18),
        label: const Text('SETTINGS'),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }
}
