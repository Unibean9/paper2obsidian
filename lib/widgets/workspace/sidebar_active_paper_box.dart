import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

class SidebarActivePaperBox extends StatelessWidget {
  const SidebarActivePaperBox({
    super.key,
    required this.title,
    required this.vaultPath,
    required this.isLoading,
    required this.onDiscard,
    required this.onChange,
  });

  final String title;
  final String vaultPath;
  final bool isLoading;
  final VoidCallback onDiscard;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Discard Paper',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isLoading ? null : onDiscard,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  vaultPath.isEmpty ? 'Vault path not configured' : vaultPath,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // Nút thay đổi paper nhanh
              InkWell(
                onTap: isLoading ? null : onChange,
                child: Text(
                  'Change',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
