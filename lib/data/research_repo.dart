import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';

// ---------------------------------------------------------------- morphology

class RootInfo {
  final int id;
  final String arabic; // spaced letters, e.g. 'ا ل ه'
  final String arabicNorm; // join key, e.g. 'اله'
  final String latin;
  final int wordsCount;
  final int uniqWordsCount;

  const RootInfo({
    required this.id,
    required this.arabic,
    required this.arabicNorm,
    required this.latin,
    required this.wordsCount,
    required this.uniqWordsCount,
  });

  String get display => arabic.replaceAll(RegExp(r'\s+'), ' ');
}

class WordMorphology {
  final String location;
  final String arabic;
  final String? glossEn;
  final String? glossBn;
  final RootInfo? root;
  final String? lemma;
  final String? stem;

  const WordMorphology({
    required this.location,
    required this.arabic,
    required this.glossEn,
    required this.glossBn,
    required this.root,
    required this.lemma,
    required this.stem,
  });
}

final wordMorphologyProvider = FutureProvider.family
    .autoDispose<WordMorphology?, String>((ref, location) async {
  final db = await ref.watch(dbProvider.future);
  final parts = location.split(':').map(int.parse).toList();
  final word = await db.customSelect(
    'SELECT text_qpc_hafs, tr_en, tr_bn FROM words '
    'WHERE surah = ?1 AND ayah = ?2 AND pos = ?3',
    variables: [for (final p in parts) Variable.withInt(p)],
  ).get();
  if (word.isEmpty) return null;

  Future<QueryRow?> one(String sql) async {
    final rows = await db.customSelect(sql,
        variables: [Variable.withString(location)]).get();
    return rows.firstOrNull;
  }

  final root = await one(
      'SELECT r.* FROM word_roots wr JOIN roots r ON r.id = wr.root_id '
      'WHERE wr.location = ?1');
  final lemma = await one(
      'SELECT l.text FROM word_lemmas wl JOIN lemmas l ON l.id = wl.lemma_id '
      'WHERE wl.location = ?1');
  final stem = await one(
      'SELECT s.text FROM word_stems ws JOIN stems s ON s.id = ws.stem_id '
      'WHERE ws.location = ?1');

  return WordMorphology(
    location: location,
    arabic: word.first.read<String>('text_qpc_hafs'),
    glossEn: word.first.readNullable<String>('tr_en'),
    glossBn: word.first.readNullable<String>('tr_bn'),
    root: root == null ? null : _rootFrom(root),
    lemma: lemma?.read<String>('text'),
    stem: stem?.read<String>('text'),
  );
});

RootInfo _rootFrom(QueryRow r) => RootInfo(
      id: r.read<int>('id'),
      arabic: r.read<String>('arabic'),
      arabicNorm: r.read<String>('arabic_norm'),
      latin: r.read<String>('latin'),
      wordsCount: r.read<int>('words_count'),
      uniqWordsCount: r.read<int>('uniq_words_count'),
    );

/// Roots ordered by frequency; [query] filters by Arabic letters or the
/// Buckwalter-style latin key.
final rootSearchProvider = FutureProvider.family
    .autoDispose<List<RootInfo>, String>((ref, query) async {
  final db = await ref.watch(dbProvider.future);
  final q = query.trim();
  final rows = await db.customSelect(
    q.isEmpty
        ? 'SELECT * FROM roots ORDER BY words_count DESC LIMIT 200'
        : "SELECT * FROM roots WHERE replace(arabic, ' ', '') LIKE ?1 "
            "OR arabic_norm LIKE ?1 OR latin LIKE ?1 "
            'ORDER BY words_count DESC LIMIT 200',
    variables: q.isEmpty ? const [] : [Variable.withString('%$q%')],
  ).get();
  return rows.map(_rootFrom).toList();
});

final rootProvider =
    FutureProvider.family.autoDispose<RootInfo?, int>((ref, id) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect('SELECT * FROM roots WHERE id = ?1',
      variables: [Variable.withInt(id)]).get();
  return rows.isEmpty ? null : _rootFrom(rows.first);
});

