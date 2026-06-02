import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../config/env_config.dart';
import '../../models/project.dart';
import '../../services/project_service.dart';
import '../../services/zotero_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/vault_access.dart';
import '../../utils/desktop_file_helper.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.initialVaultPath,
    required this.onSave,
    this.onReindex,
    this.onZoteroApiKeyChanged,
    this.onProjectsChanged,
    this.onBackHome,
  });

  final String initialVaultPath;
  final Future<void> Function(String newPath) onSave;
  final Future<int> Function()? onReindex;
  final void Function(String apiKey)? onZoteroApiKeyChanged;
  final VoidCallback? onProjectsChanged;
  final VoidCallback? onBackHome;

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

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _vaultCtrl = TextEditingController(text: widget.initialVaultPath);
    _zoteroKeyCtrl = TextEditingController();
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
        _errorMessage = 'Cannot write to this folder. Pick your Obsidian vault root.';
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
    if (widget.onReindex == null) return;
    setState(() {
      _isIndexing = true;
      _indexResult = null;
      _indexError = null;
    });
    try {
      final count = await widget.onReindex!();
      if (mounted) {
        setState(() => _indexResult = 'Vault indexed — $count papers.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _indexError = 'Re-index failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isIndexing = false);
    }
  }

  Future<void> _onSave() async {
    final String newVault = p.normalize(_vaultCtrl.text.trim());
    if (newVault.isNotEmpty && !await VaultAccess.canWriteToVault(newVault)) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Cannot write to this folder. Check write permissions.';
      });
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSave(newVault);
      if (mounted) {
        Navigator.pop(context);
      }
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        final screenWidth = MediaQuery.of(context).size.width;
        const toastWidth = 260.0;
        final sideMargin = (screenWidth - toastWidth) / 2;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 90,
              left: sideMargin,
              right: sideMargin,
            ),
            content: const Text(
              'Zotero API key saved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
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

      String msg = 'User ID resolved: $userId';
      if (!canWrite) {
        msg += '\n⚠️ Key has read-only access — Export to Zotero will be disabled.';
      }
      if (mounted) setState(() => _resolveResult = msg);
    } catch (e) {
      if (mounted) setState(() => _resolveError = 'Failed to resolve: $e');
    } finally {
      if (mounted) setState(() => _isResolvingUserId = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final activeProject = ProjectService.instance.activeProject;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 720;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.pop(context);
        },
      },
      child: Dialog(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 960, // Increased from 850 for a more spacious feel
            maxHeight: 640, // Increased from 580
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: isDesktop ? _buildDesktopLayout(activeProject) : _buildMobileLayout(activeProject),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Project? activeProject) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar with Warm Neutral Background
        Container(
          width: 230,
          color: AppColors.surfaceNeutral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: AppColors.accent, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Settings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'Cormorant Garamond',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              if (activeProject != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onBackHome?.call();
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ACTIVE PROJECT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.home_outlined, size: 10, color: AppColors.textMuted),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            activeProject.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _buildSidebarItem(0, Icons.folder_outlined, 'Obsidian Vault'),
              _buildSidebarItem(1, Icons.sync, 'Zotero Integration'),
            ],
          ),
        ),
        // Content Area on the right
        Expanded(
          child: Container(
            color: AppColors.surfaceLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: _buildSelectedTabContent(),
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Project? activeProject) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.surfaceNeutral,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: AppColors.accent, size: 16),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Settings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMobileTabItem(0, 'Obsidian'),
                    _buildMobileTabItem(1, 'Zotero'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.surfaceLight,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _buildSelectedTabContent(),
            ),
          ),
        ),
        _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceLight : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceNeutral,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: _isSaving ? null : _onSave,
            child: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildObsidianSection();
      case 1:
        return _buildZoteroSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Cormorant Garamond',
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(color: AppColors.border),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildObsidianSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Obsidian Vault & Indexing', 'Configure your Obsidian vault path and synchronization settings.'),
        
        Card(
          color: AppColors.surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Obsidian Vault Directory',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _vaultCtrl,
                  readOnly: VaultAccess.requiresPickerGrant,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Obsidian Vault Path',
                    prefixIcon: const Icon(Icons.folder_outlined, size: 18),
                    suffixIcon: isDesktopPickerSupported
                        ? IconButton(
                            tooltip: 'Browse',
                            icon: const Icon(Icons.folder_open, size: 18),
                            onPressed: _onBrowse,
                          )
                        : null,
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 11),
                    ),
                  ),
                if (isDesktopPickerSupported)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'On macOS/Windows, please use Browse to ensure write permissions to your vault.',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        if (widget.onReindex != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            color: AppColors.surfaceLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Re-index Vault',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Update the search index with all papers in your Obsidian "Papers" directory.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _isIndexing ? null : _onReindex,
                    icon: _isIndexing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.refresh, size: 14),
                    label: const Text('Index Vault Now'),
                  ),
                  if (_indexResult != null)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.successSurface,
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _indexResult!,
                              style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_indexError != null)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _indexError!,
                              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildZoteroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Zotero Integration', 'Connect your Zotero account to import and export papers directly.'),
        
        Card(
          color: AppColors.surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zotero Credentials',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _zoteroKeyCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                    helperText: 'API keys are stored securely in your system\'s local credentials.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSavingZotero ? null : _onSaveZoteroKey,
                        icon: const Icon(Icons.save_outlined, size: 14),
                        label: const Text('Save API Key'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isResolvingUserId ? null : _onResolveUserId,
                        icon: _isResolvingUserId
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.person_search_outlined, size: 14),
                        label: const Text('Verify User ID'),
                      ),
                    ),
                  ],
                ),
                if (_resolveResult != null)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _resolveResult!,
                            style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_resolveError != null)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _resolveError!,
                            style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }


}
