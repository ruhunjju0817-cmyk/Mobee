import 'package:flutter/material.dart';

/// ZoneGuard Monitor 네이비 팔레트.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF0A1628);
  static const surface = Color(0xFF112240);
  static const surfaceHigh = Color(0xFF1A2F55);
  static const border = Color(0xFF233A66);
  static const accent = Color(0xFF4F8CFF);

  static const textPrimary = Color(0xFFE6EDF7);
  static const textSecondary = Color(0xFF8FA3C4);

  static const safe = Color(0xFF22C55E);
  static const warning = Color(0xFFFACC15);
  static const danger = Color(0xFFEF4444);
  static const inactive = Color(0xFF64748B);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.surface,
        primary: AppColors.accent,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.surfaceHigh),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
