// A coloured run must never begin with a combining mark or a tatweel: the
// engine shapes each TextSpan separately, so a mark severed from its base
// letter loses its positioning and stops being drawn. This is what made the
// maddah over أُولَـٰٓئِكَ (2:5) vanish once tajweed colouring was switched on.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/tajweed/tajweed.dart';

bool attachesToPrevious(int c) =>
    c == 0x0640 ||
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06DC) ||
    (c >= 0x06DF && c <= 0x06E8) ||
    (c >= 0x06EA && c <= 0x06ED) ||
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x08D3 && c <= 0x08FF);

void main() {
  late AppDatabase db;
  setUpAll(() => db = AppDatabase(NativeDatabase(File('dist/core.db'))));
  tearDownAll(() => db.close());

  const style = TextStyle(color: Color(0xFF000000));

  Future<List<({String text, List<TajweedSpan> spans})>> ayahs(String where) async {
    final rows = await db
        .customSelect('SELECT text, spans FROM tajweed_ayah $where')
        .get();
    return [
      for (final r in rows)
        (
          text: r.read<String>('text'),
          spans: (jsonDecode(r.read<String>('spans')) as List)
              .map((s) => TajweedSpan(s[0] as int, s[1] as int, s[2] as String))
              .toList(),
        ),
    ];
  }

  test('2:5 keeps its madd mark attached to the letter it sits on', () async {
    final a = (await ayahs('WHERE surah=2 AND ayah=5')).single;
    final spans = buildTajweedSpans(
      text: a.text,
      spans: a.spans,
      disabledRules: const {},
      activeWord: null,
      base: style,
      highlightColor: const Color(0x00000000),
    );
    // The madd segment must carry its base letter, not start at the tatweel.
    final madd = spans.firstWhere(
        (s) => s.style!.color == const Color(0xFF2144C1));
    expect(madd.text!.codeUnitAt(0), isNot(0x0640));
    expect(attachesToPrevious(madd.text!.codeUnitAt(0)), isFalse);
    expect(madd.text, contains('ٓ')); // the maddah is inside the run
    expect(madd.text, startsWith('ل')); // carried by its لام
  });

  test('no run in the whole mushaf begins with an orphaned mark', () async {
    final all = await ayahs('');
    expect(all.length, 6236);
    var checked = 0;
    for (final a in all) {
      final spans = buildTajweedSpans(
        text: a.text,
        spans: a.spans,
        disabledRules: const {},
        activeWord: null,
        base: style,
        highlightColor: const Color(0x00000000),
      );
      for (final s in spans) {
        if (s.text!.isEmpty) continue;
        expect(attachesToPrevious(s.text!.codeUnitAt(0)), isFalse,
            reason: 'run "${s.text}" starts with a combining mark');
        checked++;
      }
      // Colouring must never alter the text itself.
      expect(spans.map((s) => s.text).join(), a.text);
    }
    expect(checked, greaterThan(100000));
  });

  test('word highlighting still lands on the right word', () async {
    final a = (await ayahs('WHERE surah=2 AND ayah=5')).single;
    final spans = buildTajweedSpans(
      text: a.text,
      spans: a.spans,
      disabledRules: const {},
      activeWord: 2, // عَلَىٰ
      base: style,
      highlightColor: const Color(0xFFFFFF00),
    );
    final lit = spans
        .where((s) => s.style!.backgroundColor == const Color(0xFFFFFF00))
        .map((s) => s.text)
        .join();
    expect(lit, a.text.split(' ')[1]);
  });
}
