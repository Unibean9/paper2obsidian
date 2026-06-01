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
    final theme = Theme.of(context);
    final sortedProjects = List<Project>.from(projects)
      ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sectionLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header Title & Subtitle matching Google style
          Text(
            'My Workspaces',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'Cormorant Garamond',
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              fontSize: 32,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Access your personal Obsidian research vaults and manage active academic sources.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          // Grid View of Project Cards
          Expanded(
            child: sortedProjects.isEmpty
                ? _buildEmptyHomeState()
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: AppSpacing.hero * 3.8,
                      mainAxisExtent: AppSpacing.hero * 2.1,
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
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textInverse,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
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
    );
  }
}
