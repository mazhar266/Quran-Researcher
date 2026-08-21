// End-to-end tests for the audio and tafsir data layers against the real
// module databases in dist/ (run etl/build.py first).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/data/audio_repo.dart';
import 'package:quran_app/data/db.dart';
import 'package:quran_app/data/tafsir_repo.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    container = ProviderContainer(overrides: [
      moduleDbProvider.overrideWith((ref, name) {
        final file = File('dist/$name');
        assert(file.existsSync(), 'dist/$name missing — run etl/build.py');
        final db = AppDatabase(NativeDatabase(file));
        ref.onDispose(db.close);
        return db;
      }),
    ]);
  });

  tearDownAll(() => container.dispose());

  test('surah audio: 7 ayahs with word segments for Al-Fatihah', () async {
    final rows = await container
        .read(surahAudioProvider((surah: 1, reciterId: '953')).future);
    expect(rows.length, 7);
    expect(rows.first.verseKey, '1:1');
    expect(rows.first.url, startsWith('https://'));
    expect(rows.first.segments, isNotEmpty);
    // 1:1 segment 1 covers 0-560ms in the Afasy recording.
    expect(rows.first.wordAt(100), 1);
    expect(rows.first.wordAt(999999), isNull);
  });

  test('both reciters resolve', () async {
    for (final r in reciters) {
      final rows = await container
          .read(surahAudioProvider((surah: 112, reciterId: r.id)).future);
      expect(rows.length, 4, reason: r.name);
    }
  });

  test('tafsir: direct entry', () async {
    final t = await container.read(tafsirEntryProvider(
        (verseKey: '1:1', bookSlug: 'en-tafisr-ibn-kathir')).future);
    expect(t, isNotNull);
    expect(t!.groupKey, '1:1');
    expect(t.html, contains('Al-Fatihah'));
  });

  test('tafsir: grouped ayah follows alias (1:7 -> 1:6)', () async {
    final t = await container.read(tafsirEntryProvider(
        (verseKey: '1:7', bookSlug: 'en-tafisr-ibn-kathir')).future);
    expect(t, isNotNull);
    expect(t!.groupKey, '1:6');
    expect(t.html.length, greaterThan(1000));
  });

  test('all 10 tafsir books return text for 2:255', () async {
    for (final b in tafsirBooks) {
      final t = await container.read(
          tafsirEntryProvider((verseKey: '2:255', bookSlug: b.slug)).future);
      expect(t?.html, isNotEmpty, reason: b.slug);
    }
  });
}
