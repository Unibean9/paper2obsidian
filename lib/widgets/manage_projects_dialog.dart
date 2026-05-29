import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/project_service.dart';

class ManageProjectsDialog extends StatefulWidget {
  const ManageProjectsDialog({
    super.key,
    required this.activeProjectId,
    required this.onProjectsChanged,
  });

  final String? activeProjectId;
  final VoidCallback onProjectsChanged;

  @override
  State<ManageProjectsDialog> createState() => _ManageProjectsDialogState();
}

class _ManageProjectsDialogState extends State<ManageProjectsDialog> {
  List<Project> _projects = [];

  @override
  void initState() {
    super.initState();
    _projects = List.from(ProjectService.instance.projects);
  }

  Future<void> _delete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
            'Delete "${project.name}"? This only removes the project entry — '
            'your vault files are not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ProjectService.instance.deleteProject(project.id);
    if (!mounted) return;
    setState(() =>
        _projects = List.from(ProjectService.instance.projects));
    widget.onProjectsChanged();
  }

  Future<void> _rename(Project project) async {
    final ctrl = TextEditingController(text: project.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty) return;
    await ProjectService.instance.updateProject(
        project.copyWith(name: newName));
    if (!mounted) return;
    setState(() =>
        _projects = List.from(ProjectService.instance.projects));
    widget.onProjectsChanged();
  }

  Future<void> _editCollectionKey(Project project) async {
    final ctrl = TextEditingController(
        text: project.zoteroCollectionKey ?? '');
    final newKey = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Collection Key — ${project.name}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Zotero Collection Key',
                  helperText: 'e.g. ABCD1234 — found in the Zotero URL',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    ctrl.dispose();
    if (newKey == null) return;
    final updated = project.copyWith(
      zoteroCollectionKey: newKey.isEmpty ? null : newKey,
    );
    await ProjectService.instance.updateProject(updated);
    if (!mounted) return;
    setState(() =>
        _projects = List.from(ProjectService.instance.projects));
    widget.onProjectsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Manage Projects',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: _projects.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No projects yet.')),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _projects.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final project = _projects[i];
                  final isActive =
                      project.id == widget.activeProjectId;
                  return ListTile(
                    leading: Icon(
                      Icons.folder_special,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    title: Text(
                      project.name,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      project.vaultPath,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit collection key',
                          icon: const Icon(Icons.link, size: 18),
                          onPressed: () => _editCollectionKey(project),
                        ),
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.drive_file_rename_outline,
                              size: 18),
                          onPressed: () => _rename(project),
                        ),
                        IconButton(
                          tooltip: isActive
                              ? 'Cannot delete active project'
                              : 'Delete',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: isActive
                                ? Colors.grey
                                : Colors.red.shade400,
                          ),
                          onPressed:
                              isActive ? null : () => _delete(project),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
