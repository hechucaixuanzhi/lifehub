import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// LifeHub 主题工厂 — 引用 app_tokens.dart 的 Token（对齐 docs/design/tokens.md）。
class AppTheme {
  /// 向后兼容转发（Phase 2/3 页面重写后移除，统一引用 AppColors）。
  static const Color bg = AppColors.bg;
  static const Color surface = AppColors.surface;
  static const Color onBg = AppColors.onBg;
  static const Color muted = AppColors.muted;
  static const Color accent = AppColors.accent;
  static const Color accentSoft = AppColors.accentSoft;
  static const Color danger = AppColors.danger;
  static const Color heart = AppColors.heart;

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: const TextTheme(
          titleMedium: AppTypography.title,
          bodyMedium: AppTypography.body,
          labelSmall: AppTypography.label,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onBg,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.accentSoft,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight:
                  states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.muted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.muted,
            ),
          ),
        ),
      );
}
