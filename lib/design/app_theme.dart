import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static const AppTokens tokens = AppTokens(
    primary: Color(0xFF4338CA),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE8E7FF),
    background: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF182033),
    textMuted: Color(0xFF59657A),
    outline: Color(0xFFC8CFDC),
    success: Color(0xFF087A55),
    warning: Color(0xFF9A4D00),
    error: Color(0xFFB42318),
  );

  static ThemeData light() {
    const textTheme = TextTheme(
      displaySmall:
          TextStyle(fontSize: 36, height: 1.15, fontWeight: FontWeight.w800),
      headlineMedium:
          TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800),
      headlineSmall:
          TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w700),
      titleLarge:
          TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700),
      titleMedium:
          TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w700),
      bodyLarge:
          TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400),
      bodyMedium:
          TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
      labelLarge:
          TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700),
      labelMedium:
          TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: tokens.background,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4338CA),
        onPrimary: Color(0xFFFFFFFF),
        secondary: Color(0xFF087A55),
        onSecondary: Color(0xFFFFFFFF),
        error: Color(0xFFB42318),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF182033),
        outline: Color(0xFFC8CFDC),
      ),
      textTheme:
          textTheme.apply(bodyColor: tokens.text, displayColor: tokens.text),
      extensions: const <ThemeExtension<dynamic>>[tokens],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F7FB),
        foregroundColor: Color(0xFF182033),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space4,
          vertical: AppTokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFC8CFDC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFC8CFDC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFF4338CA), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFB42318)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
    );
  }
}
