import 'package:flutter/material.dart';

import '../../theme/app_breakpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/expand_panel_button.dart';
import '../../widgets/common/resize_divider.dart';

class WorkspaceLayout extends StatefulWidget {
  const WorkspaceLayout({
    super.key,
    required this.workspaceSidebar,
    required this.pdfPanel,
    required this.chatPanel,
    required this.isSidebarCollapsed,
    required this.isChatCollapsed,
    required this.onSidebarCollapseChanged,
    required this.onChatCollapseChanged,
  });

  final Widget workspaceSidebar;
  final Widget pdfPanel;
  final Widget chatPanel;
  final bool isSidebarCollapsed;
  final bool isChatCollapsed;
  final ValueChanged<bool> onSidebarCollapseChanged;
  final ValueChanged<bool> onChatCollapseChanged;

  @override
  State<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class _WorkspaceLayoutState extends State<WorkspaceLayout> {
  static const Duration _panelAnimationDuration = Duration(milliseconds: 220);

  double _sidebarWidth = 384.0;
  double _chatWidth = 420.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppBreakpoints.mobile;
        final isTablet = constraints.maxWidth < AppBreakpoints.desktop;

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: _panelAnimationDuration,
                  curve: Curves.easeInOutCubic,
                  clipBehavior: Clip.antiAlias,
                  height: widget.isSidebarCollapsed ? 0 : AppSpacing.hero * 4.5,
                  decoration: const BoxDecoration(),
                  child: SizedBox(
                    height: AppSpacing.hero * 4.5,
                    child: widget.workspaceSidebar,
                  ),
                ),
                if (!widget.isSidebarCollapsed) const SizedBox(height: AppSpacing.lg),
                if (widget.isSidebarCollapsed) ...[
                  InkWell(
                    onTap: () => widget.onSidebarCollapseChanged(false),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_double_arrow_down,
                              size: 14, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text('Hiện Workspace',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Expanded(
                  child: widget.pdfPanel,
                ),
                if (!widget.isChatCollapsed) const SizedBox(height: AppSpacing.lg),
                if (widget.isChatCollapsed) ...[
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: () => widget.onChatCollapseChanged(false),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_double_arrow_up,
                              size: 14, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text('Hiện AI Chat',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ],
                AnimatedContainer(
                  duration: _panelAnimationDuration,
                  curve: Curves.easeInOutCubic,
                  clipBehavior: Clip.antiAlias,
                  height: widget.isChatCollapsed ? 0 : AppSpacing.hero * 4,
                  decoration: const BoxDecoration(),
                  child: SizedBox(
                    height: AppSpacing.hero * 4,
                    child: widget.chatPanel,
                  ),
                ),
              ],
            ),
          );
        }

        if (isTablet) {
          final sidebarWidth = widget.isSidebarCollapsed ? 0.0 : _sidebarWidth;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Expanded(
                  flex: widget.isChatCollapsed ? 10 : 6,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: _isDragging ? Duration.zero : _panelAnimationDuration,
                        curve: Curves.easeInOutCubic,
                        clipBehavior: Clip.antiAlias,
                        width: sidebarWidth,
                        decoration: const BoxDecoration(),
                        child: SizedBox(
                          width: _sidebarWidth,
                          child: widget.workspaceSidebar,
                        ),
                      ),
                      if (!widget.isSidebarCollapsed)
                        ResizeDivider(
                          isLeft: true,
                          onDragUpdate: (delta) {
                            setState(() {
                              _isDragging = true;
                              _sidebarWidth =
                                  (_sidebarWidth + delta).clamp(200.0, 500.0);
                            });
                          },
                          onDragEnd: () {
                            setState(() => _isDragging = false);
                          },
                        ),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            widget.pdfPanel,
                            if (widget.isSidebarCollapsed)
                              Positioned(
                                left: -AppSpacing.xl,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: ExpandPanelButton(
                                    icon: Icons.chevron_right,
                                    tooltip: 'Mở rộng workspace',
                                    isLeft: true,
                                    onPressed: () =>
                                        widget.onSidebarCollapseChanged(false),
                                  ),
                                ),
                              ),
                            if (widget.isChatCollapsed)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: ExpandPanelButtonVertical(
                                  icon: Icons.keyboard_double_arrow_up,
                                  tooltip: 'Mở rộng chat',
                                  onPressed: () =>
                                      widget.onChatCollapseChanged(false),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isChatCollapsed) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedContainer(
                    duration: _panelAnimationDuration,
                    curve: Curves.easeInOutCubic,
                    clipBehavior: Clip.antiAlias,
                    height: 320,
                    decoration: const BoxDecoration(),
                    child: widget.chatPanel,
                  ),
                ],
              ],
            ),
          );
        }

        final sidebarWidth = widget.isSidebarCollapsed ? 0.0 : _sidebarWidth;
        final chatWidth = widget.isChatCollapsed ? 0.0 : _chatWidth;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: _isDragging ? Duration.zero : _panelAnimationDuration,
                curve: Curves.easeInOutCubic,
                clipBehavior: Clip.antiAlias,
                width: sidebarWidth,
                decoration: const BoxDecoration(),
                child: SizedBox(
                  width: _sidebarWidth,
                  child: widget.workspaceSidebar,
                ),
              ),
              if (!widget.isSidebarCollapsed)
                ResizeDivider(
                  isLeft: true,
                  onDragUpdate: (delta) {
                    setState(() {
                      _isDragging = true;
                      _sidebarWidth =
                          (_sidebarWidth + delta).clamp(200.0, 500.0);
                    });
                  },
                  onDragEnd: () {
                    setState(() => _isDragging = false);
                  },
                ),
              if (widget.isSidebarCollapsed) const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    widget.pdfPanel,
                    if (widget.isSidebarCollapsed)
                      Positioned(
                        left: -AppSpacing.lg,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ExpandPanelButton(
                            icon: Icons.chevron_right,
                            tooltip: 'Mở rộng workspace',
                            isLeft: true,
                            onPressed: () =>
                                widget.onSidebarCollapseChanged(false),
                          ),
                        ),
                      ),
                    if (widget.isChatCollapsed)
                      Positioned(
                        right: -AppSpacing.lg,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ExpandPanelButton(
                            icon: Icons.chevron_left,
                            tooltip: 'Mở rộng chat',
                            isLeft: false,
                            onPressed: () =>
                                widget.onChatCollapseChanged(false),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isChatCollapsed) const SizedBox(width: AppSpacing.lg),
              if (!widget.isChatCollapsed)
                ResizeDivider(
                  isLeft: false,
                  onDragUpdate: (delta) {
                    setState(() {
                      _isDragging = true;
                      _chatWidth = (_chatWidth - delta).clamp(300.0, 600.0);
                    });
                  },
                  onDragEnd: () {
                    setState(() => _isDragging = false);
                  },
                ),
              AnimatedContainer(
                duration: _isDragging ? Duration.zero : _panelAnimationDuration,
                curve: Curves.easeInOutCubic,
                clipBehavior: Clip.antiAlias,
                width: chatWidth,
                decoration: const BoxDecoration(),
                child: SizedBox(
                  width: _chatWidth,
                  child: widget.chatPanel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
