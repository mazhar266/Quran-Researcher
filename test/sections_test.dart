// The mushaf divisions the ETL stores on every ayah — juz, hizb, rubʿ al-hizb,
// rukuʿ, manzil and sajdah — checked against the real dist/core.db.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/sections_repo.dart';

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

  test('the mushaf has 30 juz, 60 hizb, 240 rubʿ, 558 rukuʿ, 7 manzil',
      () async {
    const expected = {
      Division.juz: 30,
      Division.hizb: 60,
      Division.rub: 240,
      Division.ruku: 558,
      Division.manzil: 7,
    };
    for (final e in expected.entries) {
      final list = await container.read(divisionListProvider(e.key).future);
      expect(list.length, e.value, reason: e.key.name);
      expect(list.first.number, 1);
      expect(list.last.number, e.value);
    }
  });

  test('every division starts where the classical mushaf starts', () async {
    final juz = await container.read(divisionListProvider(Division.juz).future);
    expect(juz[1].firstVerseKey, '2:142'); // juz 2
    final hizb = await container.read(divisionListProvider(Division.hizb).future);
    expect(hizb[1].firstVerseKey, '2:75'); // hizb 2
    // The seven manzils of the week-long reading cycle.
    final manzil =
        await container.read(divisionListProvider(Division.manzil).future);
    expect(manzil.map((m) => m.firstVerseKey),
        ['1:1', '5:1', '10:1', '17:1', '26:1', '37:1', '50:1']);
  });

  test('rubʿ entries carry their hizb and quarter — four to a hizb', () async {
    final rub = await container.read(divisionListProvider(Division.rub).future);
    expect(rub.length, 240);
    // Rubʿ 1-4 are hizb 1's start, ¼, ½ and ¾; rubʿ 5 opens hizb 2.
    expect(rub[0].hizb, 1);
    expect(rub[0].quarter, 0);
    expect(rub[2].quarter, 2); // the half-hizb stop
    expect(rub[4].hizb, 2);
    expect(rub[4].quarter, 0);
    expect(rub[4].firstVerseKey, '2:75'); // same ayah as hizb 2
    for (final r in rub) {
      expect(r.hizb, (r.number - 1) ~/ 4 + 1);
    }
  });

  test('section starts mark the opening ayah of each division', () async {
    final starts = await container.read(sectionStartsProvider.future);
    final first = starts['1:1']!;
    expect(first.juz, 1);
    expect(first.hizb, 1);
    expect(first.ruku, 1);
    expect(first.manzil, 1);

    // 2:142 opens juz 2 — and every juz start is also a hizb start (two
    // hizbs to a juz), here hizb 3.
    final juz2 = starts['2:142']!;
    expect(juz2.juz, 2);
    expect(juz2.hizb, 3);

    // 2:8 opens a rukuʿ only, with no larger division breaking there.
    final rukuOnly = starts['2:8']!;
    expect(rukuOnly.ruku, 3);
    expect(rukuOnly.juz, isNull);
    expect(rukuOnly.hizb, isNull);
    expect(rukuOnly.rub, isNull);

    // A half-hizb stop: rubʿ 3 of hizb 1.
    final half = starts['2:44']!;
    expect(half.rub, 3);
    expect(half.rubQuarter, 2);
    expect(half.rubHizb, 1);

    // Ayahs mid-division carry no marker at all.
    expect(starts['2:3'], isNull);
    expect(starts.length, 694); // distinct ayahs that open some division
  });

  test('the 15 sajdah ayahs, 4 obligatory in the Hafs reading', () async {
    final list = await container.read(sajdahListProvider.future);
    expect(list.length, 15);
    expect(list.first.verseKey, '7:206');
    expect(list.where((s) => s.isObligatory).length, 4);
    expect(list.every((s) => s.page != null), isTrue);
  });

  test('an ayah reports every division it sits inside', () async {
    final p = await container.read(ayahPositionProvider('2:255').future);
    expect(p!.juz, 3);
    expect(p.hizb, 5);
    expect(p.manzil, 1);
    expect(p.ruku, isNotNull);
  });
}
