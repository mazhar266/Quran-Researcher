// The Hafs Smart resource: text encoded as pre-composed private-use glyphs,
// and the 15-line mushaf layout that ships with it.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/prefs.dart';


void main() {
  late AppDatabase db;

  setUpAll(() {
    final file = File('dist/core.db');
    assert(file.existsSync(), 'dist/core.db missing — run etl/build.py');
    db = AppDatabase(NativeDatabase(file));
  });
  tearDownAll(() => db.close());

  test('the smart script covers the whole mushaf', () async {
    final rows = await db.customSelect(
        "SELECT count(*) AS n FROM ayah_text t JOIN scripts s "
        "ON s.id = t.script_id WHERE s.slug = 'hafs-smart'").get();
    expect(rows.first.read<int>('n'), 6236);
  });

  test('its text is pre-composed private-use glyphs, not bare Arabic', () async {
    final rows = await db.customSelect(
        "SELECT t.text FROM ayah_text t JOIN scripts s ON s.id = t.script_id "
        "WHERE s.slug = 'hafs-smart' AND t.surah = 2 AND t.ayah = 5").get();
    final runes = rows.first.read<String>('text').runes.where(
        (r) => r != 0x20 && r != 0x200F); // spaces and RTL marks aside
    expect(runes, isNotEmpty);
    // Every glyph sits in the Private Use Area: one codepoint per shaped
    // cluster, so a colouring split can never detach a mark from its letter.
    expect(runes.every((r) => r >= 0xE000 && r <= 0xF8FF), isTrue);
  });

  test('the text and layout stay in core.db though the script is not offered',
      () async {
    // The reader now offers QPC Hafs alone, but the smart text and its
    // 15-line layout remain available for the mushaf work.
    expect(readerScripts.map((s) => s.slug), isNot(contains('hafs-smart')));
    final rows = await db.customSelect(
        "SELECT count(*) AS n FROM ayah_text t JOIN scripts s "
        "ON s.id = t.script_id WHERE s.slug = 'hafs-smart'").get();
    expect(rows.first.read<int>('n'), 6236);
  });

  group('15-line mushaf layout', () {
    test('every ayah is placed on a page and a line range', () async {
      final rows = await db.customSelect(
          'SELECT count(*) AS n, count(DISTINCT page) AS pages, '
          'min(line_start) AS lo, max(line_end) AS hi FROM mushaf_layout').get();
      final r = rows.first;
      expect(r.read<int>('n'), 6236);
      expect(r.read<int>('pages'), 604);
      expect(r.read<int>('lo'), 1);
      expect(r.read<int>('hi'), 15); // the Madani mushaf's 15 lines
    });

    test('line ranges are ordered, and pages agree with the existing data',
        () async {
      final bad = await db.customSelect(
          'SELECT count(*) AS n FROM mushaf_layout WHERE line_end < line_start')
          .get();
      expect(bad.first.read<int>('n'), 0);
      // Both sources number pages independently; they agree except at a few
      // ayahs that straddle a page break.
      final agree = await db.customSelect(
          'SELECT count(*) AS n FROM mushaf_layout m JOIN ayahs a '
          'ON a.surah = m.surah AND a.ayah = m.ayah WHERE a.page = m.page')
          .get();
      expect(agree.first.read<int>('n'), greaterThan(6100));
    });
  });
}
