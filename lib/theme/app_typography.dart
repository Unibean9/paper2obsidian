import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static const TextStyle code = TextStyle(
    fontFamily: 'ui-monospace',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextTheme textTheme = const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Cormorant Garamond',
      fontSize: 88,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 48,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 28,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 1.3,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 2.2,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textMuted,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textMuted,
    ),
  );
}
