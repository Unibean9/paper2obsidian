import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class LinkZoteroCollectionDialog extends StatefulWidget {
  const LinkZoteroCollectionDialog({
    super.key,
    required this.project,
    required this.onLink,
  });

  final Project project;
  final ValueChanged<String> onLink;

  @override
  State<LinkZoteroCollectionDialog> createState() => _LinkZoteroCollectionDialogState();
}

class _LinkZoteroCollectionDialogState extends State<LinkZoteroCollectionDialog> {
  late final TextEditingController _collectionKeyCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _collectionKeyCtrl = TextEditingController(text: widget.project.zoteroCollectionKey ?? '');
  }

  @override
  void dispose() {
    _collectionKeyCtrl.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onLink(_collectionKeyCtrl.text.trim());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.sync, color: AppColors.accent, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Link Zotero Collection',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Cormorant Garamond',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.lg),

              // Description
              Text(
                'Configure a project-specific collection key for "${widget.project.name}". This links the active workspace to Zotero.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Collection Key TextField
              TextFormField(
                controller: _collectionKeyCtrl,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Zotero Collection Key',
                  prefixIcon: Icon(Icons.link, size: 16),
                  hintText: 'e.g., A8F9HG2D',
                  helperText: 'Leave empty to disconnect the collection.',
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _onSubmit,
                    child: const Text('Link Collection'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
