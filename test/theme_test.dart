import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/theme/app_theme.dart';

void main() {
  test('every reading theme resolves', () {
    for (final t in ReadingTheme.values) {
      expect(AppTheme.of(t), isA<ThemeData>(), reason: t.name);
    }
  });

  test('OLED theme paints true black, not a dark grey', () {
    final oled = AppTheme.oled();
    expect(oled.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(oled.colorScheme.surface, const Color(0xFF000000));
    expect(oled.appBarTheme.backgroundColor, const Color(0xFF000000));
    expect(oled.canvasColor, const Color(0xFF000000));
    // The ordinary dark theme is deliberately *not* black.
    expect(AppTheme.dark().scaffoldBackgroundColor,
        isNot(const Color(0xFF000000)));
  });

  test('OLED reports dark brightness so the mushaf uses the mono font', () {
    // features/mushaf keys the colour-table stripping off Brightness.dark.
    expect(AppTheme.oled().brightness, Brightness.dark);
    expect(AppTheme.oled().colorScheme.brightness, Brightness.dark);
  });

  test('OLED keeps text and dividers legible on black', () {
    final scheme = AppTheme.oled().colorScheme;
    double luminance(Color c) => c.computeLuminance();
    expect(luminance(scheme.onSurface), greaterThan(0.5)); // light text
    expect(luminance(scheme.primary), greaterThan(0.2)); // accent stays visible
    expect(scheme.outlineVariant, isNot(const Color(0xFF000000)));
  });

  test('light and sepia stay light for the colour mushaf font', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.sepia().brightness, Brightness.light);
  });
}
