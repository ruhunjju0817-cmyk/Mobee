import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 테마와 무관한 상태 색상 (라이트/다크 공통).
class AppColors {
  const AppColors._();

  // 심각도 순: safe(초록) < warning(노랑) < alert(주황) < danger(빨강).
  static const safe = Color(0xFF00C896);
  static const warning = Color(0xFFFFD600);
  static const alert = Color(0xFFFF8C00);
  static const danger = Color(0xFFFF3B3B);
  static const inactive = Color(0xFF6B7280);
}

/// 라이트/다크 테마별 색상. `context.palette`로 접근.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.background,
    required this.backgroundDeep,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.accent,
    required this.shadow,
    required this.barBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.glowStrength,
  });

  /// ZoneGuard 라이트 대시보드.
  static const light = AppPalette(
    isDark: false,
    background: Color(0xFFF5F7FB),
    backgroundDeep: Color(0xFFE9EDF4),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F4F9),
    border: Color(0xFFE2E7EF),
    accent: Color(0xFF2F6FED),
    shadow: Color(0x140F1B33),
    barBackground: Color(0xD9FFFFFF),
    textPrimary: Color(0xFF0F1B33),
    textSecondary: Color(0xFF4A5878),
    textMuted: Color(0xFF8A96AD),
    glowStrength: 1,
  );

  /// 딥 네이비 산업용 대시보드. 카드가 반투명이라 배경 그리드가 비친다.
  static const dark = AppPalette(
    isDark: true,
    background: Color(0xFF0A0F1E),
    backgroundDeep: Color(0xFF060A15),
    surface: Color(0xCC111A2E),
    surfaceHigh: Color(0xFF16213A),
    border: Color(0xFF1F2C47),
    accent: Color(0xFF3D9BFF),
    shadow: Color(0x123D9BFF),
    barBackground: Color(0xC70A0F1E),
    textPrimary: Color(0xFFEAF1FF),
    textSecondary: Color(0xFF8391AD),
    textMuted: Color(0xFF55627D),
    glowStrength: 1.8,
  );

  final bool isDark;
  final Color background;
  final Color backgroundDeep;

  /// 카드 배경.
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color accent;

  /// 카드 기본 그림자 (라이트: 연한 그림자, 다크: 미세한 액센트 글로우).
  final Color shadow;

  /// 하단 블러 바 배경.
  final Color barBackground;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// 글로우 효과 배율. 어두운 배경일수록 글로우를 강하게.
  final double glowStrength;

  /// [color]로 빛나는 글로우 색 (라이트 기준 [alpha]에 테마 배율 적용).
  Color glow(Color color, double alpha) =>
      color.withValues(alpha: (alpha * glowStrength).clamp(0.0, 1.0));

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: c(background, other.background),
      backgroundDeep: c(backgroundDeep, other.backgroundDeep),
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      border: c(border, other.border),
      accent: c(accent, other.accent),
      shadow: c(shadow, other.shadow),
      barBackground: c(barBackground, other.barBackground),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      glowStrength: lerpDouble(glowStrength, other.glowStrength, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// 대시보드 공통 텍스트 스타일.
/// 레이블은 작고 흐리게, 값은 크고 굵게.
class AppText {
  const AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  /// 카드 헤더 등 대문자 레이블.
  static TextStyle label(AppPalette p) => TextStyle(
    color: p.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );

  /// 큰 상태값/숫자. 다크 테마에서는 은은한 글로우.
  static TextStyle value(AppPalette p, Color color, {double size = 30}) =>
      TextStyle(
        color: color,
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        fontFeatures: _tabular,
        shadows: p.isDark
            ? [Shadow(color: color.withValues(alpha: 0.45), blurRadius: 18)]
            : null,
      );

  /// 값 옆 단위.
  static TextStyle unit(AppPalette p) =>
      TextStyle(color: p.textMuted, fontSize: 11, fontWeight: FontWeight.w600);

  /// 폰트(한글 fallback 등)에 상관없이 줄 높이를 고정해
  /// IntrinsicHeight 안에서 미세한 overflow가 나지 않게 한다.
  static StrutStyle strut(double fontSize, [double height = 1.1]) =>
      StrutStyle(fontSize: fontSize, height: height, forceStrutHeight: true);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(AppPalette.light);
  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
        surface: p.background,
        primary: p.accent,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 투명 앱바라 상태바 아이콘 밝기를 명시.
        systemOverlayStyle: p.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
    );
  }
}
