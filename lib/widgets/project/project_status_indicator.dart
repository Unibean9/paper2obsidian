import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ProjectStatusIndicator extends StatelessWidget {
  const ProjectStatusIndicator({
    super.key,
    required this.hasCollectionKey,
    required this.isZoteroConfigured,
  });

  final bool hasCollectionKey;
  final bool isZoteroConfigured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isZoteroConfigured) {
      return Tooltip(
        message: 'Zotero not configured — add API key in Settings',
        child: Chip(
          avatar: const Icon(
            Icons.link_off,
            size: 14,
            color: AppColors.textMuted,
          ),
          label: Text('No Zotero', style: theme.textTheme.labelSmall),
          backgroundColor: AppColors.infoSurface,
          side: const BorderSide(color: AppColors.border),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (!hasCollectionKey) {
      return Tooltip(
        message: 'No Zotero collection linked — edit project to add one',
        child: Chip(
          avatar: const Icon(Icons.link, size: 14, color: AppColors.warning),
          label: Text(
            'No collection',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
            ),
          ),
          backgroundColor: AppColors.warningSurface,
          side: const BorderSide(color: AppColors.warningSurface),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return Tooltip(
      message: 'Zotero collection linked — Import/Export ready',
      child: Chip(
        avatar: const Icon(Icons.link, size: 14, color: AppColors.success),
        label: Text(
          'Zotero linked',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.success,
          ),
        ),
        backgroundColor: AppColors.successSurface,
        side: const BorderSide(color: AppColors.successSurface),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
