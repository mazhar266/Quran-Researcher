// Phase 4 research layer against the real databases in dist/.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/research_repo.dart';

void main() {
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

  test('word morphology: 1:1:2 (Allah) has root ا ل ه with 2851 occurrences',
      () async {
    final m = await container.read(wordMorphologyProvider('1:1:2').future);
    expect(m, isNotNull);
    expect(m!.root!.arabicNorm, 'اله');
    expect(m.root!.wordsCount, 2851);
    expect(m.glossEn, '(of) Allah');
    expect(m.lemma, isNotNull);
  });

  test('root occurrences join back to words', () async {
    final m = await container.read(wordMorphologyProvider('1:1:2').future);
    final occ =
        await container.read(rootOccurrencesProvider(m!.root!.id).future);
    expect(occ.length, m.root!.wordsCount);
    expect(occ.first.word, isNotEmpty);
    expect(occ.any((o) => o.location == '1:1:2'), isTrue);
  });

  test('root search finds رحم by Arabic and by latin key', () async {
    final byArabic = await container.read(rootSearchProvider('رحم').future);
    expect(byArabic.any((r) => r.arabicNorm == 'رحم'), isTrue);
    final top = await container.read(rootSearchProvider('').future);
    expect(top.length, 200);
    expect(top.first.wordsCount, greaterThan(top.last.wordsCount));
  });

  test('Arramooz dictionary entries for root اله', () async {
    final d = await container.read(dictEntriesProvider('اله').future);
    expect(d.nouns, isNotEmpty);
    expect(d.verbs, isNotEmpty);
    expect(d.nouns.any((n) => n.definition.isNotEmpty), isTrue);
  });

  test('similar ayahs for 1:1 include 27:30 with word ranges', () async {
    final matches = await container.read(similarAyahsProvider((1, 1)).future);
    final m = matches.firstWhere((m) => m.matchedKey == '27:30');
    expect(m.score, 80);
    expect(m.ranges, [[5, 8]]);
    expect(m.matchedText, isNotEmpty);
  });

  test('mutashabihat: 2:23 carries phrase 50 (71 hits across 70 ayahs)',
      () async {
    final phrases = await container.read(ayahPhrasesProvider((2, 23)).future);
    expect(phrases.map((p) => p.id), contains(50));
    final occ = await container.read(phraseOccurrencesProvider(50).future);
    expect(occ.length, 70); // one ayah contains the phrase twice
    final totalRanges = occ.fold<int>(0, (n, o) => n + o.ranges.length);
    expect(totalRanges, 71);
    expect(occ.every((o) => o.ranges.isNotEmpty && o.text.isNotEmpty), isTrue);
  });

  test('themes: 2:10 falls inside the hypocrisy section', () async {
    final themes = await container.read(ayahThemesProvider((2, 10)).future);
    expect(themes, isNotEmpty);
    expect(themes.first.ayahFrom, lessThanOrEqualTo(10));
    expect(themes.first.ayahTo, greaterThanOrEqualTo(10));
  });

  test('topics: search Allah, cross-linked description, ayah list', () async {
    final hits = await container.read(topicSearchProvider('Allah').future);
    final allah = hits.firstWhere((t) => t.name == 'Allah');
    final full = await container.read(topicProvider(allah.id).future);
    expect(full!.description, contains('<topic data-id='));
    expect(full.ayahs, contains('1:1'));
  });

  test('surah info available for all 114 surahs', () async {
    final info1 = await container.read(surahInfoProvider(1).future);
    expect(info1, contains('Fatihah'));
    final info114 = await container.read(surahInfoProvider(114).future);
    expect(info114, isNotEmpty);
  });
}
