import 'package:flutter/material.dart';

abstract class AppTheme {
  static const _twitterBlue = Color(0xFF1DA1F2);
  static const _darkBg = Color(0xFF15202B);
  static const _darkSurface = Color(0xFF192734);

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _twitterBlue,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    dividerTheme: const DividerThemeData(space: 0, thickness: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _twitterBlue,
      brightness: Brightness.dark,
      surface: _darkBg,
      surfaceContainerHighest: _darkSurface,
    ),
    scaffoldBackgroundColor: _darkBg,
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    dividerTheme: const DividerThemeData(space: 0, thickness: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );
}
