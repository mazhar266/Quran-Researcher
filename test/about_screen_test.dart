import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quran_app/data/prefs.dart';
import 'package:quran_app/features/about/about_screen.dart';
import 'package:quran_app/l10n/l10n.dart';

void main() {
  testWidgets('about screen shows the developer credit', (tester) async {
    final bytes = File('assets/fonts/UthmanicHafs_V22.ttf').readAsBytesSync();
    await (FontLoader('UthmanicHafs')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mazhar Ahmed'), findsOneWidget);
    expect(find.text('(Mazhar ibn Nasir ibn Naim)'), findsOneWidget);
    expect(find.text('BA in Islamic Studies from IOU'), findsOneWidget);
    expect(find.text('Dawra-e-Hadith from Qawmi Madrasa, Bangladesh'),
        findsOneWidget);
    expect(find.text('v${AboutScreen.version}'), findsOneWidget);
  });
}
