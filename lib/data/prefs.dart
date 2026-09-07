import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Loaded once in main() before runApp so settings are ready synchronously.
final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// The one Arabic script the reader offers. The others were dropped: the
/// IndoPak Nastaleeq data needs a font nobody ships, and Warsh and Hafs Smart
/// each render from an encoding the rest of the app's data is not keyed to.
/// Kept as a list so adding a script back is a one-line change.
const readerScripts = [
  (slug: 'qpc-hafs', family: 'UthmanicHafs', label: 'Uthmani (QPC Hafs)'),
];


class Settings {
  final String scriptSlug;
  final List<String> translationSlugs;
  final bool wordByWord;
  final bool transliteration;
  final double arabicFontSize;
  final ReadingTheme theme;
  final String reciterId;
  final String tafsirBookSlug;
  final bool tajweedColors;
  final List<String> tajweedDisabledRules;

  /// 'system' | 'en' | 'bn'
  final String appLanguage;

  const Settings({
    this.scriptSlug = 'qpc-hafs',
    this.translationSlugs = const ['en-sahih-international', 'bn-taisirul-quran'],
    this.wordByWord = false,
    this.transliteration = false,
    this.arabicFontSize = 28,
    this.theme = ReadingTheme.light,
    this.reciterId = '953',
    this.tafsirBookSlug = 'en-tafisr-ibn-kathir',
    this.tajweedColors = false,
    this.tajweedDisabledRules = const [],
    this.appLanguage = 'system',
  });

  String get fontFamily => readerScripts
      .firstWhere((s) => s.slug == scriptSlug, orElse: () => readerScripts[0])
      .family;

  /// qpc-hafs already ends each ayah with its Arabic number glyph.
  bool get scriptHasAyahMarker => scriptSlug == 'qpc-hafs';

  /// Tajweed markup is QPC-Hafs based, so coloring applies to Hafs scripts.
  bool get tajweedApplies => tajweedColors && fontFamily == 'UthmanicHafs';

  Settings copyWith({
    String? scriptSlug,
    List<String>? translationSlugs,
    bool? wordByWord,
    bool? transliteration,
    double? arabicFontSize,
    ReadingTheme? theme,
    String? reciterId,
    String? tafsirBookSlug,
    bool? tajweedColors,
    List<String>? tajweedDisabledRules,
    String? appLanguage,
  }) =>
      Settings(
        scriptSlug: scriptSlug ?? this.scriptSlug,
        translationSlugs: translationSlugs ?? this.translationSlugs,
        wordByWord: wordByWord ?? this.wordByWord,
        transliteration: transliteration ?? this.transliteration,
        arabicFontSize: arabicFontSize ?? this.arabicFontSize,
        theme: theme ?? this.theme,
        reciterId: reciterId ?? this.reciterId,
        tafsirBookSlug: tafsirBookSlug ?? this.tafsirBookSlug,
        tajweedColors: tajweedColors ?? this.tajweedColors,
        tajweedDisabledRules: tajweedDisabledRules ?? this.tajweedDisabledRules,
        appLanguage: appLanguage ?? this.appLanguage,
      );

  Map<String, dynamic> toJson() => {
        'script': scriptSlug,
        'translations': translationSlugs,
        'wbw': wordByWord,
        'translit': transliteration,
        'fontSize': arabicFontSize,
        'theme': theme.name,
        'reciter': reciterId,
        'tafsirBook': tafsirBookSlug,
        'tajweed': tajweedColors,
        'tajweedOff': tajweedDisabledRules,
        'lang': appLanguage,
      };

  /// A script that is no longer offered must not survive in saved settings,
  /// or the reader would query text it has no font for and draw tofu boxes.
  static String _knownScript(String? slug) =>
      readerScripts.any((s) => s.slug == slug) ? slug! : 'qpc-hafs';

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        scriptSlug: _knownScript(j['script'] as String?),
        translationSlugs: (j['translations'] as List?)?.cast<String>() ??
            const ['en-sahih-international', 'bn-taisirul-quran'],
        wordByWord: j['wbw'] as bool? ?? false,
        transliteration: j['translit'] as bool? ?? false,
        arabicFontSize: (j['fontSize'] as num?)?.toDouble() ?? 28,
        theme: ReadingTheme.values
            .firstWhere((t) => t.name == j['theme'], orElse: () => ReadingTheme.light),
        reciterId: j['reciter'] as String? ?? '953',
        tafsirBookSlug: j['tafsirBook'] as String? ?? 'en-tafisr-ibn-kathir',
        tajweedColors: j['tajweed'] as bool? ?? false,
        tajweedDisabledRules:
            (j['tajweedOff'] as List?)?.cast<String>() ?? const [],
        appLanguage: j['lang'] as String? ?? 'system',
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _key = 'settings';

  @override
  Settings build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const Settings();
    return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void update(Settings Function(Settings) fn) {
    state = fn(state);
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode(state.toJson()));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

class BookmarksNotifier extends Notifier<List<String>> {
  static const _key = 'bookmarks';

  @override
  List<String> build() =>
      ref.read(sharedPrefsProvider).getStringList(_key) ?? const [];

  void toggle(String verseKey) {
    state = state.contains(verseKey)
        ? state.where((k) => k != verseKey).toList()
        : [...state, verseKey];
    ref.read(sharedPrefsProvider).setStringList(_key, state);
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<String>>(BookmarksNotifier.new);

class LastReadNotifier extends Notifier<String?> {
  static const _key = 'lastRead';

  @override
  String? build() => ref.read(sharedPrefsProvider).getString(_key);

  void set(String verseKey) {
    state = verseKey;
    ref.read(sharedPrefsProvider).setString(_key, verseKey);
  }
}

final lastReadProvider =
    NotifierProvider<LastReadNotifier, String?>(LastReadNotifier.new);
