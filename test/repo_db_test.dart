// End-to-end data-layer test against the real dist/core.db (not a fixture).
// Run after `python3 etl/build.py`. Uses the host's sqlite3 library.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/repo.dart';

void main() {
  final coreDb = File('dist/core.db');

  group('QuranRepo on real core.db', () {
    late AppDatabase db;
    late QuranRepo repo;

    setUpAll(() {
      assert(coreDb.existsSync(), 'dist/core.db missing — run etl/build.py');
      db = AppDatabase(NativeDatabase(coreDb, setup: (raw) {
        raw.execute('PRAGMA query_only = ON');
      }));
      repo = QuranRepo(db);
    });

    tearDownAll(() => db.close());

    test('114 surahs, Al-Fatihah first', () async {
      final surahs = await repo.surahs();
      expect(surahs.length, 114);
      expect(surahs.first.nameSimple, 'Al-Fatihah');
      expect(surahs.last.versesCount, 6);
    });

    test('30 juz', () async {
      final juz = await repo.juzList();
      expect(juz.length, 30);
      expect(juz.first.firstVerseKey, '1:1');
    });

    test('11 translation/transliteration resources exposed as 7 translations',
        () async {
      final resources = await repo.translationResources();
      expect(resources.length, 7); // kind='translation' only
      expect(resources.map((r) => r.lang).toSet(), {'en', 'bn'});
    });

    test('Al-Fatihah reader payload', () async {
      final ayahs = await repo.surahAyahs(
        1,
        scriptSlug: 'qpc-hafs',
        translationSlugs: ['en-sahih-international', 'bn-taisirul-quran'],
        transliteration: true,
        wordByWord: true,
      );
      expect(ayahs.length, 7);
      final first = ayahs.first;
      expect(first.verseKey, '1:1');
      expect(first.arabic, contains('بِسۡمِ'));
      expect(first.words.length, 5); // 4 words + ayah-number glyph
      expect(first.words.first.glossEn, 'In (the) name');
      expect(first.translations['en-sahih-international'], contains('Allāh'));
      expect(first.translations['bn-taisirul-quran'], isNotEmpty);
      expect(first.transliteration, isNotNull);
      expect(ayahs.every((a) => a.page == 1 || a.page == 2), isTrue);
    });

    test('script variants return distinct text', () async {
      final uthmani = await repo.surahAyahs(112,
          scriptSlug: 'uthmani',
          translationSlugs: [],
          transliteration: false,
          wordByWord: false);
      final indopak = await repo.surahAyahs(112,
          scriptSlug: 'indopak-nastaleeq',
          translationSlugs: [],
          transliteration: false,
          wordByWord: false);
      expect(uthmani.length, 4);
      expect(indopak.length, 4);
      expect(uthmani.first.arabic, isNot(indopak.first.arabic));
    });

    test('FTS search finds 1:6 for "straight path"', () async {
      final hits = await repo.search('straight path');
      expect(hits.map((h) => h.verseKey), contains('1:6'));
    });

    test('FTS search works in Bangla and Arabic', () async {
      expect(await repo.search('আল্লাহ'), isNotEmpty);
      expect(await repo.search('الرحمن'), isNotEmpty);
    });

    test('malicious search input does not throw', () async {
      expect(await repo.search('"unclosed OR x AND ('), isA<List>());
    });

    test('bismillah text available', () async {
      expect(await repo.bismillah('qpc-hafs'), contains('بِسۡمِ'));
    });
  });
}