class RootOccurrence {
  final String location;
  final int surah;
  final int ayah;
  final String word;
  final String? glossEn;

  const RootOccurrence({
    required this.location,
    required this.surah,
    required this.ayah,
    required this.word,
    required this.glossEn,
  });

  String get verseKey => '$surah:$ayah';
}

final rootOccurrencesProvider = FutureProvider.family
    .autoDispose<List<RootOccurrence>, int>((ref, rootId) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT wr.location, wr.surah, wr.ayah, w.text_qpc_hafs, w.tr_en '
    'FROM word_roots wr '
    'JOIN words w ON w.surah = wr.surah AND w.ayah = wr.ayah AND w.pos = wr.pos '
    'WHERE wr.root_id = ?1 ORDER BY wr.surah, wr.ayah, wr.pos',
    variables: [Variable.withInt(rootId)],
  ).get();
  return rows
      .map((r) => RootOccurrence(
            location: r.read<String>('location'),
            surah: r.read<int>('surah'),
            ayah: r.read<int>('ayah'),
            word: r.read<String>('text_qpc_hafs'),
            glossEn: r.readNullable<String>('tr_en'),
          ))
      .toList();
});

// ---------------------------------------------------------------- dictionary

class DictNoun {
  final String vocalized;
  final String wordType;
  final String wazn;
  final String definition;

  const DictNoun({
    required this.vocalized,
    required this.wordType,
    required this.wazn,
    required this.definition,
  });
}

class DictVerb {
  final String vocalized;
  final bool transitive;

  const DictVerb({required this.vocalized, required this.transitive});
}

/// Arramooz classical dictionary entries for a normalized root.
final dictEntriesProvider = FutureProvider.family
    .autoDispose<({List<DictNoun> nouns, List<DictVerb> verbs}), String>(
        (ref, rootNorm) async {
  final db = await ref.watch(moduleDbProvider('dict_ar.db').future);
  final nouns = await db.customSelect(
    'SELECT vocalized, wordtype, wazn, definition FROM nouns '
    'WHERE root_norm = ?1 ORDER BY id LIMIT 60',
    variables: [Variable.withString(rootNorm)],
  ).get();
  final verbs = await db.customSelect(
    'SELECT vocalized, transitive FROM verbs '
    'WHERE root_norm = ?1 ORDER BY id LIMIT 40',
    variables: [Variable.withString(rootNorm)],
  ).get();
  return (
    nouns: nouns
        .map((r) => DictNoun(
              vocalized: r.read<String>('vocalized'),
              wordType: r.readNullable<String>('wordtype') ?? '',
              wazn: r.readNullable<String>('wazn') ?? '',
              definition: r.readNullable<String>('definition') ?? '',
            ))
        .toList(),
    verbs: verbs
        .map((r) => DictVerb(
              vocalized: r.read<String>('vocalized'),
              transitive: (r.readNullable<int>('transitive') ?? 0) != 0,
            ))
        .toList(),
  );
});

// -------------------------------------------------------------- similarities

class SimilarMatch {
  final String matchedKey;
  final int score;
  final int coverage;

  /// 1-based inclusive word ranges within the *matched* ayah.
  final List<List<int>> ranges;
  final String matchedText;

  const SimilarMatch({
    required this.matchedKey,
    required this.score,
    required this.coverage,
    required this.ranges,
    required this.matchedText,
  });
}

Future<String?> _ayahText(AppDatabase db, int surah, int ayah) async {
  final rows = await db.customSelect(
    "SELECT t.text FROM ayah_text t JOIN scripts s ON s.id = t.script_id "
    "WHERE s.slug = 'qpc-hafs' AND t.surah = ?1 AND t.ayah = ?2",
    variables: [Variable.withInt(surah), Variable.withInt(ayah)],
  ).get();
  return rows.firstOrNull?.read<String>('text');
}

