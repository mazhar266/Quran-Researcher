// Golden test for Arabic rendering: real KFGQPC font, tajweed coloring, and
// range highlighting. Regenerate after intentional visual changes with:
//   flutter test --update-goldens test/golden_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/features/research/widgets.dart';
import 'package:quran_app/tajweed/tajweed.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('UthmanicHafs', 'assets/fonts/UthmanicHafs_V22.ttf');
  });

  testWidgets('tajweed colors and range highlight render stably',
      (tester) async {
    // 1:1 in QPC Hafs with a representative subset of its rule spans.
    const text = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١';
    final tajweedSpans = buildTajweedSpans(
      text: text,
      spans: const [
        TajweedSpan(7, 8, 'ham_wasl'),
        TajweedSpan(14, 15, 'ham_wasl'),
        TajweedSpan(15, 16, 'laam_shamsiyah'),
        TajweedSpan(22, 24, 'madda_normal'),
      ],
      disabledRules: const {},
      activeWord: 2,
      base: const TextStyle(
          fontFamily: 'UthmanicHafs', fontSize: 30, color: Colors.black),
      highlightColor: const Color(0x6633CC99),
    );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: RepaintBoundary(
          key: const Key('golden'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(children: tajweedSpans),
                textDirection: TextDirection.rtl,
              ),
              const Padding(
                padding: EdgeInsets.all(8),
                child: ArabicRangeText(
                  text: text,
                  ranges: [
                    [3, 4]
                  ],
                  fontSize: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('goldens/arabic_rendering.png'),
    );
  });
}
