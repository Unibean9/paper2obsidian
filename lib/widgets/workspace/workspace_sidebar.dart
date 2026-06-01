import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/paper_metadata.dart';
import '../../models/zotero_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/panel_container.dart';
import '../../widgets/workspace/sidebar_active_paper_box.dart';
import '../../widgets/workspace/sidebar_status_box.dart';
import '../../widgets/workspace/upload_zone.dart';
import '../../widgets/workspace/metadata_tab.dart';
import '../../widgets/workspace/citations_tab.dart';
import '../../widgets/workspace/library_tab.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.selectedPdf,
    required this.vaultPath,
    required this.isLoading,
    required this.paperStatus,
    required this.paperCitations,
    required this.progressLogs,
    required this.statusText,
    required this.isZoteroConfigured,
    required this.isFromZotero,
    required this.activeCollectionKey,
    required this.pendingZoteroItemKey,
    required this.workspaceSection,
    required this.titleCtrl,
    required this.authorsCtrl,
    required this.venueCtrl,
    required this.yearCtrl,
    required this.doiCtrl,
    required this.keywordsCtrl,
    required this.datasetCtrl,
    required this.problemCtrl,
    required this.limitationCtrl,
    required this.summaryCtrl,
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
    required this.onCollapse,
    required this.onCancel,
  });

  final File? selectedPdf;
  final String vaultPath;
  final bool isLoading;
  final PaperStatus paperStatus;
  final List<String> paperCitations;
  final List<String> progressLogs;
  final String statusText;
  final bool isZoteroConfigured;
  final bool isFromZotero;
  final String? activeCollectionKey;
  final String? pendingZoteroItemKey;
  final int workspaceSection;
  final TextEditingController titleCtrl;
  final TextEditingController authorsCtrl;
  final TextEditingController venueCtrl;
  final TextEditingController yearCtrl;
  final TextEditingController doiCtrl;
  final TextEditingController keywordsCtrl;
  final TextEditingController datasetCtrl;
  final TextEditingController problemCtrl;
  final TextEditingController limitationCtrl;
  final TextEditingController summaryCtrl;
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
  final VoidCallback onCollapse;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTitle = titleCtrl.text.trim().isNotEmpty
        ? titleCtrl.text.trim()
        : selectedPdf != null
            ? p.basename(selectedPdf!.path)
            : '';

    return PanelContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('WORKSPACE', style: theme.textTheme.titleSmall),
                    Tooltip(
                      message: 'Thu gọn workspace',
                      child: GestureDetector(
                        onTap: onCollapse,
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
                const SizedBox(height: AppSpacing.md),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
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
                const SizedBox(height: AppSpacing.lg),
                // Nút trích xuất và lưu
                if (selectedPdf != null) ...[
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
                          icon: Icons.save_alt,
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
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (isZoteroConfigured && selectedPdf != null) ...[
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
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text('PANELS', style: theme.textTheme.titleSmall),
          ),
          _buildHorizontalTabBar(context),
          const SizedBox(height: AppSpacing.xs),
          const Divider(height: 1),
          Expanded(child: _buildSidebarSectionContent()),
          if (progressLogs.isNotEmpty ||
              statusText != 'Ready') ...[
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

  Widget _buildDottedUploadZone() {
    return HoverUploadZone(
      onTap: isLoading ? null : onPickPdf,
      zoteroAvailable: isZoteroConfigured && activeCollectionKey != null,
      onZoteroTap: onImportZotero,
    );
  }

  Widget _buildHorizontalTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceNeutral,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabItem(context, 0, 'Metadata', Icons.auto_awesome)),
          Expanded(child: _buildTabItem(context, 1, 'Citations', Icons.format_quote)),
          Expanded(child: _buildTabItem(context, 2, 'Library', Icons.local_library)),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index, String label, IconData icon) {
    final isSelected = workspaceSection == index;
    return GestureDetector(
      onTap: () => onSectionChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md - 2),
          boxShadow: isSelected ? AppShadows.subtle : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
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
            icon: Icon(icon, size: 15),
            label: Text(label),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          );

    return SizedBox(width: double.infinity, child: child);
  }

  Widget _buildSidebarSectionContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.015, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(workspaceSection),
        child: _buildWorkspaceSectionView(),
      ),
    );
  }

  Widget _buildWorkspaceSectionView() {
    switch (workspaceSection) {
      case 0:
        return MetadataTab(
          titleCtrl: titleCtrl,
          authorsCtrl: authorsCtrl,
          venueCtrl: venueCtrl,
          yearCtrl: yearCtrl,
          doiCtrl: doiCtrl,
          keywordsCtrl: keywordsCtrl,
          datasetCtrl: datasetCtrl,
          problemCtrl: problemCtrl,
          limitationCtrl: limitationCtrl,
          summaryCtrl: summaryCtrl,
        );
      case 1:
        return CitationsTab(citations: paperCitations);
      case 2:
        return LibraryTab(
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
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
