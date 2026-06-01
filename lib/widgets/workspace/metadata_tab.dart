import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class MetadataTab extends StatelessWidget {
  const MetadataTab({
    super.key,
    required this.titleCtrl,
    required this.authorsCtrl,
    required this.venueCtrl,
    required this.yearCtrl,
    required this.doiCtrl,
    required this.keywordsCtrl,
    required this.datasetCtrl,
    required this.problemCtrl,
    required this.limitationCtrl,
    required this.summaryCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController authorsCtrl;
  final TextEditingController venueCtrl;
  final TextEditingController yearCtrl;
  final TextEditingController doiCtrl;
  final TextEditingController keywordsCtrl;
  final TextEditingController datasetCtrl;
  final TextEditingController problemCtrl;
  final TextEditingController limitationCtrl;
  final TextEditingController summaryCtrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          _buildTextField('Title', titleCtrl, maxLines: 3),
          _buildTextField('Authors', authorsCtrl, maxLines: 3),
          _buildTextField('Venue', venueCtrl, maxLines: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTextField('Year', yearCtrl)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildTextField('DOI', doiCtrl)),
            ],
          ),
          _buildTextField('Tags / Keywords', keywordsCtrl, maxLines: 2),
          _buildTextField('Dataset', datasetCtrl, maxLines: 2),
          _buildTextField('Problem Statement', problemCtrl, maxLines: 3),
          _buildTextField('Limitations', limitationCtrl, maxLines: 2),
          _buildTextField('Summary', summaryCtrl, maxLines: 6),
        ],
      ),
    );
  }
}

// Builds a labeled TextField with the label rendered above the input field.
Widget _buildTextField(
  String label,
  TextEditingController controller, {
  int maxLines = 1,
}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: maxLines,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(hintText: 'Enter $label...'),
            ),
          ],
        ),
      );
    },
  );
}
