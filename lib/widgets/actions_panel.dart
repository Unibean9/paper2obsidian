import 'dart:io';

import 'package:flutter/material.dart';

import '../models/paper_metadata.dart';
import 'panel_container.dart';

/// Column 1 — Actions panel: PDF picker, extraction progress log, and Save button.
///
/// Renders different action buttons based on [paperStatus]:
/// - [PaperStatus.idle]       → "Select Paper" only
/// - [PaperStatus.uploaded]   → "Extract Paper" (primary) + "Discard" (text)
/// - [PaperStatus.extracting] → spinner, progress log, Cancel button
/// - [PaperStatus.done]       → "Save to Obsidian" enabled
/// - [PaperStatus.error]      → "Extract Paper" retry + "Discard"
///
/// [isLoading] covers the Save-to-Obsidian async operation only, not extraction.
class ActionsPanel extends StatefulWidget {
  const ActionsPanel({
    super.key,
    required this.paperStatus,
    required this.isLoading,
    required this.vaultPath,
    required this.selectedPdf,
    required this.progressLogs,
    required this.statusText,
    required this.primaryColor,
    required this.onPickPdf,
    required this.onExtract,
    required this.onDiscard,
    required this.onSaveToObsidian,
    required this.onCancel,
  });

  /// Current paper workflow status (drives conditional button rendering).
  final PaperStatus paperStatus;

  /// True only during the Save-to-Obsidian async operation (not extraction).
  final bool isLoading;
  final String vaultPath;
  final File? selectedPdf;
  final List<String> progressLogs;
  final String statusText;
  final Color primaryColor;
  final VoidCallback onPickPdf;

  /// Triggered when the user clicks "Extract Paper" after staging a file.
  final VoidCallback onExtract;

  /// Triggered when the user clicks "Discard" to remove the staged file.
  final VoidCallback onDiscard;
  final VoidCallback onSaveToObsidian;
  final VoidCallback onCancel;

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
    // Auto-scroll to bottom when new log entries arrive.
    if (widget.progressLogs.length != oldWidget.progressLogs.length) {
      _scrollLogsToBottom();
    }
  }

  void _scrollLogsToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isExtracting = widget.paperStatus == PaperStatus.extracting;
    final bool isUploaded = widget.paperStatus == PaperStatus.uploaded;
    final bool isError = widget.paperStatus == PaperStatus.error;
    final bool isDone = widget.paperStatus == PaperStatus.done;
    final bool isBusy = isExtracting || widget.isLoading;

    final String textLower = widget.statusText.toLowerCase();
    final bool isSuccess =
        textLower.contains('success') || textLower.contains('thành công');
    final bool isStatusError =
        textLower.contains('error') || textLower.contains('lỗi');

    return PanelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // ── Select Paper button (always visible, disabled when busy)
          FilledButton.icon(
            onPressed: isBusy ? null : widget.onPickPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Select Paper (PDF)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // ── Extract + Discard buttons (uploaded or error state)
          if (isUploaded || isError) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onExtract,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                isError ? 'Retry Extraction' : 'Extract Paper',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: widget.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onDiscard,
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
              label: Text(
                'Discard',
                style: TextStyle(color: Colors.red.shade400),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Progress log area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccess
                    ? Colors.green.shade50
                    : (isStatusError
                          ? Colors.red.shade50
                          : (isBusy
                                ? widget.primaryColor.withValues(alpha: 0.05)
                                : Colors.grey.shade100)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuccess
                      ? Colors.green.shade200
                      : (isStatusError
                            ? Colors.red.shade200
                            : (isBusy
                                  ? widget.primaryColor.withValues(alpha: 0.3)
                                  : Colors.transparent)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extraction Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: _logScrollCtrl,
                      itemCount: widget.progressLogs.length,
                      itemBuilder: (context, index) {
                        final String log = widget.progressLogs[index];
                        Color textColor = Colors.black87;
                        if (log.startsWith('✅') || log.startsWith('🎉')) {
                          textColor = Colors.green.shade700;
                        }
                        if (log.startsWith('⚠️')) {
                          textColor = Colors.orange.shade800;
                        }
                        if (log.startsWith('❌')) {
                          textColor = Colors.red.shade700;
                        }
                        if (log.startsWith('⏳')) {
                          textColor = widget.primaryColor;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Progress bar and Cancel — only during extraction
                  if (isExtracting) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(4),
                      color: widget.primaryColor,
                      backgroundColor:
                          widget.primaryColor.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          size: 18,
                        ),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade500,
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                    ),
                  ],

                  // Spinner during save-to-obsidian
                  if (widget.isLoading && !isExtracting) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(4),
                      color: widget.primaryColor,
                      backgroundColor:
                          widget.primaryColor.withValues(alpha: 0.1),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Save to Obsidian button — only enabled when done and not saving
          FilledButton.icon(
            onPressed: (!isDone || widget.isLoading || widget.vaultPath.trim().isEmpty)
                ? null
                : widget.onSaveToObsidian,
            icon: const Icon(Icons.save_alt),
            label: const Text(
              'Save to Obsidian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 64),
              backgroundColor: widget.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          if (widget.vaultPath.trim().isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Set vault path in Settings (use Browse on macOS).',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
        ],
      ),
    );
  }
}
