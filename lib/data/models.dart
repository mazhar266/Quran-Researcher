class Surah {
  final int id;
  final String name;
  final String nameSimple;
  final String nameArabic;
  final String revelationPlace;
  final int revelationOrder;
  final int versesCount;
  final bool bismillahPre;

  const Surah({
    required this.id,
    required this.name,
    required this.nameSimple,
    required this.nameArabic,
    required this.revelationPlace,
    required this.revelationOrder,
    required this.versesCount,
    required this.bismillahPre,
  });
}

class JuzInfo {
  final int number;
  final String firstVerseKey;
  final int versesCount;

  const JuzInfo({
    required this.number,
    required this.firstVerseKey,
    required this.versesCount,
  });

  int get firstSurah => int.parse(firstVerseKey.split(':')[0]);
  int get firstAyah => int.parse(firstVerseKey.split(':')[1]);
}

class WordView {
  final int pos;
  final String arabic;
  final String? glossEn;
  final String? glossBn;

  const WordView({
    required this.pos,
    required this.arabic,
    this.glossEn,
    this.glossBn,
  });
}

class AyahView {
  final int surah;
  final int ayah;
  final String verseKey;
  final String arabic;
  final int? page;
  final int? juz;
  final String? sajdaType;
  final List<WordView> words;

  /// resource slug -> translated text, in the user's selected order.
  final Map<String, String> translations;
  final String? transliteration;

  /// Plain QPC-Hafs text + rule spans, present when tajweed mode is on.
  final String? tajweedText;
  final List<(int, int, String)>? tajweedSpans;

  const AyahView({
    required this.surah,
    required this.ayah,
    required this.verseKey,
    required this.arabic,
    required this.page,
    required this.juz,
    required this.sajdaType,
    required this.words,
    required this.translations,
    required this.transliteration,
    this.tajweedText,
    this.tajweedSpans,
  });
}

class TranslationResource {
  final int id;
  final String slug;
  final String lang;
  final String name;

  const TranslationResource({
    required this.id,
    required this.slug,
    required this.lang,
    required this.name,
  });
}

class SearchHit {
  final String verseKey;
  final String snippet;
  final String column; // which field matched: ar_simple / tr_en / tr_bn / translit

  const SearchHit({
    required this.verseKey,
    required this.snippet,
    required this.column,
  });

  int get surah => int.parse(verseKey.split(':')[0]);
  int get ayah => int.parse(verseKey.split(':')[1]);
}
