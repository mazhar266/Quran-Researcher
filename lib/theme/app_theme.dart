import 'package:flutter/material.dart';

/// The app's reading themes: light, dark, a sepia "paper" mode for long
/// mushaf sessions, and a true-black mode for OLED screens.
enum ReadingTheme { light, dark, sepia, oled }

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

  /// Pure #000000 surfaces: on an OLED panel black pixels are switched off, so
  /// this saves power and removes the dark theme's grey halo in a dark room.
  /// Elevation overlays are dropped for the same reason — a "raised" surface
  /// tinted grey would defeat the point — leaving hairline borders to separate
  /// things instead.
  static ThemeData oled() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedGreen,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF000000),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF050505),
      surfaceContainer: const Color(0xFF0A0A0A),
      surfaceContainerHigh: const Color(0xFF101010),
      surfaceContainerHighest: const Color(0xFF161616),
      outlineVariant: const Color(0xFF2A2A2A),
    );
    return _base(scheme, scaffold: const Color(0xFF000000)).copyWith(
      canvasColor: const Color(0xFF000000),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0A0A0A)),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0A0A0A),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF0A0A0A),
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
    );
  }

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
        ReadingTheme.oled => oled(),
      };
}
