import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import 'page_fonts_web.dart' if (dart.library.ffi) 'page_fonts_native.dart';

const mushafPageCount = 604;

final _loadedPages = <int>{};

/// Loads the per-page QPC V1 font and returns its family name.
final pageFontProvider = FutureProvider.family<String, int>((ref, page) async {
  final family = 'QPC_P$page';
  if (_loadedPages.add(page)) {
    try {
      final loader = FontLoader(family)..addFont(pageFontBytes(page));
      await loader.load();
    } catch (e) {
      _loadedPages.remove(page);
      rethrow;
    }
  }
  ref.keepAlive();
  return family;
});

class MushafPageAyah {
  final int surah;
  final int ayah;
  final String glyphs;
  final int? juz;

  const MushafPageAyah({
    required this.surah,
    required this.ayah,
    required this.glyphs,
    required this.juz,
  });
}

/// Ayahs on one mushaf page in reading order (QPC V1 glyph codes).
final pageAyahsProvider =
    FutureProvider.family<List<MushafPageAyah>, int>((ref, page) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    "SELECT a.surah, a.ayah, a.juz, t.text FROM ayahs a "
    "JOIN ayah_text t ON t.surah = a.surah AND t.ayah = a.ayah "
    "JOIN scripts s ON s.id = t.script_id "
    "WHERE s.slug = 'qpc-v1-glyph' AND a.page = ?1 ORDER BY a.id",
    variables: [Variable.withInt(page)],
  ).get();
  return rows
      .map((r) => MushafPageAyah(
            surah: r.read<int>('surah'),
            ayah: r.read<int>('ayah'),
            glyphs: r.read<String>('text'),
            juz: r.readNullable<int>('juz'),
          ))
      .toList();
});
