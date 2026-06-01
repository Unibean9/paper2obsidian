import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/paper_metadata.dart';
import '../../models/zotero_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../common/panel_container.dart';
import 'analysis_briefing_view.dart';
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

    // Map 2 (Library) to 0 (Sources) to fit the double tab layout
    final activeTab = workspaceSection == 2 ? 0 : workspaceSection;

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
          ),

          // Double Tab Switcher: Sources & Analysis
          _buildNotebookLMTabBar(context, activeTab),
          const Divider(height: 1),

          // Core Tab View Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(activeTab),
                child: activeTab == 0
                    ? _buildSourcesTabContent(context)
                    : _buildAnalysisTabContent(theme),
              ),
            ),
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

  // Modern pill-shaped tab bar matching Google NotebookLM layout
  Widget _buildNotebookLMTabBar(BuildContext context, int activeTab) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceNeutral,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNotebookLMTabItem(
              context: context,
              index: 0,
              label: 'Sources',
              icon: Icons.source_outlined,
              isSelected: activeTab == 0,
            ),
          ),
          Expanded(
            child: _buildNotebookLMTabItem(
              context: context,
              index: 1,
              label: 'Analysis',
              icon: Icons.auto_awesome_outlined,
              isSelected: activeTab == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookLMTabItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onSectionChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 1),
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
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
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
            label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
            label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
  Widget _buildAnalysisTabContent(ThemeData theme) {
    if (selectedPdf == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceNeutral,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 32,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No source active',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Please upload a document or select a paper from the Library below to view the analysis summary.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AnalysisBriefingView(
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
      citations: paperCitations,
    );
  }
}
