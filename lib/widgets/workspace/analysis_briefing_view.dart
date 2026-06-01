import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import 'metadata_tab.dart';

class AnalysisBriefingView extends StatefulWidget {
  const AnalysisBriefingView({
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
    required this.citations,
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
  final List<String> citations;

  @override
  State<AnalysisBriefingView> createState() => _AnalysisBriefingViewState();
}

class _AnalysisBriefingViewState extends State<AnalysisBriefingView> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Header Selector
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit_note : Icons.auto_awesome,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _isEditing ? 'EDIT INFORMATION' : 'DOCUMENT BRIEFING',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Toggle Edit/Reader Mode Button
              TextButton.icon(
                onPressed: () {
                  setState(() => _isEditing = !_isEditing);
                },
                icon: Icon(
                  _isEditing ? Icons.chrome_reader_mode_outlined : Icons.edit_outlined,
                  size: 14,
                  color: AppColors.accent,
                ),
                label: Text(
                  _isEditing ? 'View Briefing' : 'Edit Details',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Active Content View
        Expanded(
          child: _isEditing ? _buildEditForm() : _buildReaderBriefing(theme),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return MetadataTab(
      titleCtrl: widget.titleCtrl,
      authorsCtrl: widget.authorsCtrl,
      venueCtrl: widget.venueCtrl,
      yearCtrl: widget.yearCtrl,
      doiCtrl: widget.doiCtrl,
      keywordsCtrl: widget.keywordsCtrl,
      datasetCtrl: widget.datasetCtrl,
      problemCtrl: widget.problemCtrl,
      limitationCtrl: widget.limitationCtrl,
      summaryCtrl: widget.summaryCtrl,
    );
  }

  Widget _buildReaderBriefing(ThemeData theme) {
    final title = widget.titleCtrl.text.trim();
    final authors = widget.authorsCtrl.text.trim();
    final summary = widget.summaryCtrl.text.trim();
    final venue = widget.venueCtrl.text.trim();
    final year = widget.yearCtrl.text.trim();
    final doi = widget.doiCtrl.text.trim();
    final dataset = widget.datasetCtrl.text.trim();
    final keywords = widget.keywordsCtrl.text.trim();
    final problem = widget.problemCtrl.text.trim();
    final limitation = widget.limitationCtrl.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Paper Title & Authors
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (authors.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    authors,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Brief Study Guide Callout
          if (summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'STUDY BRIEFING',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Quick Metadata Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceNeutral.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'PUBLICATION INFO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (venue.isNotEmpty)
                  _buildMetaItem(Icons.menu_book_outlined, 'Venue', venue, theme),
                if (year.isNotEmpty)
                  _buildMetaItem(Icons.calendar_today_outlined, 'Year', year, theme),
                if (doi.isNotEmpty)
                  _buildMetaItem(Icons.link_outlined, 'DOI', doi, theme),
                if (dataset.isNotEmpty)
                  _buildMetaItem(Icons.analytics_outlined, 'Dataset', dataset, theme),
                if (keywords.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: keywords.split(',').map((kw) {
                      final clean = kw.trim();
                      if (clean.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          clean,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Key Insights (Problem Statement & Limitations)
          if (problem.isNotEmpty || limitation.isNotEmpty) ...[
            Text(
              'KEY INSIGHTS',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (problem.isNotEmpty)
              _buildInsightCard(
                icon: Icons.lightbulb_outline,
                title: 'Problem Statement',
                content: problem,
                theme: theme,
              ),
            if (limitation.isNotEmpty)
              _buildInsightCard(
                icon: Icons.report_problem_outlined,
                title: 'Limitations & Challenges',
                content: limitation,
                theme: theme,
              ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Citations Tab view embedded beautiful list
          if (widget.citations.isNotEmpty) ...[
            Text(
              'EXTRACTED CITATIONS (${widget.citations.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.citations.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.surfaceNeutral,
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          widget.citations[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String content,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
