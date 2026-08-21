import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';

class Reciter {
  final String id; // matches audio_<id>.db
  final String name;

  const Reciter({required this.id, required this.name});
}

const reciters = [
  Reciter(id: '953', name: 'Mishari Rashid al-Afasy'),
  Reciter(id: '957', name: 'Mahmoud Khalil al-Husary'),
];

class AyahAudio {
  final int surah;
  final int ayah;
  final String url;

  /// [[wordPos, startMs, endMs], ...] — word-level recitation timings.
  final List<List<int>> segments;

  const AyahAudio({
    required this.surah,
    required this.ayah,
    required this.url,
    required this.segments,
  });

  String get verseKey => '$surah:$ayah';

  /// The word being recited at [positionMs], or null between words.
  int? wordAt(int positionMs) {
    for (final s in segments) {
      if (positionMs >= s[1] && positionMs < s[2]) return s[0];
    }
    return null;
  }
}

/// All ayah audio rows for one surah from one reciter, in ayah order.
final surahAudioProvider = FutureProvider.family
    .autoDispose<List<AyahAudio>, ({int surah, String reciterId})>((ref, key) async {
  final db = await ref.watch(moduleDbProvider('audio_${key.reciterId}.db').future);
  final rows = await db.customSelect(
    'SELECT surah, ayah, url, segments FROM ayah_audio '
    'WHERE surah = ?1 ORDER BY ayah',
    variables: [Variable.withInt(key.surah)],
  ).get();
  return rows.map((r) {
    final raw = r.readNullable<String>('segments');
    final segments = raw == null || raw == 'null'
        ? const <List<int>>[]
        : (jsonDecode(raw) as List)
            .map((s) => (s as List).cast<int>())
            .toList();
    return AyahAudio(
      surah: r.read<int>('surah'),
      ayah: r.read<int>('ayah'),
      url: r.read<String>('url'),
      segments: segments,
    );
  }).toList();
});
