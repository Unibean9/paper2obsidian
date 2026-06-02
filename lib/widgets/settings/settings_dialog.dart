import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../common/animated_dialog.dart';

import '../../config/env_config.dart';
import '../../services/project_service.dart';
import '../../services/zotero_service.dart';
import '../../utils/vault_access.dart';
import '../../utils/desktop_file_helper.dart';
import '../project/manage_projects_dialog.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.initialVaultPath,
    required this.onSave,
    this.onReindex,
    this.onZoteroApiKeyChanged,
    this.onProjectsChanged,
  });

  final String initialVaultPath;
  final Future<void> Function(String newPath) onSave;
  final Future<int> Function()? onReindex;
  final void Function(String apiKey)? onZoteroApiKeyChanged;
  final VoidCallback? onProjectsChanged;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _vaultCtrl;
  late final TextEditingController _zoteroKeyCtrl;

  String? _errorMessage;
  bool _isSaving = false;
  bool _isIndexing = false;
  String? _indexResult;
  String? _indexError;

  bool _isResolvingUserId = false;
  String? _resolveResult;
  String? _resolveError;
  bool _isSavingZotero = false;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _vaultCtrl = TextEditingController(text: widget.initialVaultPath);
    _zoteroKeyCtrl = TextEditingController();
    _scrollController = ScrollController();
    _loadZoteroKey();
  }

  Future<void> _loadZoteroKey() async {
    final key = await EnvConfig.getZoteroApiKey();
    if (mounted) _zoteroKeyCtrl.text = key;
  }

  @override
  void dispose() {
    _vaultCtrl.dispose();
    _zoteroKeyCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onBrowse() async {
    final String? path = await VaultAccess.pickVaultWithWriteAccess(
      initialDirectory: _vaultCtrl.text.isNotEmpty ? _vaultCtrl.text : null,
    );
    if (path == null || path.isEmpty) return;
    if (!await VaultAccess.canWriteToVault(path)) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Cannot write to this folder. Pick your Obsidian vault root.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _vaultCtrl.text = path;
      _errorMessage = null;
    });
  }

  Future<void> _onReindex() async {
    setState(() {
      _isIndexing = true;
      _indexResult = null;
      _indexError = null;
    });
    try {
      final count = await widget.onReindex!();
      if (mounted) setState(() => _indexResult = 'Vault indexed — $count papers');
    } catch (e) {
      if (mounted) setState(() => _indexError = 'Re-index failed: $e');
    } finally {
      if (mounted) setState(() => _isIndexing = false);
    }
  }

  Future<void> _onSave() async {
    final String newVault = p.normalize(_vaultCtrl.text.trim());
    if (newVault.isNotEmpty && !await VaultAccess.canWriteToVault(newVault)) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Cannot write to this folder. Check that the path exists and you have write permission.';
      });
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSave(newVault);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onSaveZoteroKey() async {
    setState(() => _isSavingZotero = true);
    try {
      final key = _zoteroKeyCtrl.text.trim();
      await EnvConfig.setZoteroApiKey(key);
      widget.onZoteroApiKeyChanged?.call(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zotero API key saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingZotero = false);
    }
  }

  Future<void> _onResolveUserId() async {
    setState(() {
      _isResolvingUserId = true;
      _resolveResult = null;
      _resolveError = null;
    });
    try {
      final apiKey = _zoteroKeyCtrl.text.trim();
      if (apiKey.isEmpty) {
        setState(() => _resolveError = 'Enter and save an API key first.');
        return;
      }
      final service = ZoteroService(apiKey: apiKey);
      final data = await service.resolveUserId();
      final userId = data['userID']?.toString();
      if (userId == null) {
        setState(() => _resolveError = 'Could not extract user ID from response.');
        return;
      }

      await EnvConfig.setResolvedZoteroUserId(userId);

      final access = data['access'] as Map<String, dynamic>?;
      final library = access?['library'] as Map<String, dynamic>?;
      final canWrite = library?['write'] == true || library?['write'] == 1;

      String msg = 'User ID: $userId';
      if (!canWrite) {
        msg += '\n⚠ This key has read-only access — Export to Zotero will be disabled.';
      }
      if (mounted) setState(() => _resolveResult = msg);
    } catch (e) {
      if (mounted) setState(() => _resolveError = 'Failed to resolve: $e');
    } finally {
      if (mounted) setState(() => _isResolvingUserId = false);
    }
  }

  void _openManageProjects() {
    showAnimatedDialog(
      context: context,
      child: ManageProjectsDialog(
        activeProjectId: ProjectService.instance.activeProject?.id,
        onProjectsChanged: () => widget.onProjectsChanged?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.pop(context);
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isSaving) _onSave();
        },
      },
      child: AlertDialog(
        title: const Text(
          'Preferences',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Vault path ──────────────────────────────────────────────
                    TextField(
                      controller: _vaultCtrl,
                      readOnly: VaultAccess.requiresPickerGrant,
                      decoration: InputDecoration(
                        labelText: 'Obsidian Vault Path',
                        prefixIcon: const Icon(Icons.folder_outlined),
                        suffixIcon: isDesktopPickerSupported
                            ? IconButton(
                                tooltip: 'Browse folder',
                                icon: const Icon(Icons.folder_open),
                                onPressed: _onBrowse,
                              )
                            : null,
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    if (isDesktopPickerSupported)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'On macOS/Windows, use Browse so the app has permission to read and write the vault.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // ── Re-index ─────────────────────────────────────────────────
                    if (widget.onReindex != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _isIndexing ? null : _onReindex,
                              icon: _isIndexing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 18),
                              label: const Text('Re-index Vault'),
                            ),
                          ),
                        ],
                      ),
                      if (_indexResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _indexResult!,
                            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                          ),
                        ),
                      if (_indexError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _indexError!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                          ),
                        ),
                    ],

                    // ── Projects ─────────────────────────────────────────────────
                    const Divider(height: 28),
                    const Text(
                      'Projects',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openManageProjects,
                        icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                        label: const Text('Manage Projects'),
                      ),
                    ),

                    // ── Zotero ───────────────────────────────────────────────────
                    const Divider(height: 28),
                    const Text(
                      'Zotero',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _zoteroKeyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Zotero API Key',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        helperText: 'Stored securely in Windows Credential Manager.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isSavingZotero ? null : _onSaveZoteroKey,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save API Key'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isResolvingUserId ? null : _onResolveUserId,
                            icon: _isResolvingUserId
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.person_search_outlined, size: 18),
                            label: const Text('Resolve User ID'),
                          ),
                        ),
                      ],
                    ),
                    if (_resolveResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _resolveResult!,
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                        ),
                      ),
                    if (_resolveError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _resolveError!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                  ],
                ),
              ),
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
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
