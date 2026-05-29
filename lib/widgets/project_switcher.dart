import 'package:flutter/material.dart';

import '../models/project.dart';

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
            label: const Text('New Project'),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: activeProject?.id,
                isExpanded: true,
                style: theme.textTheme.bodyMedium,
                icon: const Icon(Icons.expand_more, size: 18),
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
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 4),
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
}
