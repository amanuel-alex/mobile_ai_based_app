import 'package:flutter/material.dart';
import 'package:mobile_ai_photo_editor/shared/styles/app_colors.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: AppColors.surface),
  );
}
