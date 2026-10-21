import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static TextStyle displayLarge(TextTheme textTheme) {
    return textTheme.displayLarge!.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
  }

  static TextStyle headlineMedium(TextTheme textTheme) {
    return textTheme.headlineMedium!.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle titleLarge(TextTheme textTheme) {
    return textTheme.titleLarge!.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle titleMedium(TextTheme textTheme) {
    return textTheme.titleMedium!.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle bodyLarge(TextTheme textTheme) {
    return textTheme.bodyLarge!.copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );
  }

  static TextStyle bodyMedium(TextTheme textTheme) {
    return textTheme.bodyMedium!.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
  }

  static TextStyle labelLarge(TextTheme textTheme) {
    return textTheme.labelLarge!.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
  }
}