import 'package:flutter/material.dart';

/// The app's three reading themes: light, dark, and a sepia "paper" mode
/// for long mushaf reading sessions.
enum ReadingTheme { light, dark, sepia }

class AppTheme {
  AppTheme._();

  static const _seedGreen = Color(0xFF146B4E); // mushaf border green

  static ThemeData light() => _base(
        ColorScheme.fromSeed(seedColor: _seedGreen),
        scaffold: const Color(0xFFFBFAF6),
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(seedColor: _seedGreen, brightness: Brightness.dark),
        scaffold: const Color(0xFF121815),
      );

  static ThemeData sepia() => _base(
        ColorScheme.fromSeed(
          seedColor: _seedGreen,
          surface: const Color(0xFFF4ECDA),
        ),
        scaffold: const Color(0xFFF8F1E3),
      );

  static ThemeData _base(ColorScheme scheme, {required Color scaffold}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        scrolledUnderElevation: 1,
      ),
    );
  }

  static ThemeData of(ReadingTheme t) => switch (t) {
        ReadingTheme.light => light(),
        ReadingTheme.dark => dark(),
        ReadingTheme.sepia => sepia(),
      };
}
