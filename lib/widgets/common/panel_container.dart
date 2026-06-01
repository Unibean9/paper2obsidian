import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class PanelContainer extends StatelessWidget {
  const PanelContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: AppColors.surfaceNeutral,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: padding,
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }
}
