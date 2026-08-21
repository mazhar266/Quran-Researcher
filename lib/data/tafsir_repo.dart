import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db.dart';

class TafsirBook {
  final String slug; // matches tafsir_<slug>.db
  final String lang;
  final String name;

  const TafsirBook({required this.slug, required this.lang, required this.name});
}

const tafsirBooks = [
  TafsirBook(slug: 'en-tafisr-ibn-kathir', lang: 'en', name: 'Tafsir Ibn Kathir (abridged)'),
  TafsirBook(slug: 'en-tafsir-maarif-ul-quran', lang: 'en', name: "Ma'arif-ul-Quran"),
  TafsirBook(slug: 'tafsir-al-jalalayn', lang: 'en', name: 'Tafsir al-Jalalayn'),
  TafsirBook(slug: 'tazkirul-quran-en', lang: 'en', name: 'Tazkirul Quran'),
  TafsirBook(slug: 'abridged-explanation-of-the-quran', lang: 'en', name: 'Abridged Explanation (Mukhtasar)'),
  TafsirBook(slug: 'bn-tafseer-ibn-e-kaseer', lang: 'bn', name: 'তাফসীর ইবনে কাসীর'),
  TafsirBook(slug: 'bn-tafsir-abu-bakr-zakaria', lang: 'bn', name: 'তাফসীর আবু বকর যাকারিয়া'),
  TafsirBook(slug: 'bn-tafsir-ahsanul-bayaan', lang: 'bn', name: 'তাফসীর আহসানুল বায়ান'),
  TafsirBook(slug: 'tafisr-fathul-majid-bn', lang: 'bn', name: 'ফাতহুল মাজীদ'),
  TafsirBook(slug: 'bengali-mokhtasar', lang: 'bn', name: 'আল-মুখতাসার (বাংলা)'),
];

class TafsirEntry {
  final String bookSlug;

  /// The verse key this text is anchored at — for grouped entries this is the
  /// first ayah of the group (e.g. 1:7's tafsir lives under 1:6).
  final String groupKey;
  final String html;

  const TafsirEntry({
    required this.bookSlug,
    required this.groupKey,
    required this.html,
  });
}

/// Tafsir text for one ayah from one book, following group aliases
/// ("1:7" -> text stored under "1:6").
final tafsirEntryProvider = FutureProvider.family
    .autoDispose<TafsirEntry?, ({String verseKey, String bookSlug})>((ref, key) async {
  final db = await ref.watch(moduleDbProvider('tafsir_${key.bookSlug}.db').future);
  final parts = key.verseKey.split(':');

  Future<({String? groupKey, String? text})?> fetch(int surah, int ayah) async {
    final rows = await db.customSelect(
      'SELECT group_key, text FROM tafsir WHERE surah = ?1 AND ayah = ?2',
      variables: [Variable.withInt(surah), Variable.withInt(ayah)],
    ).get();
    if (rows.isEmpty) return null;
    return (
      groupKey: rows.first.readNullable<String>('group_key'),
      text: rows.first.readNullable<String>('text'),
    );
  }

  var row = await fetch(int.parse(parts[0]), int.parse(parts[1]));
  if (row == null) return null;
  var anchor = key.verseKey;
  if (row.text == null && row.groupKey != null) {
    // Alias row: group_key names the anchor ayah that holds the text.
    anchor = row.groupKey!;
    final ap = anchor.split(':');
    row = await fetch(int.parse(ap[0]), int.parse(ap[1]));
    if (row?.text == null) return null;
  }
  final html = row!.text;
  if (html == null || html.trim().isEmpty) return null;
  return TafsirEntry(bookSlug: key.bookSlug, groupKey: anchor, html: html);
});
