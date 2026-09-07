// Pins the case that regressed: 2:5's أُولَـٰٓئِكَ carries a madd wājib
// muttasil whose maddah (ٓ) sits on a dagger alef. Colouring the rule used to
// split that mark away from its letter, and the engine then stopped drawing
// it. Rendered here through the real text engine so the mark's loss would
// show up as a golden diff.
//   flutter test --update-goldens test/madd_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/tajweed/tajweed.dart';

void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/UthmanicHafs_V22.ttf').readAsBytesSync();
    await (FontLoader('UthmanicHafs')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  });

  testWidgets('2:5 keeps its madd mark when tajweed colouring is on',
      (tester) async {
    final db = AppDatabase(NativeDatabase(File('dist/core.db')));
    final row = (await db
            .customSelect(
                'SELECT text, spans FROM tajweed_ayah WHERE surah=2 AND ayah=5')
            .get())
        .first;
    final text = row.read<String>('text');
    final spans = (jsonDecode(row.read<String>('spans')) as List)
        .map((s) => TajweedSpan(s[0] as int, s[1] as int, s[2] as String))
        .toList();
    await db.close();

    const base = TextStyle(
        fontFamily: 'UthmanicHafs', fontSize: 34, color: Colors.black);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: RepaintBoundary(
          key: const Key('madd'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Plain, for reference: this always drew the mark correctly.
              Text(text, textDirection: TextDirection.rtl, style: base),
              const SizedBox(height: 16),
              // Tajweed-coloured: the case that used to lose the maddah.
              Text.rich(
                TextSpan(
                  children: buildTajweedSpans(
                    text: text,
                    spans: spans,
                    disabledRules: const {},
                    activeWord: null,
                    base: base,
                    highlightColor: const Color(0x00000000),
                  ),
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    ));

    await expectLater(find.byKey(const Key('madd')),
        matchesGoldenFile('goldens/madd_2_5.png'));
  });
}
