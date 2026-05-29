import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'panel_container.dart';

class PdfViewerPanel extends StatefulWidget {
  const PdfViewerPanel({
    super.key,
    required this.selectedPdf,
    required this.primaryColor,
  });

  final File? selectedPdf;
  final Color primaryColor;

  @override
  State<PdfViewerPanel> createState() => _PdfViewerPanelState();
}

class _PdfViewerPanelState extends State<PdfViewerPanel> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfInteractionMode _pdfInteractionMode = PdfInteractionMode.pan;

  @override
  Widget build(BuildContext context) {
    return PanelContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.visibility, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Document Preview',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.selectedPdf != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.highlight_alt,
                      color: _pdfInteractionMode == PdfInteractionMode.selection
                          ? widget.primaryColor
                          : Colors.grey.shade600,
                    ),
                    tooltip: 'Toggle Text Selection',
                    onPressed: () {
                      setState(() {
                        _pdfInteractionMode =
                            _pdfInteractionMode == PdfInteractionMode.pan
                            ? PdfInteractionMode.selection
                            : PdfInteractionMode.pan;
                      });
                    },
                  ),
                  const VerticalDivider(width: 20, indent: 8, endIndent: 8),
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    tooltip: 'Zoom Out',
                    onPressed: () => _pdfViewerController.zoomLevel =
                        (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    tooltip: 'Zoom In',
                    onPressed: () => _pdfViewerController.zoomLevel =
                        (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset Zoom',
                    onPressed: () => _pdfViewerController.zoomLevel = 1.0,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: widget.selectedPdf != null
                ? SfPdfViewer.file(
                    widget.selectedPdf!,
                    controller: _pdfViewerController,
                    interactionMode: _pdfInteractionMode,
                    enableTextSelection: true,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.find_in_page_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No PDF selected',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
