// The About screen shows a hardcoded version string; pubspec.yaml carries the
// real one. They drifted before (pubspec sat at 1.0.0 while v2.1.1 shipped),
// so pin them together.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/features/about/about_screen.dart';

void main() {
  test('About screen version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml needs a "x.y.z+build" version');
    expect(AboutScreen.version, match!.group(1));
  });
}
