// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Quran Researcher';

  @override
  String get tabSurahs => 'Surahs';

  @override
  String get tabJuz => 'Juz';

  @override
  String get tabBookmarks => 'Bookmarks';

  @override
  String get tabResearch => 'Research';

  @override
  String get searchTooltip => 'Search';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String continueReading(String verseKey) {
    return 'Continue $verseKey';
  }

  @override
  String get makkah => 'Makkah';

  @override
  String get madinah => 'Madinah';

  @override
  String ayahsCount(int count) {
    return '$count ayahs';
  }

  @override
  String juzTitle(int number) {
    return 'Juz $number';
  }

  @override
  String juzStartsAt(String verseKey, int count) {
    return 'Starts at $verseKey · $count ayahs';
  }

  @override
  String get noBookmarks =>
      'No bookmarks yet — tap the bookmark icon on any ayah.';

  @override
  String get searchHint => 'Search Arabic, English, Bangla, transliteration…';

  @override
  String get searchMinChars => 'Type at least two characters to search.';

  @override
  String get playFromHere => 'Play from here';

  @override
  String get tafsirTooltip => 'Tafsir';

  @override
  String get researchTooltip => 'Research: similar ayahs, phrases, themes';

  @override
  String get bookmarkAdd => 'Bookmark';

  @override
  String get bookmarkRemove => 'Remove bookmark';

  @override
  String get aboutSurah => 'About this surah';

  @override
  String get mushafView => 'Mushaf page view';

  @override
  String get warshNotice =>
      'Warsh riwayah — its ayah numbering differs from Hafs, so translations, word-by-word, and audio are hidden in this script.';

  @override
  String get sectionScript => 'Arabic script';

  @override
  String get sectionFontSize => 'Arabic font size';

  @override
  String get sectionTajweed => 'Tajweed';

  @override
  String get tajweedColors => 'Tajweed colors';

  @override
  String get tajweedColorsSub =>
      'Color recitation rules in the Uthmani/QPC Hafs scripts';

  @override
  String get tajweedLegend => 'Rule legend & toggles';

  @override
  String tajweedAllShown(int count) {
    return 'All $count rules shown';
  }

  @override
  String tajweedHidden(int count) {
    return '$count rules hidden';
  }

  @override
  String get sectionDisplay => 'Display';

  @override
  String get wordByWord => 'Word-by-word glosses';

  @override
  String get wordByWordSub =>
      'Show each word with its English and Bangla meaning';

  @override
  String get transliteration => 'Transliteration';

  @override
  String get sectionTranslations => 'Translations';

  @override
  String get langEnglish => 'English';

  @override
  String get langBangla => 'Bangla';

  @override
  String get sectionTheme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeOled => 'True black (OLED)';

  @override
  String get themeSepia => 'Sepia (paper)';

  @override
  String get sectionLanguage => 'App language';

  @override
  String get langSystem => 'System default';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutTitle => 'About & data sources';

  @override
  String get aboutSubtitle => 'Attributions, licenses, and version';

  @override
  String get repeatOff => 'Repeat: off';

  @override
  String get repeatAyah => 'Repeat: this ayah';

  @override
  String get repeatRange => 'Repeat: range';

  @override
  String get previousAyah => 'Previous ayah';

  @override
  String get nextAyah => 'Next ayah';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get setRangeA => 'Set A';

  @override
  String get setRangeB => 'Set B';

  @override
  String ayahLabel(String verseKey) {
    return 'Ayah $verseKey';
  }

  @override
  String get researchRoots => 'Root explorer';

  @override
  String get researchRootsSub =>
      '1,642 trilateral roots with corpus-wide occurrences and the Arramooz dictionary';

  @override
  String get researchPhrases => 'Mutashabihat';

  @override
  String get researchPhrasesSub =>
      'Repeated phrases across the mushaf — with a hifz study mode';

  @override
  String get researchThemes => 'Ayah themes';

  @override
  String get researchThemesSub => 'Thematic sections of every surah';

  @override
  String get researchTopics => 'Topic ontology';

  @override
  String get researchTopicsSub =>
      '2,512 topics with descriptions, ayahs, and cross-links';

  @override
  String get researchTip =>
      'Tip: in the reader, tap any word (word-by-word mode) for its morphology and dictionary entry, or use the research button on an ayah for similar ayahs, shared phrases, and themes.';

  @override
  String hizbTitle(int number) {
    return 'Hizb $number';
  }

  @override
  String rukuTitle(int number) {
    return 'Ruku $number';
  }

  @override
  String manzilTitle(int number) {
    return 'Manzil $number';
  }

  @override
  String rubTitle(int number) {
    return 'Rub $number';
  }

  @override
  String get sectionJuz => 'Juz';

  @override
  String get sectionHizb => 'Hizb';

  @override
  String get sectionRub => 'Rub\' al-Hizb';

  @override
  String get sectionRuku => 'Ruku';

  @override
  String get sectionManzil => 'Manzil';

  @override
  String get sectionSajdah => 'Sajdah';

  @override
  String get sajdahObligatory => 'Obligatory';

  @override
  String get sajdahRecommended => 'Recommended';

  @override
  String get tabDivisions => 'Divisions';

  @override
  String pageTitle(int number) {
    return 'Page $number';
  }

  @override
  String get developer => 'Developer';

  @override
  String get goToPage => 'Go to page';

  @override
  String get ayahsOnPage => 'Ayahs on this page';

  @override
  String get goToPageTitle => 'Go to page (1–604)';

  @override
  String get cancel => 'Cancel';

  @override
  String get go => 'Go';

  @override
  String get downloadsTitle => 'Content downloads';

  @override
  String get downloadsSubtitle => 'Tafsir books, dictionary and mushaf fonts';

  @override
  String get downloadsGroupTafsirEn => 'Tafsir — English';

  @override
  String get downloadsGroupTafsirBn => 'Tafsir — বাংলা';

  @override
  String get downloadsGroupResearch => 'Research';

  @override
  String get downloadsGroupMushaf => 'Mushaf';

  @override
  String get dictModuleName => 'Arramooz classical Arabic dictionary';

  @override
  String get fontsModuleName => 'Mushaf page fonts (KFGQPC)';

  @override
  String get downloadAction => 'Download';

  @override
  String get downloadCancel => 'Cancel';

  @override
  String get downloadRetry => 'Retry';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadedLabel => 'Downloaded';

  @override
  String get downloadRemove => 'Remove';

  @override
  String get downloadRemoveConfirmTitle => 'Remove download?';

  @override
  String get downloadRemoveConfirmBody => 'You can download it again any time.';

  @override
  String downloadProgressOf(String received, String total) {
    return '$received of $total';
  }

  @override
  String get tafsirNeedsDownload => 'Tafsir not downloaded';

  @override
  String get tafsirNeedsDownloadBody =>
      'This tafsir book is not on your device yet. Download it once to read it any time, offline.';

  @override
  String get dictNeedsDownload => 'Dictionary not downloaded';

  @override
  String get dictNeedsDownloadBody =>
      'The Arramooz classical dictionary powers the word-research tools. Download it once to use them offline.';

  @override
  String get fontsNeedsDownload => 'Mushaf fonts not downloaded';

  @override
  String fontsNeedsDownloadBody(String size) {
    return 'Page mode is drawn with the KFGQPC page fonts — $size to download, about 160 MB on your device. Download once for offline page mode.';
  }

  @override
  String get downloadWebNote =>
      'On the web app, each tafsir, the dictionary and the mushaf fonts load automatically the first time you open them — no downloads to manage.';
}
