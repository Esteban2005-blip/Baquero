import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.background,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.outline,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color background;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color outline;
  final Color success;
  final Color warning;
  final Color error;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space12 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double touchTarget = 48;
  static const double contentMaxWidth = 1040;

  static AppTokens of(BuildContext context) {
    return Theme.of(context).extension<AppTokens>()!;
  }

  @override
  AppTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? background,
    Color? surface,
    Color? text,
    Color? textMuted,
    Color? outline,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
