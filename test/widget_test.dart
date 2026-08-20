import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_app/data/models.dart';
import 'package:quran_app/data/prefs.dart';
import 'package:quran_app/data/repo.dart';
import 'package:quran_app/main.dart';

const _fatiha = Surah(
  id: 1,
  name: 'Al-Fātiĥah',
  nameSimple: 'Al-Fatihah',
  nameArabic: 'الفاتحة',
  revelationPlace: 'makkah',
  revelationOrder: 5,
  versesCount: 7,
  bismillahPre: false,
);

void main() {
  testWidgets('home shows surah list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        surahsProvider.overrideWith((ref) async => const [_fatiha]),
        juzListProvider.overrideWith((ref) async => const [
              JuzInfo(number: 1, firstVerseKey: '1:1', versesCount: 148),
            ]),
      ],
      child: const QuranApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Quran Researcher'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsOneWidget);
    expect(find.text('Makkah · 7 ayahs'), findsOneWidget);
  });
}
