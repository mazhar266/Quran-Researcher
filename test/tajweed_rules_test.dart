// Every rule the corpus uses must be nameable, and the madd rules must state
// how long the letter is held — the colour alone cannot say 2 vs 4-5 vs 6.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/tajweed/tajweed.dart';

void main() {
  test('every rule in the corpus has a name, Arabic name and colour', () async {
    final db = AppDatabase(NativeDatabase(File('dist/core.db')));
    addTearDown(db.close);
    final rows = await db.customSelect('SELECT spans FROM tajweed_ayah').get();
    final used = <String>{};
    for (final r in rows) {
      for (final s in jsonDecode(r.read<String>('spans')) as List) {
        used.add(s[2] as String);
      }
    }
    expect(used.length, 18);
    for (final slug in used) {
      final rule = tajweedRuleBySlug[slug];
      expect(rule, isNotNull, reason: slug);
      expect(rule!.arabic, isNotEmpty, reason: slug);
      expect(rule.bangla, isNotEmpty, reason: slug);
      expect(rule.label, isNotEmpty, reason: slug);
    }
  });

  test('madd rules carry their harakat count', () {
    const expected = {
      'madda_normal': '2',
      'madda_necessary': '6',
      'madda_obligatory_mottasel': '4-5', // مد واجب متصل, as in أُولَـٰٓئِكَ
      'madda_obligatory_monfasel': '4-5',
    };
    for (final e in expected.entries) {
      expect(tajweedRuleBySlug[e.key]!.harakat, e.value, reason: e.key);
    }
    // Rules with no prescribed length must not invent one.
    expect(tajweedRuleBySlug['qalaqah']!.harakat, isNull);
    expect(tajweedRuleBySlug['ham_wasl']!.harakat, isNull);
  });
}