final similarAyahsProvider = FutureProvider.family
    .autoDispose<List<SimilarMatch>, (int, int)>((ref, key) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT matched_key, score, coverage, ranges FROM similar_ayahs '
    'WHERE surah = ?1 AND ayah = ?2 ORDER BY score DESC',
    variables: [Variable.withInt(key.$1), Variable.withInt(key.$2)],
  ).get();
  final result = <SimilarMatch>[];
  for (final r in rows) {
    final mk = r.read<String>('matched_key').split(':');
    final text = await _ayahText(db, int.parse(mk[0]), int.parse(mk[1]));
    result.add(SimilarMatch(
      matchedKey: r.read<String>('matched_key'),
      score: r.read<int>('score'),
      coverage: r.read<int>('coverage'),
      ranges: (jsonDecode(r.read<String>('ranges')) as List)
          .map((x) => (x as List).cast<int>())
          .toList(),
      matchedText: text ?? '',
    ));
  }
  return result;
});

// -------------------------------------------------------------- mutashabihat

class PhraseInfo {
  final int id;
  final String sourceKey;
  final int fromWord;
  final int toWord;
  final int surahsCount;
  final int ayahsCount;
  final int occurrences;

  const PhraseInfo({
    required this.id,
    required this.sourceKey,
    required this.fromWord,
    required this.toWord,
    required this.surahsCount,
    required this.ayahsCount,
    required this.occurrences,
  });
}

PhraseInfo _phraseFrom(QueryRow r) => PhraseInfo(
      id: r.read<int>('id'),
      sourceKey: r.read<String>('source_key'),
      fromWord: r.read<int>('from_word'),
      toWord: r.read<int>('to_word'),
      surahsCount: r.read<int>('surahs_count'),
      ayahsCount: r.read<int>('ayahs_count'),
      occurrences: r.read<int>('occurrences'),
    );

/// Most-repeated phrases across the mushaf (hifz study entry point).
final phrasesProvider =
    FutureProvider.autoDispose<List<PhraseInfo>>((ref) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
      'SELECT * FROM phrases ORDER BY occurrences DESC LIMIT 300').get();
  return rows.map(_phraseFrom).toList();
});

/// Phrases that occur in one specific ayah.
final ayahPhrasesProvider = FutureProvider.family
    .autoDispose<List<PhraseInfo>, (int, int)>((ref, key) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT p.* FROM phrase_occurrences po JOIN phrases p ON p.id = po.phrase_id '
    'WHERE po.surah = ?1 AND po.ayah = ?2 ORDER BY p.occurrences DESC',
    variables: [Variable.withInt(key.$1), Variable.withInt(key.$2)],
  ).get();
  return rows.map(_phraseFrom).toList();
});

class PhraseOccurrence {
  final String verseKey;
  final int surah;
  final int ayah;
  final List<List<int>> ranges;
  final String text;

  const PhraseOccurrence({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.ranges,
    required this.text,
  });
}

final phraseOccurrencesProvider = FutureProvider.family
    .autoDispose<List<PhraseOccurrence>, int>((ref, phraseId) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT po.verse_key, po.surah, po.ayah, po.ranges, t.text '
    'FROM phrase_occurrences po '
    'JOIN ayah_text t ON t.surah = po.surah AND t.ayah = po.ayah '
    "JOIN scripts s ON s.id = t.script_id AND s.slug = 'qpc-hafs' "
    'WHERE po.phrase_id = ?1 ORDER BY po.surah, po.ayah',
    variables: [Variable.withInt(phraseId)],
  ).get();
  return rows
      .map((r) => PhraseOccurrence(
            verseKey: r.read<String>('verse_key'),
            surah: r.read<int>('surah'),
            ayah: r.read<int>('ayah'),
            ranges: (jsonDecode(r.read<String>('ranges')) as List)
                .map((x) => (x as List).cast<int>())
                .toList(),
            text: r.read<String>('text'),
          ))
      .toList();
});

// -------------------------------------------------------------------- themes

class ThemeEntry {
  final int surah;
  final int ayahFrom;
  final int ayahTo;
  final String theme;

  const ThemeEntry({
    required this.surah,
    required this.ayahFrom,
    required this.ayahTo,
    required this.theme,
  });
}

