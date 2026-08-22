import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';
import 'models.dart';

/// All read access to core.db. The schema is fixed by etl/build.py, so plain
/// SQL against it is simpler than drift codegen for a database we never write.
class QuranRepo {
  QuranRepo(this._db);

  final AppDatabase _db;

  Future<List<Surah>> surahs() async {
    final rows = await _db.customSelect('SELECT * FROM surahs ORDER BY id').get();
    return rows
        .map((r) => Surah(
              id: r.read<int>('id'),
              name: r.read<String>('name'),
              nameSimple: r.read<String>('name_simple'),
              nameArabic: r.read<String>('name_arabic'),
              revelationPlace: r.read<String>('revelation_place'),
              revelationOrder: r.read<int>('revelation_order'),
              versesCount: r.read<int>('verses_count'),
              bismillahPre: r.read<int>('bismillah_pre') != 0,
            ))
        .toList();
  }

  Future<List<JuzInfo>> juzList() async {
    final rows = await _db
        .customSelect('SELECT juz, count(*) AS n, '
            '(SELECT verse_key FROM ayahs a2 WHERE a2.juz = a.juz '
            ' ORDER BY a2.id LIMIT 1) AS first_key '
            'FROM ayahs a GROUP BY juz ORDER BY juz')
        .get();
    return rows
        .map((r) => JuzInfo(
              number: r.read<int>('juz'),
              firstVerseKey: r.read<String>('first_key'),
              versesCount: r.read<int>('n'),
            ))
        .toList();
  }

  Future<List<TranslationResource>> translationResources() async {
    final rows = await _db
        .customSelect("SELECT id, slug, lang, name FROM resources "
            "WHERE kind='translation' ORDER BY lang, id")
        .get();
    return rows
        .map((r) => TranslationResource(
              id: r.read<int>('id'),
              slug: r.read<String>('slug'),
              lang: r.read<String>('lang'),
              name: r.read<String>('name'),
            ))
        .toList();
  }

  /// Everything the reader needs for one surah, in ayah order.
  Future<List<AyahView>> surahAyahs(
    int surah, {
    required String scriptSlug,
    required List<String> translationSlugs,
    required bool transliteration,
    required bool wordByWord,
    bool tajweed = false,
  }) async {
    final ayahRows = await _db.customSelect(
      'SELECT a.ayah, a.verse_key, a.page, a.juz, a.sajda_type, t.text '
      'FROM ayahs a JOIN ayah_text t ON t.surah = a.surah AND t.ayah = a.ayah '
      'JOIN scripts s ON s.id = t.script_id '
      'WHERE a.surah = ?1 AND s.slug = ?2 ORDER BY a.ayah',
      variables: [Variable.withInt(surah), Variable.withString(scriptSlug)],
    ).get();

    final words = <int, List<WordView>>{};
    if (wordByWord) {
      final wordRows = await _db.customSelect(
        'SELECT ayah, pos, text_qpc_hafs, tr_en, tr_bn FROM words '
        'WHERE surah = ?1 ORDER BY ayah, pos',
        variables: [Variable.withInt(surah)],
      ).get();
      for (final r in wordRows) {
        words.putIfAbsent(r.read<int>('ayah'), () => []).add(WordView(
              pos: r.read<int>('pos'),
              arabic: r.read<String>('text_qpc_hafs'),
              glossEn: r.readNullable<String>('tr_en'),
              glossBn: r.readNullable<String>('tr_bn'),
            ));
      }
    }

    final translations = <String, Map<int, String>>{};
    for (final slug in translationSlugs) {
      translations[slug] = await _resourceTexts(surah, slug);
    }
    final translit =
        transliteration ? await _resourceTexts(surah, 'translit-simple') : null;

    final tajweedRows = <int, (String, List<(int, int, String)>)>{};
    if (tajweed) {
      final rows = await _db.customSelect(
        'SELECT ayah, text, spans FROM tajweed_ayah WHERE surah = ?1',
        variables: [Variable.withInt(surah)],
      ).get();
      for (final r in rows) {
        final spans = (jsonDecode(r.read<String>('spans')) as List)
            .map((s) => (s[0] as int, s[1] as int, s[2] as String))
            .toList();
        tajweedRows[r.read<int>('ayah')] = (r.read<String>('text'), spans);
      }
    }

    return ayahRows.map((r) {
      final ayah = r.read<int>('ayah');
      return AyahView(
        surah: surah,
        ayah: ayah,
        verseKey: r.read<String>('verse_key'),
        arabic: r.read<String>('text'),
        page: r.readNullable<int>('page'),
        juz: r.readNullable<int>('juz'),
        sajdaType: r.readNullable<String>('sajda_type'),
        words: words[ayah] ?? const [],
        translations: {
          for (final slug in translationSlugs)
            if (translations[slug]![ayah] != null) slug: translations[slug]![ayah]!,
        },
        transliteration: translit?[ayah],
        tajweedText: tajweedRows[ayah]?.$1,
        tajweedSpans: tajweedRows[ayah]?.$2,
      );
    }).toList();
  }

  Future<Map<int, String>> _resourceTexts(int surah, String slug) async {
    final rows = await _db.customSelect(
      'SELECT t.ayah, t.text FROM translations t '
      'JOIN resources r ON r.id = t.resource_id '
      'WHERE t.surah = ?1 AND r.slug = ?2',
      variables: [Variable.withInt(surah), Variable.withString(slug)],
    ).get();
    return {for (final r in rows) r.read<int>('ayah'): r.read<String>('text')};
  }

  Future<String?> bismillah(String scriptSlug) async {
    final rows = await _db.customSelect(
      'SELECT text FROM ayah_text t JOIN scripts s ON s.id = t.script_id '
      'WHERE s.slug = ?1 AND t.surah = 1 AND t.ayah = 1',
      variables: [Variable.withString(scriptSlug)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('text');
  }

  Future<List<SearchHit>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    // Quote each term so user input can't break the FTS query syntax.
    final match = query
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => '"${t.replaceAll('"', '')}"')
        .join(' ');
    final rows = await _db.customSelect(
      "SELECT verse_key, "
      "snippet(fts_ayah, -1, '', '', '…', 24) AS snip "
      "FROM fts_ayah WHERE fts_ayah MATCH ?1 LIMIT 80",
      variables: [Variable.withString(match)],
    ).get();
    return rows
        .map((r) => SearchHit(
              verseKey: r.read<String>('verse_key'),
              snippet: r.read<String>('snip'),
              column: '',
            ))
        .toList();
  }
}

final repoProvider = FutureProvider<QuranRepo>((ref) async {
  return QuranRepo(await ref.watch(dbProvider.future));
});

final surahsProvider = FutureProvider<List<Surah>>((ref) async {
  return (await ref.watch(repoProvider.future)).surahs();
});

final juzListProvider = FutureProvider<List<JuzInfo>>((ref) async {
  return (await ref.watch(repoProvider.future)).juzList();
});

final translationResourcesProvider =
    FutureProvider<List<TranslationResource>>((ref) async {
  return (await ref.watch(repoProvider.future)).translationResources();
});
