import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';

/// A mushaf division an ayah belongs to. The ETL stores juz, hizb, rubʿ,
/// rukuʿ and manzil for every ayah; these expose them for navigation and for
/// the stop markers a printed mushaf prints in the margin.
enum Division { juz, hizb, rub, ruku, manzil }

/// The divisions that *begin* at one ayah, so the reader can mark the stop.
class SectionStart {
  final int? juz;
  final int? hizb;

  /// 1..240. Four to a hizb, so the quarter within the hizb is what a mushaf
  /// marks with ۞: ¼, ½ (nisf) and ¾.
  final int? rub;
  final int? ruku;
  final int? manzil;

  const SectionStart({this.juz, this.hizb, this.rub, this.ruku, this.manzil});

  /// 0 = hizb start, 1 = ¼, 2 = ½, 3 = ¾.
  int? get rubQuarter => rub == null ? null : (rub! - 1) % 4;

  /// The hizb a rubʿ marker belongs to.
  int? get rubHizb => rub == null ? null : (rub! - 1) ~/ 4 + 1;

  bool get isEmpty =>
      juz == null && hizb == null && rub == null && ruku == null && manzil == null;
}

/// verse key -> the divisions starting there. ~900 entries, loaded once.
final sectionStartsProvider =
    FutureProvider<Map<String, SectionStart>>((ref) async {
  final db = await ref.watch(dbProvider.future);
  final starts = <String, Map<Division, int>>{};
  for (final d in Division.values) {
    final column = d.name;
    final rows = await db.customSelect(
      // The first ayah of each division, by mushaf order.
      'SELECT $column AS n, verse_key FROM ayahs '
      'WHERE id IN (SELECT min(id) FROM ayahs GROUP BY $column)',
    ).get();
    for (final r in rows) {
      starts
          .putIfAbsent(r.read<String>('verse_key'), () => {})[d] = r.read<int>('n');
    }
  }
  ref.keepAlive();
  return {
    for (final e in starts.entries)
      e.key: SectionStart(
        juz: e.value[Division.juz],
        hizb: e.value[Division.hizb],
        rub: e.value[Division.rub],
        ruku: e.value[Division.ruku],
        manzil: e.value[Division.manzil],
      ),
  };
});

class DivisionEntry {
  final int number;
  final String firstVerseKey;
  final int versesCount;

  /// Set for rubʿ: which hizb it falls in, and which quarter of it.
  final int? hizb;
  final int? quarter;

  const DivisionEntry({
    required this.number,
    required this.firstVerseKey,
    required this.versesCount,
    this.hizb,
    this.quarter,
  });

  int get surah => int.parse(firstVerseKey.split(':')[0]);
  int get ayah => int.parse(firstVerseKey.split(':')[1]);
}

/// Every entry of one division, in mushaf order.
final divisionListProvider = FutureProvider.family
    .autoDispose<List<DivisionEntry>, Division>((ref, division) async {
  final db = await ref.watch(dbProvider.future);
  final column = division.name;
  final rows = await db.customSelect(
    'SELECT $column AS n, count(*) AS c, '
    '(SELECT verse_key FROM ayahs x WHERE x.$column = a.$column '
    ' ORDER BY x.id LIMIT 1) AS first_key '
    'FROM ayahs a GROUP BY $column ORDER BY $column',
  ).get();
  return rows.map((r) {
    final n = r.read<int>('n');
    return DivisionEntry(
      number: n,
      firstVerseKey: r.read<String>('first_key'),
      versesCount: r.read<int>('c'),
      hizb: division == Division.rub ? (n - 1) ~/ 4 + 1 : null,
      quarter: division == Division.rub ? (n - 1) % 4 : null,
    );
  }).toList();
});

class SajdahEntry {
  final String verseKey;
  final String type; // 'required' | 'optional'
  final int surah;
  final int ayah;
  final int? page;

  const SajdahEntry({
    required this.verseKey,
    required this.type,
    required this.surah,
    required this.ayah,
    required this.page,
  });

  bool get isObligatory => type == 'required';
}

/// The 15 sajdah ayahs, in mushaf order.
final sajdahListProvider =
    FutureProvider.autoDispose<List<SajdahEntry>>((ref) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT verse_key, sajda_type, surah, ayah, page FROM ayahs '
    'WHERE sajda_type IS NOT NULL ORDER BY id',
  ).get();
  return rows
      .map((r) => SajdahEntry(
            verseKey: r.read<String>('verse_key'),
            type: r.read<String>('sajda_type'),
            surah: r.read<int>('surah'),
            ayah: r.read<int>('ayah'),
            page: r.readNullable<int>('page'),
          ))
      .toList();
});

/// The divisions an ayah sits inside — shown in the reader's position bar.
final ayahPositionProvider = FutureProvider.family
    .autoDispose<SectionStart?, String>((ref, verseKey) async {
  final db = await ref.watch(dbProvider.future);
  final parts = verseKey.split(':').map(int.parse).toList();
  final rows = await db.customSelect(
    'SELECT juz, hizb, rub, ruku, manzil FROM ayahs '
    'WHERE surah = ?1 AND ayah = ?2',
    variables: [Variable.withInt(parts[0]), Variable.withInt(parts[1])],
  ).get();
  if (rows.isEmpty) return null;
  final r = rows.first;
  return SectionStart(
    juz: r.readNullable<int>('juz'),
    hizb: r.readNullable<int>('hizb'),
    rub: r.readNullable<int>('rub'),
    ruku: r.readNullable<int>('ruku'),
    manzil: r.readNullable<int>('manzil'),
  );
});
