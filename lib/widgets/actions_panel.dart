import 'dart:io';

import 'package:flutter/material.dart';

import 'panel_container.dart';

/// Column 1 — Actions panel: PDF picker, extraction progress log, and Save button.
/// Owns a ScrollController for auto-scrolling the log list (Bucket C).
class ActionsPanel extends StatefulWidget {
  const ActionsPanel({
    super.key,
    required this.isLoading,
    required this.vaultPath,
    required this.selectedPdf,
    required this.progressLogs,
    required this.statusText,
    required this.primaryColor,
    required this.onPickPdf,
    required this.onSaveToObsidian,
    required this.onCancel,
  });

  final bool isLoading;
  final String vaultPath;
  final File? selectedPdf;
  final List<String> progressLogs;
  final String statusText;
  final Color primaryColor;
  final VoidCallback onPickPdf;
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
    final String textLower = widget.statusText.toLowerCase();
    final bool isSuccess =
        textLower.contains('success') || textLower.contains('thành công');
    final bool isError =
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

          // Nút chọn file PDF
          FilledButton.icon(
            onPressed: widget.isLoading ? null : widget.onPickPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Select Paper (PDF)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Khu vực log tiến trình trích xuất
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccess
                    ? Colors.green.shade50
                    : (isError
                          ? Colors.red.shade50
                          : (widget.isLoading
                                ? widget.primaryColor.withValues(alpha: 0.05)
                                : Colors.grey.shade100)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuccess
                      ? Colors.green.shade200
                      : (isError
                            ? Colors.red.shade200
                            : (widget.isLoading
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

                  // Thanh tiến trình và nút Cancel khi đang loading
                  if (widget.isLoading) ...[
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nút Save to Obsidian
          FilledButton.icon(
            onPressed: (widget.selectedPdf == null ||
                    widget.isLoading ||
                    widget.vaultPath.trim().isEmpty)
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
