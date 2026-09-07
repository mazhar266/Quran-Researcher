import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran Researcher'**
  String get appTitle;

  /// No description provided for @tabSurahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get tabSurahs;

  /// No description provided for @tabJuz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get tabJuz;

  /// No description provided for @tabBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get tabBookmarks;

  /// No description provided for @tabResearch.
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get tabResearch;

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue {verseKey}'**
  String continueReading(String verseKey);

  /// No description provided for @makkah.
  ///
  /// In en, this message translates to:
  /// **'Makkah'**
  String get makkah;

  /// No description provided for @madinah.
  ///
  /// In en, this message translates to:
  /// **'Madinah'**
  String get madinah;

  /// No description provided for @ayahsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ayahs'**
  String ayahsCount(int count);

  /// No description provided for @juzTitle.
  ///
  /// In en, this message translates to:
  /// **'Juz {number}'**
  String juzTitle(int number);

  /// No description provided for @juzStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts at {verseKey} · {count} ayahs'**
  String juzStartsAt(String verseKey, int count);

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet — tap the bookmark icon on any ayah.'**
  String get noBookmarks;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Arabic, English, Bangla, transliteration…'**
  String get searchHint;

  /// No description provided for @searchMinChars.
  ///
  /// In en, this message translates to:
  /// **'Type at least two characters to search.'**
  String get searchMinChars;

  /// No description provided for @playFromHere.
  ///
  /// In en, this message translates to:
  /// **'Play from here'**
  String get playFromHere;

  /// No description provided for @tafsirTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tafsir'**
  String get tafsirTooltip;

  /// No description provided for @researchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Research: similar ayahs, phrases, themes'**
  String get researchTooltip;

  /// No description provided for @bookmarkAdd.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get bookmarkRemove;

  /// No description provided for @aboutSurah.
  ///
  /// In en, this message translates to:
  /// **'About this surah'**
  String get aboutSurah;

  /// No description provided for @mushafView.
  ///
  /// In en, this message translates to:
  /// **'Mushaf page view'**
  String get mushafView;

  /// No description provided for @warshNotice.
  ///
  /// In en, this message translates to:
  /// **'Warsh riwayah — its ayah numbering differs from Hafs, so translations, word-by-word, and audio are hidden in this script.'**
  String get warshNotice;

  /// No description provided for @sectionScript.
  ///
  /// In en, this message translates to:
  /// **'Arabic script'**
  String get sectionScript;

  /// No description provided for @sectionFontSize.
  ///
  /// In en, this message translates to:
  /// **'Arabic font size'**
  String get sectionFontSize;

  /// No description provided for @sectionTajweed.
  ///
  /// In en, this message translates to:
  /// **'Tajweed'**
  String get sectionTajweed;

  /// No description provided for @tajweedColors.
  ///
  /// In en, this message translates to:
  /// **'Tajweed colors'**
  String get tajweedColors;

  /// No description provided for @tajweedColorsSub.
  ///
  /// In en, this message translates to:
  /// **'Color recitation rules in the Uthmani/QPC Hafs scripts'**
  String get tajweedColorsSub;

  /// No description provided for @tajweedLegend.
  ///
  /// In en, this message translates to:
  /// **'Rule legend & toggles'**
  String get tajweedLegend;

  /// No description provided for @tajweedAllShown.
  ///
  /// In en, this message translates to:
  /// **'All {count} rules shown'**
  String tajweedAllShown(int count);

  /// No description provided for @tajweedHidden.
  ///
  /// In en, this message translates to:
  /// **'{count} rules hidden'**
  String tajweedHidden(int count);

  /// No description provided for @sectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get sectionDisplay;

  /// No description provided for @wordByWord.
  ///
  /// In en, this message translates to:
  /// **'Word-by-word glosses'**
  String get wordByWord;

  /// No description provided for @wordByWordSub.
  ///
  /// In en, this message translates to:
  /// **'Show each word with its English and Bangla meaning'**
  String get wordByWordSub;

  /// No description provided for @transliteration.
  ///
  /// In en, this message translates to:
  /// **'Transliteration'**
  String get transliteration;

  /// No description provided for @sectionTranslations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get sectionTranslations;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langBangla.
  ///
  /// In en, this message translates to:
  /// **'Bangla'**
  String get langBangla;

  /// No description provided for @sectionTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get sectionTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeOled.
  ///
  /// In en, this message translates to:
  /// **'True black (OLED)'**
  String get themeOled;

  /// No description provided for @themeSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia (paper)'**
  String get themeSepia;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get sectionLanguage;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get langSystem;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About & data sources'**
  String get aboutTitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attributions, licenses, and version'**
  String get aboutSubtitle;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat: off'**
  String get repeatOff;

  /// No description provided for @repeatAyah.
  ///
  /// In en, this message translates to:
  /// **'Repeat: this ayah'**
  String get repeatAyah;

  /// No description provided for @repeatRange.
  ///
  /// In en, this message translates to:
  /// **'Repeat: range'**
  String get repeatRange;

  /// No description provided for @previousAyah.
  ///
  /// In en, this message translates to:
  /// **'Previous ayah'**
  String get previousAyah;

  /// No description provided for @nextAyah.
  ///
  /// In en, this message translates to:
  /// **'Next ayah'**
  String get nextAyah;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @setRangeA.
  ///
  /// In en, this message translates to:
  /// **'Set A'**
  String get setRangeA;

  /// No description provided for @setRangeB.
  ///
  /// In en, this message translates to:
  /// **'Set B'**
  String get setRangeB;

  /// No description provided for @ayahLabel.
  ///
  /// In en, this message translates to:
  /// **'Ayah {verseKey}'**
  String ayahLabel(String verseKey);

  /// No description provided for @researchRoots.
  ///
  /// In en, this message translates to:
  /// **'Root explorer'**
  String get researchRoots;

  /// No description provided for @researchRootsSub.
  ///
  /// In en, this message translates to:
  /// **'1,642 trilateral roots with corpus-wide occurrences and the Arramooz dictionary'**
  String get researchRootsSub;

  /// No description provided for @researchPhrases.
  ///
  /// In en, this message translates to:
  /// **'Mutashabihat'**
  String get researchPhrases;

  /// No description provided for @researchPhrasesSub.
  ///
  /// In en, this message translates to:
  /// **'Repeated phrases across the mushaf — with a hifz study mode'**
  String get researchPhrasesSub;

  /// No description provided for @researchThemes.
  ///
  /// In en, this message translates to:
  /// **'Ayah themes'**
  String get researchThemes;

  /// No description provided for @researchThemesSub.
  ///
  /// In en, this message translates to:
  /// **'Thematic sections of every surah'**
  String get researchThemesSub;

  /// No description provided for @researchTopics.
  ///
  /// In en, this message translates to:
  /// **'Topic ontology'**
  String get researchTopics;

  /// No description provided for @researchTopicsSub.
  ///
  /// In en, this message translates to:
  /// **'2,512 topics with descriptions, ayahs, and cross-links'**
  String get researchTopicsSub;

  /// No description provided for @researchTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: in the reader, tap any word (word-by-word mode) for its morphology and dictionary entry, or use the research button on an ayah for similar ayahs, shared phrases, and themes.'**
  String get researchTip;

  /// No description provided for @hizbTitle.
  ///
  /// In en, this message translates to:
  /// **'Hizb {number}'**
  String hizbTitle(int number);

  /// No description provided for @rukuTitle.
  ///
  /// In en, this message translates to:
  /// **'Ruku {number}'**
  String rukuTitle(int number);

  /// No description provided for @manzilTitle.
  ///
  /// In en, this message translates to:
  /// **'Manzil {number}'**
  String manzilTitle(int number);

  /// No description provided for @rubTitle.
  ///
  /// In en, this message translates to:
  /// **'Rub {number}'**
  String rubTitle(int number);

  /// No description provided for @sectionJuz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get sectionJuz;

  /// No description provided for @sectionHizb.
  ///
  /// In en, this message translates to:
  /// **'Hizb'**
  String get sectionHizb;

  /// No description provided for @sectionRub.
  ///
  /// In en, this message translates to:
  /// **'Rub\' al-Hizb'**
  String get sectionRub;

  /// No description provided for @sectionRuku.
  ///
  /// In en, this message translates to:
  /// **'Ruku'**
  String get sectionRuku;

  /// No description provided for @sectionManzil.
  ///
  /// In en, this message translates to:
  /// **'Manzil'**
  String get sectionManzil;

  /// No description provided for @sectionSajdah.
  ///
  /// In en, this message translates to:
  /// **'Sajdah'**
  String get sectionSajdah;

  /// No description provided for @sajdahObligatory.
  ///
  /// In en, this message translates to:
  /// **'Obligatory'**
  String get sajdahObligatory;

  /// No description provided for @sajdahRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sajdahRecommended;

  /// No description provided for @tabDivisions.
  ///
  /// In en, this message translates to:
  /// **'Divisions'**
  String get tabDivisions;

  /// No description provided for @pageTitle.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String pageTitle(int number);

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
