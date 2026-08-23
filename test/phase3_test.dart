// Phase 3: tajweed span building (pure logic) + mushaf/warsh data against
// the real databases in dist/ (run etl/build.py first).
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/repo.dart';
import 'package:quran_app/mushaf/mushaf_providers.dart';
import 'package:quran_app/tajweed/tajweed.dart';

void main() {
  group('buildTajweedSpans', () {
    const base = TextStyle(color: Colors.black);

    test('colors ruled ranges and leaves the rest alone', () {
      final spans = buildTajweedSpans(
        text: 'abc def',
        spans: const [TajweedSpan(0, 3, 'qalaqah')],
        disabledRules: const {},
        activeWord: null,
        base: base,
        highlightColor: Colors.yellow,
      );
      expect(spans.map((s) => s.text).join(), 'abc def');
      expect(spans.first.style!.color, isNot(Colors.black)); // qalaqah red
      expect(spans.last.style!.color, Colors.black);
    });

    test('disabled rules render in base color', () {
      final spans = buildTajweedSpans(
        text: 'abc',
        spans: const [TajweedSpan(0, 3, 'qalaqah')],
        disabledRules: const {'qalaqah'},
        activeWord: null,
        base: base,
        highlightColor: Colors.yellow,
      );
      expect(spans.single.style!.color, Colors.black);
    });

    test('recognizerFor attaches each word\'s tap recognizer to its segments',
        () {
      final requested = <int>[];
      final recognizers = <int, TapGestureRecognizer>{};
      final spans = buildTajweedSpans(
        text: 'abc def',
        spans: const [TajweedSpan(4, 6, 'ghunnah')],
        disabledRules: const {},
        activeWord: null,
        base: base,
        highlightColor: Colors.yellow,
        recognizerFor: (pos) {
          requested.add(pos);
          return recognizers.putIfAbsent(pos, TapGestureRecognizer.new);
        },
      );
      addTearDown(() {
        for (final r in recognizers.values) {
          r.dispose();
        }
      });
      // Word 1 = 'abc'; word 2 = 'def' (split by the rule into 'de'+'f').
      expect(requested.toSet(), {1, 2});
      final word2 = spans
          .where((s) => s.recognizer == recognizers[2])
          .map((s) => s.text)
          .join();
      expect(word2, 'def');
      final space = spans.firstWhere((s) => s.text == ' ');
      expect(space.recognizer, isNull);
    });

    test('active word gets background, split across rule boundaries', () {
      final spans = buildTajweedSpans(
        text: 'abc def ghi',
        spans: const [TajweedSpan(4, 6, 'ghunnah')],
        disabledRules: const {},
        activeWord: 2,
        base: base,
        highlightColor: Colors.yellow,
      );
      final highlighted =
          spans.where((s) => s.style!.backgroundColor == Colors.yellow);
      expect(highlighted.map((s) => s.text).join(), 'def');
      expect(spans.map((s) => s.text).join(), 'abc def ghi');
    });
  });

  group('real data', () {
    late ProviderContainer container;

    setUpAll(() {
      AppDatabase open(String name) {
        final file = File('dist/$name');
        assert(file.existsSync(), 'dist/$name missing — run etl/build.py');
        return AppDatabase(NativeDatabase(file));
      }

      container = ProviderContainer(overrides: [
        dbProvider.overrideWith((ref) {
          final db = open('core.db');
          ref.onDispose(db.close);
          return db;
        }),
        moduleDbProvider.overrideWith((ref, name) {
          final db = open(name);
          ref.onDispose(db.close);
          return db;
        }),
      ]);
    });

    tearDownAll(() => container.dispose());

    test('tajweed data flows through the repo, rules all in the palette', () async {
      final repo = await container.read(repoProvider.future);
      final ayahs = await repo.surahAyahs(2,
          scriptSlug: 'qpc-hafs',
          translationSlugs: [],
          transliteration: false,
          wordByWord: false,
          tajweed: true);
      expect(ayahs.length, 286);
      expect(ayahs.every((a) => a.tajweedText != null), isTrue);
      final known = tajweedRules.map((r) => r.slug).toSet();
      for (final a in ayahs) {
        for (final s in a.tajweedSpans!) {
          expect(known, contains(s.$3));
        }
      }
    });

    test('mushaf page 1 is Al-Fatihah, page 604 ends the mushaf', () async {
      final p1 = await container.read(pageAyahsProvider(1).future);
      expect(p1.length, 7);
      expect(p1.first.surah, 1);
      final p604 = await container.read(pageAyahsProvider(604).future);
      expect(p604.map((a) => a.surah).toSet(), {112, 113, 114});
      expect(p604.first.glyphs, isNotEmpty);
    });

    test('warsh script rows exist with their own numbering', () async {
      final extra =
          await container.read(moduleDbProvider('scripts_extra.db').future);
      final rows = await extra
          .customSelect(
              "SELECT count(DISTINCT t.surah) AS s, count(*) AS n FROM ayah_text t "
              "JOIN scripts sc ON sc.id = t.script_id WHERE sc.slug='warsh'")
          .get();
      expect(rows.first.read<int>('s'), 114);
      expect(rows.first.read<int>('n'), 6214); // Warsh counts 6214 ayahs
    });
  });

  test('fontpack asset holds all 604 page fonts', () {
    final bytes = File('assets/fontpack_v1.zip').readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    for (final page in [1, 302, 604]) {
      expect(names, contains('p$page.ttf'));
    }
    expect(names.length, 604);
  });
}
