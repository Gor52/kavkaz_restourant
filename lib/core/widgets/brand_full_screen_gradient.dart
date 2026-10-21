import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

BoxDecoration brandFullScreenBoxDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.backgroundTop,
        AppColors.background,
        AppColors.primaryDark.withValues(alpha: 0.92),
        AppColors.primaryDark,
        AppColors.textPrimary,
      ],
      stops: const [0.0, 0.12, 0.38, 0.78, 1.0],
    ),
  );
}
