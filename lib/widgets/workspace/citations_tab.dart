import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_empty_state.dart';

class CitationsTab extends StatelessWidget {
  const CitationsTab({super.key, required this.citations});

  final List<String> citations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (citations.isEmpty) {
      return const AppEmptyState(
        icon: Icons.format_quote,
        title: 'No citations extracted yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Extracted Citations (${citations.length})',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: citations.length,
            itemBuilder: (context, index) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.surfaceNeutral,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                title: Text(
                  citations[index],
                  style: theme.textTheme.labelLarge?.copyWith(height: 1.4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
