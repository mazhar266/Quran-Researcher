import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';

/// Traditional sarf (صرف) analysis of one word, from the Quranic Arabic Corpus
/// annotation plus the bab/masdar derived at build time by etl/grammar.py.
class WordSarf {
  final String posTag; // N, V, P
  final int? verbForm; // I-X
  final String? aspect; // PERF / IMPF / IMPV
  final String? voice; // ACT / PASS
  final String? pgn; // 3MS, 1P, ...
  final String? mood; // IND / SUBJ / JUS
  final String? gcase; // NOM / ACC / GEN
  final bool? definite;
  final String? special; // ACT_PCPL / PASS_PCPL / VN / ADJ / PN
  final String? root;
  final String? lemma;
  final List<String> prefixes;
  final List<String> suffixes;

  // Derived per verb lemma (null when it could not be established honestly).
  final String? babAr;
  final String? babKey;
  final String? masdar;
  final String? masdarSource;

  const WordSarf({
    required this.posTag,
    this.verbForm,
    this.aspect,
    this.voice,
    this.pgn,
    this.mood,
    this.gcase,
    this.definite,
    this.special,
    this.root,
    this.lemma,
    this.prefixes = const [],
    this.suffixes = const [],
    this.babAr,
    this.babKey,
    this.masdar,
    this.masdarSource,
  });

  bool get isVerb => posTag == 'V';

  /// Roman numeral for the verb form, as the corpus labels it.
  String? get formRoman => switch (verbForm) {
        1 => 'I', 2 => 'II', 3 => 'III', 4 => 'IV', 5 => 'V',
        6 => 'VI', 7 => 'VII', 8 => 'VIII', 9 => 'IX', 10 => 'X',
        _ => null,
      };

  /// The sigah (صيغة) in Arabic: tense + voice + person/gender/number.
  String? get sigahAr {
    if (!isVerb || aspect == null) return null;
    final tense = switch (aspect) {
      'PERF' => 'مَاضِي',
      'IMPF' => 'مُضَارِع',
      'IMPV' => 'أَمْر',
      _ => null,
    };
    final v = voice == 'PASS' ? 'مَجْهُول' : 'مَعْرُوف';
    final person = _pgnAr[pgn];
    return [tense, v, ?person].whereType<String>().join(' · ');
  }

  static const _pgnAr = {
    '1S': 'مُتَكَلِّم وَحْدَهُ', '1P': 'مُتَكَلِّم مَعَ الغَيْر',
    '2MS': 'وَاحِد مُذَكَّر حَاضِر', '2MD': 'تَثْنِيَة مُذَكَّر حَاضِر',
    '2MP': 'جَمْع مُذَكَّر حَاضِر', '2FS': 'وَاحِدَة مُؤَنَّث حَاضِر',
    '2FD': 'تَثْنِيَة مُؤَنَّث حَاضِر', '2FP': 'جَمْع مُؤَنَّث حَاضِر',
    '2D': 'تَثْنِيَة حَاضِر',
    '3MS': 'وَاحِد مُذَكَّر غَائِب', '3MD': 'تَثْنِيَة مُذَكَّر غَائِب',
    '3MP': 'جَمْع مُذَكَّر غَائِب', '3FS': 'وَاحِدَة مُؤَنَّث غَائِب',
    '3FD': 'تَثْنِيَة مُؤَنَّث غَائِب', '3FP': 'جَمْع مُؤَنَّث غَائِب',
  };
}

final wordSarfProvider =
    FutureProvider.family.autoDispose<WordSarf?, String>((ref, location) async {
  final db = await ref.watch(dbProvider.future);
  final parts = location.split(':').map(int.parse).toList();
  final rows = await db.customSelect(
    'SELECT g.*, v.bab_ar, v.bab_key, v.masdar, v.masdar_source '
    'FROM word_grammar g '
    'LEFT JOIN verb_lemmas v ON v.lemma = g.lemma AND v.root = g.root '
    'WHERE g.surah = ?1 AND g.ayah = ?2 AND g.pos = ?3',
    variables: [for (final p in parts) Variable.withInt(p)],
  ).get();
  if (rows.isEmpty) return null;
  final r = rows.first;
  List<String> list(String col) {
    final raw = r.readNullable<String>(col);
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  return WordSarf(
    posTag: r.read<String>('pos_tag'),
    verbForm: r.readNullable<int>('verb_form'),
    aspect: r.readNullable<String>('aspect'),
    voice: r.readNullable<String>('voice'),
    pgn: r.readNullable<String>('pgn'),
    mood: r.readNullable<String>('mood'),
    gcase: r.readNullable<String>('gcase'),
    definite: r.readNullable<int>('definite') == null
        ? null
        : r.read<int>('definite') == 1,
    special: r.readNullable<String>('special'),
    root: r.readNullable<String>('root'),
    lemma: r.readNullable<String>('lemma'),
    prefixes: list('prefixes'),
    suffixes: list('suffixes'),
    babAr: r.readNullable<String>('bab_ar'),
    babKey: r.readNullable<String>('bab_key'),
    masdar: r.readNullable<String>('masdar'),
    masdarSource: r.readNullable<String>('masdar_source'),
  );
});
