import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class ProjectSwitcher extends StatelessWidget {
  const ProjectSwitcher({
    super.key,
    required this.projects,
    required this.activeProject,
    required this.onSwitch,
    required this.onCreateProject,
    this.enabled = true,
  });

  final List<Project> projects;
  final Project? activeProject;
  final void Function(Project) onSwitch;
  final VoidCallback onCreateProject;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (projects.isEmpty)
          TextButton.icon(
            onPressed: enabled ? onCreateProject : null,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('NEW PROJECT'),
          )
        else
          Container(
            constraints: const BoxConstraints(maxWidth: AppSpacing.hero * 4),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.background,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: activeProject?.id,
                isExpanded: true,
                dropdownColor: AppColors.surfaceLight,
                style: theme.textTheme.labelLarge,
                icon: const Icon(Icons.expand_more, size: 18),
                selectedItemBuilder: (context) => projects
                    .map((p) => _buildProjectOption(context, p))
                    .toList(),
                onChanged: enabled
                    ? (id) {
                        if (id == null) return;
                        final project =
                            projects.where((p) => p.id == id).firstOrNull;
                        if (project != null) onSwitch(project);
                      }
                    : null,
                items: [
                  ...projects.map(
                    (p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: _buildProjectOption(context, p),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          onPressed: enabled ? onCreateProject : null,
          tooltip: 'New project',
          icon: const Icon(Icons.add_box_outlined, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _buildProjectOption(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final subtitle = project.vaultPath.isEmpty
        ? 'Vault path not configured'
        : project.vaultPath;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            project.name,
            style: theme.textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '-',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          flex: 3,
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
