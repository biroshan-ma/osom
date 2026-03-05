import 'package:flutter/material.dart';

import 'colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Use plain TextStyle here to avoid calling GoogleFonts at import time.
  // The app-level ThemeData (in `theme.dart`) can still apply Montserrat via
  // GoogleFonts at runtime if available.
  static final TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static final TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static final TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );

  static final TextStyle input = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static final TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
