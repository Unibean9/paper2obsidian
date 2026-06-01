import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class SidebarStatusBox extends StatelessWidget {
  const SidebarStatusBox({
    super.key,
    required this.statusText,
    required this.progressLogs,
  });

  final String statusText;
  final List<String> progressLogs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestLog = progressLogs.isNotEmpty ? progressLogs.last : statusText;
    final isErrorState =
        latestLog.toLowerCase().contains('error') ||
        latestLog.toLowerCase().contains('failed') ||
        latestLog.toLowerCase().contains('lỗi');
    final isSuccessState =
        latestLog.startsWith('✅') || latestLog.toLowerCase().contains('success');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isErrorState
            ? AppColors.errorSurface
            : isSuccessState
            ? AppColors.successSurface
            : AppColors.surfaceLight,
        border: Border.all(
          color: isErrorState
              ? AppColors.error
              : isSuccessState
              ? AppColors.success
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATUS', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            latestLog,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isErrorState
                  ? AppColors.error
                  : isSuccessState
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
