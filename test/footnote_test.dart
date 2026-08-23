// Footnoted translation rendering: <sup foot_note="id">n</sup> markers must
// become tappable superscripts, never leak as raw text.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/features/reader/translation_text.dart';

void main() {
  test('footnotes JSON stored for Sahih International (with footnotes) 1:1',
      () async {
    final db = AppDatabase(NativeDatabase(File('dist/core.db')));
    addTearDown(db.close);
    final rows = await db.customSelect(
      "SELECT t.text, t.footnotes FROM translations t "
      "JOIN resources r ON r.id = t.resource_id "
      "WHERE r.slug = 'en-sahih-international-fn' AND t.surah = 1 AND t.ayah = 1",
    ).get();
    final text = rows.first.read<String>('text');
    expect(text, contains('<sup foot_note="226402">1</sup>'));
    final notes = (jsonDecode(rows.first.read<String>('footnotes')) as Map)
        .cast<String, String>();
    expect(notes['226402'], contains('Allāh'));
  });

  testWidgets('sup markers render as superscripts, not raw markup',
      (tester) async {
    const sample = 'In the name of Allāh,<sup foot_note="226402">1</sup> the '
        'Entirely Merciful.<sup foot_note="226403">2</sup>';
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TranslationText(
            text: sample,
            resourceSlug: 'en-sahih-international-fn',
            surah: 1,
            ayah: 1,
          ),
        ),
      ),
    ));
    expect(find.textContaining('<sup'), findsNothing);
    expect(find.textContaining('foot_note'), findsNothing);
    expect(find.text('1'), findsOneWidget); // superscript marker
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('In the name of Allāh,'), findsOneWidget);
  });

  testWidgets('plain translations render unchanged', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TranslationText(
            text: 'Sovereign of the Day of Recompense.',
            resourceSlug: 'en-sahih-international',
            surah: 1,
            ayah: 4,
          ),
        ),
      ),
    ));
    expect(find.text('Sovereign of the Day of Recompense.'), findsOneWidget);
  });
}
