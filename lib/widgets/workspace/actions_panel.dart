import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/paper_metadata.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../common/panel_container.dart';

class ActionsPanel extends StatefulWidget {
  const ActionsPanel({
    super.key,
    required this.paperStatus,
    required this.isLoading,
    required this.vaultPath,
    required this.selectedPdf,
    required this.progressLogs,
    required this.statusText,
    required this.onPickPdf,
    required this.onExtract,
    required this.onDiscard,
    required this.onSaveToObsidian,
    required this.onCancel,
    this.isZoteroConfigured = false,
    this.activeCollectionKey,
    this.onImportFromZotero,
    this.onExportFromZotero,
    this.isFromZotero = false,
  });

  final PaperStatus paperStatus;
  final bool isLoading;
  final String vaultPath;
  final File? selectedPdf;
  final List<String> progressLogs;
  final String statusText;
  final VoidCallback onPickPdf;
  final VoidCallback onExtract;
  final VoidCallback onDiscard;
  final VoidCallback onSaveToObsidian;
  final VoidCallback onCancel;

  final bool isZoteroConfigured;
  final String? activeCollectionKey;
  final VoidCallback? onImportFromZotero;
  final VoidCallback? onExportFromZotero;
  final bool isFromZotero;

  @override
  State<ActionsPanel> createState() => _ActionsPanelState();
}

class _ActionsPanelState extends State<ActionsPanel> {
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void dispose() {
    _logScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ActionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progressLogs.length != oldWidget.progressLogs.length) {
      _scrollLogsToBottom();
    }
  }

  void _scrollLogsToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_logScrollCtrl.hasClients) return;
      _logScrollCtrl.animateTo(
        _logScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExtracting = widget.paperStatus == PaperStatus.extracting;
    final isUploaded = widget.paperStatus == PaperStatus.uploaded;
    final isError = widget.paperStatus == PaperStatus.error;
    final isDone = widget.paperStatus == PaperStatus.done;
    final isBusy = isExtracting || widget.isLoading;

    final statusLower = widget.statusText.toLowerCase();
    final isSuccess =
        statusLower.contains('success') || statusLower.contains('thành công');
    final isStatusError =
        statusLower.contains('error') || statusLower.contains('lỗi');

    final logBackground = isSuccess
        ? AppColors.successSurface
        : isStatusError
        ? AppColors.errorSurface
        : isBusy
        ? AppColors.surfaceNeutral
        : AppColors.infoSurface;
    final logBorder = isSuccess
        ? AppColors.success
        : isStatusError
        ? AppColors.error
        : isBusy
        ? AppColors.primary
        : AppColors.border;

    return PanelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIONS', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : widget.onPickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('SELECT PAPER'),
            ),
          ),
          if (isUploaded || isError) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onExtract,
                icon: const Icon(Icons.auto_awesome),
                label: Text(isError ? 'RETRY EXTRACTION' : 'EXTRACT PAPER'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: widget.onDiscard,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error,
                ),
                label: Text(
                  'DISCARD',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: logBackground,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: logBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXTRACTION PROGRESS',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView.builder(
                      controller: _logScrollCtrl,
                      itemCount: widget.progressLogs.length,
                      itemBuilder: (context, index) {
                        final log = widget.progressLogs[index];
                        var textColor = AppColors.textPrimary;

                        if (log.startsWith('✅') || log.startsWith('🎉')) {
                          textColor = AppColors.success;
                        } else if (log.startsWith('⚠️')) {
                          textColor = AppColors.warning;
                        } else if (log.startsWith('❌')) {
                          textColor = AppColors.error;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            log,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (isExtracting) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(
                      minHeight: AppSpacing.xs,
                      color: AppColors.primary,
                      backgroundColor: AppColors.border,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          size: 18,
                          color: AppColors.error,
                        ),
                        label: Text(
                          'CANCEL',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (widget.isLoading && !isExtracting) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(
                      minHeight: AppSpacing.xs,
                      color: AppColors.primary,
                      backgroundColor: AppColors.border,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.isZoteroConfigured) ...[
            _ZoteroActionButton(
              icon: Icons.cloud_download_outlined,
              label: 'IMPORT FROM ZOTERO',
              tooltip: widget.activeCollectionKey == null
                  ? 'Set a Zotero collection key for this project first'
                  : null,
              enabled: !isBusy && widget.activeCollectionKey != null,
              onTap: widget.onImportFromZotero,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ZoteroActionButton(
              icon: Icons.cloud_upload_outlined,
              label: 'EXPORT TO ZOTERO',
              tooltip: widget.isFromZotero
                  ? 'This paper was imported from Zotero — export disabled'
                  : widget.activeCollectionKey == null
                  ? 'Set a Zotero collection key for this project first'
                  : (!isDone ? 'Extract a paper first' : null),
              enabled: isDone &&
                  !isBusy &&
                  !widget.isFromZotero &&
                  widget.activeCollectionKey != null,
              onTap: widget.onExportFromZotero,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (!isDone || widget.isLoading || widget.vaultPath.trim().isEmpty)
                  ? null
                  : widget.onSaveToObsidian,
              icon: const Icon(Icons.save_alt),
              label: const Text('SAVE TO OBSIDIAN'),
            ),
          ),
          if (widget.vaultPath.trim().isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set vault path in Settings (use Browse on macOS).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoteroActionButton extends StatelessWidget {
  const _ZoteroActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );

    if (tooltip != null && !enabled) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
