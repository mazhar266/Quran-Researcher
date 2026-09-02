// Sarf layer: word grammar aligned from the Quranic Arabic Corpus, plus the
// bab and masdar derived by etl/grammar.py. Runs against the real dist/core.db.
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/sarf.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    final file = File('dist/core.db');
    assert(file.existsSync(), 'dist/core.db missing — run etl/build.py');
    container = ProviderContainer(overrides: [
      dbProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase(file));
        ref.onDispose(db.close);
        return db;
      }),
    ]);
  });

  tearDownAll(() => container.dispose());

  Future<WordSarf?> sarf(String loc) =>
      container.read(wordSarfProvider(loc).future);

  test('يؤمنون (2:3:2) is form IV, present, active, 3rd masc plural', () async {
    final s = (await sarf('2:3:2'))!;
    expect(s.isVerb, isTrue);
    expect(s.verbForm, 4);
    expect(s.formRoman, 'IV');
    expect(s.aspect, 'IMPF');
    expect(s.voice, 'ACT');
    expect(s.pgn, '3MP');
    expect(s.mood, 'IND');
    expect(s.babAr, contains('الإِفْعَال'));
    expect(s.masdar, contains('إيمَان')); // إيمان, not the template إأمان
    expect(s.sigahAr, contains('مُضَارِع'));
    expect(s.sigahAr, contains('مَعْرُوف'));
  });

  test('أنزل (2:4:4) is recognised as passive', () async {
    final s = (await sarf('2:4:4'))!;
    expect(s.aspect, 'PERF');
    expect(s.voice, 'PASS');
    expect(s.sigahAr, contains('مَجْهُول'));
  });

  test('اقرأ (96:1:1) is an imperative, bab fataha', () async {
    final s = (await sarf('96:1:1'))!;
    expect(s.aspect, 'IMPV');
    expect(s.babAr, contains('فَتَحَ'));
  });

  test('nouns carry case, not verb features', () async {
    final s = (await sarf('1:1:2'))!; // ٱللَّهِ
    expect(s.isVerb, isFalse);
    expect(s.gcase, 'GEN');
    expect(s.special, 'PN');
    expect(s.sigahAr, isNull);
  });

  group('derived data quality', () {
    late AppDatabase db;
    setUpAll(() => db = AppDatabase(NativeDatabase(File('dist/core.db'))));
    tearDownAll(() => db.close());

    test('forms II-X always resolve a bab', () async {
      final rows = await db.customSelect(
        'SELECT count(*) AS n FROM verb_lemmas '
        'WHERE verb_form BETWEEN 2 AND 10 AND bab_ar IS NULL').get();
      expect(rows.first.read<int>('n'), 0);
    });

    test('hollow verbs get the classical bab', () async {
      for (final (lemma, bab) in [
        ('قالَ', 'نَصَرَ'), // قال يقول
        ('كانَ', 'نَصَرَ'), // كان يكون
        ('خافَ', 'سَمِعَ'), // خاف يخاف
        ('جاءَ', 'ضَرَبَ'), // جاء يجيء
      ]) {
        final rows = await db.customSelect(
          'SELECT bab_ar FROM verb_lemmas WHERE lemma = ?1',
          variables: [Variable.withString(lemma)]).get();
        expect(rows.first.read<String>('bab_ar'), contains(bab),
            reason: lemma);
      }
    });

    test('most verb words in the Quran show a bab', () async {
      final rows = await db.customSelect('''
        SELECT (SELECT count(*) FROM word_grammar g
                  JOIN verb_lemmas v ON v.lemma = g.lemma AND v.root = g.root
                WHERE g.pos_tag = 'V' AND v.bab_ar IS NOT NULL) AS with_bab,
               (SELECT count(*) FROM word_grammar WHERE pos_tag = 'V') AS total
      ''').get();
      final withBab = rows.first.read<int>('with_bab');
      final total = rows.first.read<int>('total');
      expect(withBab / total, greaterThan(0.9));
    });

    test('no malformed template masdar leaks through for weak roots', () async {
      // إأعان-style output would mean the pattern was applied to a hamzated
      // root; templates are only allowed on sound roots.
      final rows = await db.customSelect(
        "SELECT count(*) AS n FROM verb_lemmas WHERE masdar_source = 'pattern' "
        "AND (masdar LIKE '%أ%' OR masdar LIKE '%ؤ%' OR masdar LIKE '%ئ%')").get();
      expect(rows.first.read<int>('n'), 0);
    });
  });
}
