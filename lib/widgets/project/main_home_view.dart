import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../common/app_empty_state.dart';
import 'new_project_card.dart';
import 'project_card.dart';

class MainHomeView extends StatelessWidget {
  const MainHomeView({
    super.key,
    required this.projects,
    required this.onCreateProject,
    required this.onOpenProject,
  });

  final List<Project> projects;
  final VoidCallback onCreateProject;
  final ValueChanged<Project> onOpenProject;

  static const Duration _cardAnimationDuration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final sortedProjects = List<Project>.from(projects)
      ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sectionLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projects',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Open an existing workspace or create a new one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: sortedProjects.isEmpty
                ? _buildEmptyHomeState()
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: AppSpacing.hero * 3.8,
                      mainAxisExtent: AppSpacing.hero * 2.25,
                      mainAxisSpacing: AppSpacing.xl,
                      crossAxisSpacing: AppSpacing.xl,
                    ),
                    itemCount: sortedProjects.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildAnimatedProjectCard(
                          index: index,
                          child: _buildNewProjectCard(),
                        );
                      }
                      final project = sortedProjects[index - 1];
                      return _buildAnimatedProjectCard(
                        index: index,
                        child: _buildProjectCard(context, project),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedProjectCard({
    required int index,
    required Widget child,
  }) {
    final delayMs = (index * 45).clamp(0, 180);
    return TweenAnimationBuilder<double>(
      key: ValueKey('project-card-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: _cardAnimationDuration + Duration(milliseconds: delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, card) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * AppSpacing.xl),
            child: card,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildEmptyHomeState() {
    return AppEmptyState(
      icon: Icons.folder_special_outlined,
      title: 'No project yet',
      description: 'Create a project to get started.',
      action: FilledButton.icon(
        onPressed: onCreateProject,
        icon: const Icon(Icons.add),
        label: const Text('Create Project'),
      ),
      iconSize: AppSpacing.hero,
    );
  }

  Widget _buildNewProjectCard() {
    return HoverNewProjectCard(
      onTap: onCreateProject,
    );
  }

  Widget _buildProjectCard(BuildContext context, Project project) {
    return HoverProjectCard(
      project: project,
      onTap: () => onOpenProject(project),
      pathBadge: _buildPathBadge(context, project.vaultPath),
      metaChip: _buildMetaChip(context, _formatDate(project.lastOpenedAt)),
    );
  }

  Widget _buildPathBadge(BuildContext context, String path) {
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

  Widget _buildMetaChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
