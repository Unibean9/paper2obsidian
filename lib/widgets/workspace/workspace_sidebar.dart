import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/paper_metadata.dart';
import '../../models/zotero_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../common/panel_container.dart';
import 'library_tab.dart';
import 'sidebar_active_paper_box.dart';
import 'sidebar_status_box.dart';
import 'upload_zone.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.selectedPdf,
    required this.vaultPath,
    required this.isLoading,
    required this.paperStatus,
    required this.progressLogs,
    required this.statusText,
    required this.isZoteroConfigured,
    required this.isFromZotero,
    required this.activeCollectionKey,
    required this.pendingZoteroItemKey,
    required this.workspaceSection,
    required this.titleCtrl,
    required this.libraryTabKey,
    required this.onDiscard,
    required this.onPickPdf,
    required this.onExtract,
    required this.onSave,
    required this.onImportZotero,
    required this.onExportZotero,
    required this.onOpenPaperFromLibrary,
    required this.loadLibrary,
    required this.loadZoteroCollection,
    required this.onImportZoteroItem,
    required this.onSectionChanged,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onSettings,
    required this.onCancel,
  });

  final File? selectedPdf;
  final String vaultPath;
  final bool isLoading;
  final PaperStatus paperStatus;
  final List<String> progressLogs;
  final String statusText;
  final bool isZoteroConfigured;
  final bool isFromZotero;
  final String? activeCollectionKey;
  final String? pendingZoteroItemKey;
  final int workspaceSection;
  final TextEditingController titleCtrl;
  final GlobalKey<LibraryTabState> libraryTabKey;
  final VoidCallback onDiscard;
  final VoidCallback onPickPdf;
  final VoidCallback onExtract;
  final VoidCallback onSave;
  final VoidCallback onImportZotero;
  final VoidCallback onExportZotero;
  final Future<void> Function(String mdPath) onOpenPaperFromLibrary;
  final Future<List<Map<String, String>>> Function() loadLibrary;
  final Future<List<({ZoteroItem item, bool isLocal})>> Function(String collectionKey)? loadZoteroCollection;
  final Future<void> Function(ZoteroItem item)? onImportZoteroItem;
  final ValueChanged<int> onSectionChanged;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onSettings;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _buildMiniSidebar(context);
    }
    final theme = Theme.of(context);

    return PanelContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header with collapse button
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WORKSPACE',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                Tooltip(
                  message: 'Collapse workspace',
                  child: GestureDetector(
                    onTap: onToggleCollapse,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        Icons.keyboard_double_arrow_left,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),

          // Core Content
          Expanded(
            child: _buildSourcesTabContent(context),
          ),

          // Sticky status logs box if extracting or status loading
          if (progressLogs.isNotEmpty || statusText != 'Ready') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SidebarStatusBox(
                statusText: statusText,
                progressLogs: progressLogs,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 1: SOURCES TAB CONTENT ---
  Widget _buildSourcesTabContent(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTitle = titleCtrl.text.trim().isNotEmpty
        ? titleCtrl.text.trim()
        : selectedPdf != null
            ? p.basename(selectedPdf!.path)
            : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upper section: Upload zone or Active paper box
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                selectedPdf == null ? 'ADD SOURCE' : 'ACTIVE SOURCE',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selectedPdf == null
                    ? _buildDottedUploadZone()
                    : SidebarActivePaperBox(
                        title: selectedTitle,
                        vaultPath: vaultPath,
                        isLoading: isLoading,
                        onDiscard: onDiscard,
                        onChange: onPickPdf,
                      ),
              ),

              // Action buttons below Active Paper Box
              if (selectedPdf != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildSidebarActionButton(
                        icon: paperStatus == PaperStatus.extracting
                            ? Icons.stop_circle_outlined
                            : Icons.auto_awesome,
                        label: paperStatus == PaperStatus.extracting
                            ? 'Cancel'
                            : 'Extract AI',
                        onPressed: paperStatus == PaperStatus.extracting
                            ? onCancel
                            : (isLoading ? null : onExtract),
                        filled: paperStatus == PaperStatus.uploaded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildSidebarActionButton(
                        icon: Icons.save_alt_outlined,
                        label: 'Save Obsidian',
                        onPressed: paperStatus == PaperStatus.done &&
                                !isLoading &&
                                vaultPath.trim().isNotEmpty
                            ? onSave
                            : null,
                        filled: paperStatus == PaperStatus.done,
                      ),
                    ),
                  ],
                ),
                if (isZoteroConfigured) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSidebarActionButton(
                          icon: Icons.cloud_download_outlined,
                          label: 'Zotero Import',
                          onPressed: !isLoading && activeCollectionKey != null
                              ? onImportZotero
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _buildSidebarActionButton(
                          icon: Icons.cloud_upload_outlined,
                          label: 'Zotero Export',
                          onPressed: paperStatus == PaperStatus.done &&
                                  !isLoading &&
                                  !isFromZotero &&
                                  activeCollectionKey != null
                              ? onExportZotero
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        // Lower section: LibraryTab (All Sources list)
        Expanded(
          child: Container(
            color: AppColors.background.withValues(alpha: 0.1),
            child: LibraryTab(
              key: libraryTabKey,
              vaultPath: vaultPath,
              onOpenPaper: onOpenPaperFromLibrary,
              loadLibrary: loadLibrary,
              isZoteroConfigured: isZoteroConfigured,
              activeCollectionKey: activeCollectionKey,
              loadZoteroCollection: activeCollectionKey != null
                  ? loadZoteroCollection
                  : null,
              onImportZoteroItem: onImportZoteroItem,
              pendingZoteroItemKey: pendingZoteroItemKey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDottedUploadZone() {
    return HoverUploadZone(
      onTap: isLoading ? null : onPickPdf,
      zoteroAvailable: isZoteroConfigured && activeCollectionKey != null,
      onZoteroTap: onImportZotero,
    );
  }

  Widget _buildSidebarActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    final child = filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 14),
            label: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textInverse,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 14),
            label: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          );

    return SizedBox(width: double.infinity, child: child);
  }

  // --- TAB 2: ANALYSIS TAB CONTENT ---
  // (Analysis briefing view moved to Right Sidebar - AI Chat assistant panel)

  Widget _buildMiniSidebar(BuildContext context) {
    return PanelContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Toggle button (keyboard_double_arrow_right)
          Tooltip(
            message: 'Expand Workspace',
            child: _buildMiniIconBtn(
              icon: Icons.keyboard_double_arrow_right,
              onTap: onToggleCollapse,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: AppSpacing.md),

          // 1. Sources Tab Icon
          Tooltip(
            message: 'Sources',
            child: _buildMiniIconBtn(
              icon: Icons.source_outlined,
              isSelected: workspaceSection == 0,
              onTap: () {
                onSectionChanged(0);
                if (isCollapsed) {
                  onToggleCollapse();
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Library Tab Icon
          Tooltip(
            message: 'Library',
            child: _buildMiniIconBtn(
              icon: Icons.library_books_outlined,
              isSelected: workspaceSection == 2,
              onTap: () {
                onSectionChanged(2);
                if (isCollapsed) {
                  onToggleCollapse();
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: AppSpacing.md),

          // 3. Add Source Button
          Tooltip(
            message: 'Add Source (PDF)',
            child: _buildMiniIconBtn(
              icon: Icons.add_box_outlined,
              onTap: isLoading ? null : onPickPdf,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 4. Save Obsidian Button
          Tooltip(
            message: 'Save to Obsidian',
            child: _buildMiniIconBtn(
              icon: Icons.save_alt_outlined,
              onTap: paperStatus == PaperStatus.done &&
                      !isLoading &&
                      vaultPath.trim().isNotEmpty
                  ? onSave
                  : null,
              isSelected: paperStatus == PaperStatus.done,
            ),
          ),

          const Spacer(),

          // 5. Settings Button
          Tooltip(
            message: 'Settings',
            child: _buildMiniIconBtn(
              icon: Icons.settings_outlined,
              onTap: onSettings,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildMiniIconBtn({
    required IconData icon,
    required VoidCallback? onTap,
    bool isSelected = false,
    Color? color,
  }) {
    final baseColor = color ?? (isSelected ? AppColors.accent : AppColors.textSecondary);
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected ? AppColors.border : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.border : baseColor,
          ),
        ),
      ),
    );
  }
}
