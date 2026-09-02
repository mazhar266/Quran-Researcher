import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import 'font_mono.dart';
import 'page_fonts_web.dart' if (dart.library.ffi) 'page_fonts_native.dart';

const mushafPageCount = 604;

final _loadedFamilies = <String>{};

/// Loads the per-page QPC V4 font and returns its family name.
///
/// [mono] strips the font's colour tables so the glyphs take the theme's text
/// colour — needed on dark backgrounds, where the baked-in black is invisible.
final pageFontProvider =
    FutureProvider.family<String, ({int page, bool mono})>((ref, key) async {
  final family = 'QPC_V4${key.mono ? '_MONO' : ''}_P${key.page}';
  if (_loadedFamilies.add(family)) {
    try {
      final loader = FontLoader(family)
        ..addFont(key.mono
            ? pageFontBytes(key.page).then(stripColourTables)
            : pageFontBytes(key.page));
      await loader.load();
    } catch (e) {
      _loadedFamilies.remove(family);
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

/// Ayahs on one mushaf page in reading order.
///
/// The glyphs are QPC **V4** codes, which is what the shipped per-page fonts
/// actually encode (their internal name is QCF4001_COLOR). The V1 codes stored
/// in `ayah_text` have no matching font in this dataset and render as ordinary
/// Arabic letters through a fallback face.
final pageAyahsProvider =
    FutureProvider.family<List<MushafPageAyah>, int>((ref, page) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT m.surah, m.ayah, m.glyphs, a.juz FROM mushaf_page_text m '
    'JOIN ayahs a ON a.surah = m.surah AND a.ayah = m.ayah '
    'WHERE m.page = ?1 ORDER BY a.id',
    variables: [Variable.withInt(page)],
  ).get();
  return rows
      .map((r) => MushafPageAyah(
            surah: r.read<int>('surah'),
            ayah: r.read<int>('ayah'),
            glyphs: r.read<String>('glyphs'),
            juz: r.readNullable<int>('juz'),
          ))
      .toList();
});
