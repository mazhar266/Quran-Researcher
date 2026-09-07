// Every script the reader offers must be renderable by the font it is paired
// with. This has bitten twice: the mushaf shipped V4 fonts against V1 glyph
// codes, and IndoPak Nastaleeq's private-use encoding had no font at all.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/prefs.dart';

/// Codepoints a TrueType/OpenType font can actually draw (cmap 4, 6 and 12).
Set<int> fontCodepoints(File file) {
  final bytes = file.readAsBytesSync();
  final d = ByteData.sublistView(bytes);
  final numTables = d.getUint16(4);
  int? cmapOffset;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'cmap') cmapOffset = d.getUint32(rec + 8);
  }
  expect(cmapOffset, isNotNull, reason: '${file.path} has no cmap');
  final co = cmapOffset!;
  final cps = <int>{};
  for (var i = 0; i < d.getUint16(co + 2); i++) {
    final so = co + d.getUint32(co + 4 + 8 * i + 4);
    switch (d.getUint16(so)) {
      case 4:
        final segX2 = d.getUint16(so + 6);
        final ends = so + 14, starts = ends + segX2 + 2;
        for (var j = 0; j < segX2 ~/ 2; j++) {
          final start = d.getUint16(starts + 2 * j);
          final end = d.getUint16(ends + 2 * j);
          if (start == 0xFFFF) continue;
          for (var cp = start; cp <= end && cp < 0xFFFF; cp++) {
            cps.add(cp);
          }
        }
      case 6:
        final first = d.getUint16(so + 6), count = d.getUint16(so + 8);
        for (var j = 0; j < count; j++) {
          cps.add(first + j);
        }
      case 12:
        final groups = d.getUint32(so + 12);
        for (var j = 0; j < groups; j++) {
          final g = so + 16 + 12 * j;
          final start = d.getUint32(g), end = d.getUint32(g + 4);
          if (end - start < 0x10000) {
            for (var cp = start; cp <= end; cp++) {
              cps.add(cp);
            }
          }
        }
    }
  }
  return cps;
}

void main() {
  test('every reader script has a font declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final script in readerScripts) {
      expect(pubspec, contains('family: ${script.family}'),
          reason: '${script.slug} needs its font shipped');
    }
  });

  test('the dropped IndoPak Nastaleeq script is no longer offered', () {
    // Its text is encoded in a private-use area (U+F500…) that no font in the
    // dataset covers, so it could only ever render as boxes.
    expect(readerScripts.map((s) => s.slug), isNot(contains('indopak-nastaleeq')));
  });

  test('saved settings naming a removed script fall back to a working one', () {
    final s = Settings.fromJson({'script': 'indopak-nastaleeq'});
    expect(readerScripts.map((x) => x.slug), contains(s.scriptSlug));
    expect(s.scriptSlug, 'qpc-hafs');
    // A still-valid choice is preserved untouched.
    expect(Settings.fromJson({'script': 'warsh'}).scriptSlug, 'warsh');
  });

  test('each script font covers the madd marks the text relies on', () {
    // U+0653 MADDAH ABOVE is the ~ over أُولَـٰٓئِكَ; U+0670 is the dagger alef.
    for (final name in ['UthmanicHafs_V22.ttf', 'DigitalKhattIndoPak.otf',
                        'uthmanic-warsh-v21.ttf']) {
      final cps = fontCodepoints(File('assets/fonts/$name'));
      expect(cps, contains(0x0653), reason: '$name lacks MADDAH ABOVE');
      expect(cps, contains(0x0670), reason: '$name lacks superscript alef');
    }
  });
}
