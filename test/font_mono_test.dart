// The V4 page fonts are COLR/CPAL colour fonts whose baked-in black is
// invisible on a dark background; stripping those tables makes the glyphs take
// the theme's text colour. The rewritten sfnt must stay structurally valid.
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/mushaf/font_mono.dart';

List<String> tagsOf(ByteData font) {
  final src = font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes);
  final data = ByteData.sublistView(src);
  return [
    for (var i = 0; i < data.getUint16(4); i++)
      String.fromCharCodes(src.sublist(12 + 16 * i, 16 + 16 * i)),
  ];
}

void main() {
  late ByteData original;

  setUpAll(() {
    final zip = File('assets/fontpack_v4.zip');
    assert(zip.existsSync(), 'assets/fontpack_v4.zip missing — run etl/build.py');
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    final bytes =
        archive.files.firstWhere((f) => f.name == 'p1.ttf').content as List<int>;
    original = ByteData.sublistView(Uint8List.fromList(bytes));
  });

  test('the shipped page font really is a colour font', () {
    expect(tagsOf(original), contains('COLR'));
    expect(tagsOf(original), contains('CPAL'));
  });

  test('stripping removes only the colour tables', () {
    final mono = stripColourTables(original);
    final before = tagsOf(original).toSet();
    final after = tagsOf(mono).toSet();
    expect(after, isNot(contains('COLR')));
    expect(after, isNot(contains('CPAL')));
    expect(after, before.difference({'COLR', 'CPAL'}));
    // The outlines the renderer falls back to must survive.
    expect(after, containsAll(['glyf', 'loca', 'cmap', 'head', 'hmtx']));
  });

  test('the rewritten font keeps a valid sfnt structure', () {
    final mono = stripColourTables(original);
    final src = mono.buffer.asUint8List(mono.offsetInBytes, mono.lengthInBytes);
    final data = ByteData.sublistView(src);
    expect(data.getUint32(0), 0x00010000); // TrueType sfnt version
    final n = data.getUint16(4);
    expect(n, tagsOf(original).length - 2);
    var pow2 = 1;
    while (pow2 * 2 <= n) {
      pow2 *= 2;
    }
    expect(data.getUint16(6), pow2 * 16); // searchRange
    expect(data.getUint16(8), pow2.bitLength - 1); // entrySelector
    for (var i = 0; i < n; i++) {
      final rec = 12 + 16 * i;
      final offset = data.getUint32(rec + 8);
      final length = data.getUint32(rec + 12);
      expect(offset % 4, 0, reason: 'tables must stay 4-byte aligned');
      expect(offset + length, lessThanOrEqualTo(src.length));
    }
  });

  test('a font without colour tables is returned untouched', () {
    final mono = stripColourTables(original);
    expect(identical(stripColourTables(mono), mono), isTrue);
  });
}
