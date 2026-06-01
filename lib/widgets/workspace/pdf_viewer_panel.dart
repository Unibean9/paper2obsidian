import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../common/app_empty_state.dart';
import '../common/panel_container.dart';

class PdfViewerPanel extends StatefulWidget {
  const PdfViewerPanel({super.key, required this.selectedPdf});

  final File? selectedPdf;

  @override
  State<PdfViewerPanel> createState() => _PdfViewerPanelState();
}

class _PdfViewerPanelState extends State<PdfViewerPanel> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  PdfInteractionMode _pdfInteractionMode = PdfInteractionMode.pan;

  // Document states
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showSearchBar = false;

  // Controller for stable page jump input
  final TextEditingController _pageController = TextEditingController();

  // Text search states
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  final FocusNode _searchFocusNode = FocusNode();

  // Symmetrical Dimensions for Floating Widgets
  static const double _floatingWidgetWidth = 330.0;
  static const double _floatingWidgetHeight = 48.0; // Increased from 44 to 48 for a premium look & feel

  @override
  void initState() {
    super.initState();
    _pageController.text = '$_currentPage';
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchCompleted);
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfViewerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPdf != widget.selectedPdf) {
      _closeSearch();
      _currentPage = 1;
      _totalPages = 0;
      _pageController.text = '1';
    }
  }

  void _onSearchCompleted() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to update search match count on UI
      });
      // Maintain focus on search field if it gets hijacked by the viewer/layout rebuilds
      if (!_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
    }
  }

  void _closeSearch() {
    _searchResult?.removeListener(_onSearchCompleted);
    _searchResult?.clear();
    _searchController.clear();
    setState(() {
      _showSearchBar = false;
      _searchResult = null;
    });
  }

  void _performSearch(String text) {
    // Crucial: remove listener from old search result to prevent focus loss & state loops
    _searchResult?.removeListener(_onSearchCompleted);

    if (text.isEmpty) {
      _searchResult?.clear();
      setState(() {
        _searchResult = null;
      });
      return;
    }

    final result = _pdfViewerController.searchText(text);
    _searchResult = result;
    _searchResult?.addListener(_onSearchCompleted);
    
    // Maintain active focus node state
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPdf = widget.selectedPdf != null;

    return PanelContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ultra-thin Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            color: AppColors.surfaceLight,
            child: Row(
              children: [
                Text(
                  'Document Preview',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                // 1. PDF Viewer
                Positioned.fill(
                  child: hasPdf
                      ? SfPdfViewer.file(
                          widget.selectedPdf!,
                          controller: _pdfViewerController,
                          interactionMode: _pdfInteractionMode,
                          enableTextSelection: true,
                          onDocumentLoaded: (details) {
                            setState(() {
                              _totalPages = details.document.pages.count;
                            });
                          },
                          onPageChanged: (details) {
                            setState(() {
                              _currentPage = details.newPageNumber;
                              _pageController.text = '${details.newPageNumber}';
                            });
                          },
                        )
                      : const AppEmptyState(
                          icon: Icons.find_in_page_outlined,
                          title: 'No PDF selected',
                        ),
                ),

                // 2. Animated Symmetrical Search Bar (Positioned above toolbar, matching width exactly)
                if (hasPdf)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    bottom: _showSearchBar ? 74 : 10,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showSearchBar ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_showSearchBar,
                        child: Center(
                          child: Container(
                            width: _floatingWidgetWidth,
                            height: _floatingWidgetHeight,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.medium,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey('pdf_search_text_field'),
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    textInputAction: TextInputAction.search,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Search...',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                      filled: false,
                                      isDense: true,
                                    ),
                                    onChanged: _performSearch,
                                    onSubmitted: _performSearch,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                // Search Count Indicator
                                if (_searchResult != null && _searchResult!.hasResult) ...[
                                  Text(
                                    '${_searchResult!.currentInstanceIndex}/${_searchResult!.totalInstanceCount}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ] else if (_searchController.text.isNotEmpty &&
                                    _searchResult != null &&
                                    !_searchResult!.hasResult) ...[
                                  Text(
                                    '0/0',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: AppSpacing.md),
                                // Previous Button
                                Tooltip(
                                  message: 'Previous Occurrence',
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _searchResult != null && _searchResult!.hasResult
                                        ? () => _searchResult!.previousInstance()
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                // Next Button
                                Tooltip(
                                  message: 'Next Occurrence',
                                  child: IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _searchResult != null && _searchResult!.hasResult
                                        ? () => _searchResult!.nextInstance()
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3. Floating Main Toolbar (Zoom, Fit, Pages, Mode, Search Toggle)
                if (hasPdf)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: _floatingWidgetWidth,
                        height: _floatingWidgetHeight,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.medium,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Zoom Out
                            Tooltip(
                              message: 'Zoom Out',
                              child: IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () => _pdfViewerController.zoomLevel =
                                    (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0),
                              ),
                            ),
                            // Fit Page Width
                            Tooltip(
                              message: 'Fit Page Width',
                              child: IconButton(
                                icon: const Icon(Icons.fullscreen_exit, size: 16),
                                onPressed: () => _pdfViewerController.zoomLevel = 1.0,
                              ),
                            ),
                            // Zoom In
                            Tooltip(
                              message: 'Zoom In',
                              child: IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () => _pdfViewerController.zoomLevel =
                                    (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0),
                              ),
                            ),
                            // Divider
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 16,
                              width: 1,
                              color: AppColors.border,
                            ),
                            // Page Indicator [currentPage] of [totalPages]
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceNeutral.withValues(alpha: 0.5),
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: TextField(
                                    controller: _pageController,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onSubmitted: (value) {
                                      final page = int.tryParse(value);
                                      if (page != null && page >= 1 && page <= _totalPages) {
                                        _pdfViewerController.jumpToPage(page);
                                      } else {
                                        _pageController.text = '$_currentPage';
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'of $_totalPages',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            // Divider
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 16,
                              width: 1,
                              color: AppColors.border,
                            ),
                            // Interaction Mode Selector (Pan / Text Selection)
                            Tooltip(
                              message: _pdfInteractionMode == PdfInteractionMode.selection
                                  ? 'Switch to Pan Mode'
                                  : 'Switch to Text Selection Mode',
                              child: IconButton(
                                icon: Icon(
                                  _pdfInteractionMode == PdfInteractionMode.selection
                                      ? Icons.ads_click
                                      : Icons.pan_tool_outlined,
                                  size: 16,
                                  color: _pdfInteractionMode == PdfInteractionMode.selection
                                      ? AppColors.accent
                                      : AppColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _pdfInteractionMode =
                                        _pdfInteractionMode == PdfInteractionMode.pan
                                            ? PdfInteractionMode.selection
                                            : PdfInteractionMode.pan;
                                  });
                                },
                              ),
                            ),
                            // Search Toggle
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _showSearchBar
                                    ? AppColors.surfaceNeutral
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Tooltip(
                                message: _showSearchBar ? 'Close Search' : 'Search Document',
                                child: IconButton(
                                  icon: Icon(
                                    _showSearchBar ? Icons.close : Icons.search_rounded,
                                    size: 16,
                                    color: _showSearchBar ? AppColors.accent : AppColors.primary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showSearchBar = !_showSearchBar;
                                      if (_showSearchBar) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _searchFocusNode.requestFocus();
                                        });
                                      } else {
                                        _closeSearch();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