final themeSearchProvider = FutureProvider.family
    .autoDispose<List<ThemeEntry>, String>((ref, query) async {
  final db = await ref.watch(dbProvider.future);
  final q = query.trim();
  final rows = await db.customSelect(
    q.isEmpty
        ? 'SELECT * FROM themes ORDER BY surah, ayah_from'
        : 'SELECT * FROM themes WHERE theme LIKE ?1 ORDER BY surah, ayah_from',
    variables: q.isEmpty ? const [] : [Variable.withString('%$q%')],
  ).get();
  return rows
      .map((r) => ThemeEntry(
            surah: r.read<int>('surah'),
            ayahFrom: r.read<int>('ayah_from'),
            ayahTo: r.read<int>('ayah_to'),
            theme: r.read<String>('theme'),
          ))
      .toList();
});

final ayahThemesProvider = FutureProvider.family
    .autoDispose<List<ThemeEntry>, (int, int)>((ref, key) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT * FROM themes WHERE surah = ?1 AND ayah_from <= ?2 AND ayah_to >= ?2',
    variables: [Variable.withInt(key.$1), Variable.withInt(key.$2)],
  ).get();
  return rows
      .map((r) => ThemeEntry(
            surah: r.read<int>('surah'),
            ayahFrom: r.read<int>('ayah_from'),
            ayahTo: r.read<int>('ayah_to'),
            theme: r.read<String>('theme'),
          ))
      .toList();
});

// -------------------------------------------------------------------- topics

class TopicInfo {
  final int id;
  final String name;
  final String? arabicName;
  final int? parentId;
  final String? description;
  final List<String> ayahs;
  final int childCount;

  const TopicInfo({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.parentId,
    required this.description,
    required this.ayahs,
    required this.childCount,
  });
}

List<String> _topicAyahs(String? raw) {
  if (raw == null || raw == 'null') return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! String || decoded.trim().isEmpty) return const [];
  return decoded
      .split(',')
      .map((s) => s.trim())
      .where((s) => RegExp(r'^\d+:\d+$').hasMatch(s))
      .toList();
}

TopicInfo _topicFrom(QueryRow r) => TopicInfo(
      id: r.read<int>('id'),
      name: r.read<String>('name'),
      arabicName: r.readNullable<String>('arabic_name'),
      parentId: r.readNullable<int>('parent_id'),
      description: r.readNullable<String>('description'),
      ayahs: _topicAyahs(r.readNullable<String>('ayahs')),
      childCount: r.read<int>('child_count'),
    );

const _topicCols = 't.*, (SELECT count(*) FROM topics c WHERE c.parent_id = t.id) AS child_count';

final topicSearchProvider = FutureProvider.family
    .autoDispose<List<TopicInfo>, String>((ref, query) async {
  final db = await ref.watch(dbProvider.future);
  final q = query.trim();
  final rows = await db.customSelect(
    q.isEmpty
        ? 'SELECT $_topicCols FROM topics t WHERE t.description IS NOT NULL '
            'ORDER BY t.name LIMIT 300'
        : 'SELECT $_topicCols FROM topics t WHERE t.name LIKE ?1 '
            'OR t.arabic_name LIKE ?1 ORDER BY t.name LIMIT 300',
    variables: q.isEmpty ? const [] : [Variable.withString('%$q%')],
  ).get();
  return rows.map(_topicFrom).toList();
});

final topicProvider =
    FutureProvider.family.autoDispose<TopicInfo?, int>((ref, id) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
      'SELECT $_topicCols FROM topics t WHERE t.id = ?1',
      variables: [Variable.withInt(id)]).get();
  return rows.isEmpty ? null : _topicFrom(rows.first);
});

final topicChildrenProvider = FutureProvider.family
    .autoDispose<List<TopicInfo>, int>((ref, id) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
      'SELECT $_topicCols FROM topics t WHERE t.parent_id = ?1 ORDER BY t.name',
      variables: [Variable.withInt(id)]).get();
  return rows.map(_topicFrom).toList();
});

// --------------------------------------------------------------- surah info

final surahInfoProvider =
    FutureProvider.family.autoDispose<String?, int>((ref, surah) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
      'SELECT text FROM surah_info WHERE surah = ?1',
      variables: [Variable.withInt(surah)]).get();
  return rows.firstOrNull?.readNullable<String>('text');
});
