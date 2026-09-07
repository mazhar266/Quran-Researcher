// Renders a mushaf leaf so the paper treatment — frame, heading, page-number
// ornament — is pinned and reviewable.
//   flutter test --update-goldens test/mushaf_golden_test.dart
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/db.dart';
import 'package:quran_app/features/mushaf/mushaf_screen.dart';
import 'package:quran_app/l10n/l10n.dart';
import 'package:quran_app/mushaf/mushaf_providers.dart';

void main() {
  testWidgets('a mushaf leaf renders as a framed page', (tester) async {
    final bytes = File('assets/fonts/UthmanicHafs_V22.ttf').readAsBytesSync();
    await (FontLoader('UthmanicHafs')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
    // The page text is QPC V4 glyph codes, so load page 1's own face out of
    // the shipped pack — otherwise the leaf renders ornaments, not words.
    final pack = ZipDecoder()
        .decodeBytes(File('assets/fontpack_v4.zip').readAsBytesSync());
    final p1 = pack.files.firstWhere((f) => f.name == 'p1.ttf').content
        as List<int>;
    await (FontLoader('QPC_TEST_P1')
          ..addFont(Future.value(
              ByteData.sublistView(Uint8List.fromList(p1)))))
        .load();
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      dbProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase(File('dist/core.db')));
        ref.onDispose(db.close);
        return db;
      }),
      // The provider extracts from the zip via path_provider, which has no
      // filesystem here; the face itself is the real one, loaded above.
      pageFontProvider.overrideWith((ref, key) async => 'QPC_TEST_P1'),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MushafScreen(initialPage: 1),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(find.byType(MushafScreen),
        matchesGoldenFile('goldens/mushaf_leaf.png'));
  });
}
