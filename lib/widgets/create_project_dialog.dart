import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../services/project_service.dart';
import '../utils/vault_access.dart';
import '../utils/desktop_file_helper.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key, this.onCreated});

  final void Function(Project project)? onCreated;

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameCtrl = TextEditingController();
  final _vaultCtrl = TextEditingController();
  final _collectionKeyCtrl = TextEditingController();

  String? _nameError;
  String? _vaultError;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vaultCtrl.dispose();
    _collectionKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final path = await VaultAccess.pickVaultWithWriteAccess(
      initialDirectory:
          _vaultCtrl.text.isNotEmpty ? _vaultCtrl.text : null,
    );
    if (path == null || path.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _vaultCtrl.text = p.normalize(path);
      _vaultError = null;
    });
  }

  bool _validate() {
    String? nameErr;
    String? vaultErr;

    if (_nameCtrl.text.trim().isEmpty) {
      nameErr = 'Project name is required.';
    }

    final vaultPath = _vaultCtrl.text.trim();
    if (vaultPath.isEmpty) {
      vaultErr = 'Vault folder is required.';
    } else if (!Directory(vaultPath).existsSync()) {
      vaultErr = 'Folder does not exist.';
    }

    setState(() {
      _nameError = nameErr;
      _vaultError = vaultErr;
    });
    return nameErr == null && vaultErr == null;
  }

  Future<void> _onSave() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);
    try {
      final collectionKey = _collectionKeyCtrl.text.trim();
      final project = await ProjectService.instance.createProject(
        name: _nameCtrl.text.trim(),
        vaultPath: p.normalize(_vaultCtrl.text.trim()),
        zoteroCollectionKey: collectionKey.isNotEmpty ? collectionKey : null,
      );
      if (!mounted) return;
      widget.onCreated?.call(project);
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New Project',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Project Name',
                  prefixIcon: const Icon(Icons.folder_special_outlined),
                  errorText: _nameError,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vaultCtrl,
                readOnly: VaultAccess.requiresPickerGrant,
                decoration: InputDecoration(
                  labelText: 'Obsidian Vault Path',
                  prefixIcon: const Icon(Icons.folder_outlined),
                  errorText: _vaultError,
                  suffixIcon: isDesktopPickerSupported
                      ? IconButton(
                          tooltip: 'Browse',
                          icon: const Icon(Icons.folder_open),
                          onPressed: _browse,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              TextField(
                controller: _collectionKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Zotero Collection Key (optional)',
                  prefixIcon: Icon(Icons.link_outlined),
                  helperText: 'e.g. ABCD1234 — find it in the Zotero URL',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
