import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../utils/vault_access.dart';
import '../utils/desktop_file_helper.dart';

/// Settings dialog for configuring the Obsidian vault path.
/// Extracted from `_showSettingsDialog` in the original main.dart.
///
/// Error messages are displayed as inline [Text] widgets inside the dialog body —
/// NOT via ScaffoldMessenger, because the dialog's BuildContext has no Scaffold ancestor.
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => SettingsDialog(
///     initialVaultPath: vaultPath,
///     onSave: (newPath) async {
///       setState(() => vaultPath = newPath);
///       await _saveSettings();
///     },
///   ),
/// );
/// ```
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.initialVaultPath,
    required this.onSave,
    this.onReindex,
  });

  final String initialVaultPath;

  /// Called with the validated new vault path when the user taps "Save Changes".
  final Future<void> Function(String newPath) onSave;

  /// Called when the user taps "Re-index Vault". Returns the paper count on
  /// success. Pass `null` to hide the button (e.g., when no vault is set).
  final Future<int> Function()? onReindex;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _vaultCtrl;

  /// Inline error message rendered below the vault path field.
  /// Using inline Text instead of ScaffoldMessenger — the dialog context
  /// has no Scaffold ancestor so SnackBars would throw.
  String? _errorMessage;
  bool _isSaving = false;

  // Re-index state
  bool _isIndexing = false;
  String? _indexResult;
  String? _indexError;

  @override
  void initState() {
    super.initState();
    _vaultCtrl = TextEditingController(text: widget.initialVaultPath);
  }

  @override
  void dispose() {
    _vaultCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Preferences',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              // Error display pattern: inline Text, never ScaffoldMessenger
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

              // Re-index Vault section — only shown when callback is provided
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
          child: const Text('Save Changes'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
