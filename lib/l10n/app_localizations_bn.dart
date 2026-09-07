// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'কুরআন গবেষক';

  @override
  String get tabSurahs => 'সূরা';

  @override
  String get tabJuz => 'পারা';

  @override
  String get tabBookmarks => 'বুকমার্ক';

  @override
  String get tabResearch => 'গবেষণা';

  @override
  String get searchTooltip => 'অনুসন্ধান';

  @override
  String get settingsTooltip => 'সেটিংস';

  @override
  String continueReading(String verseKey) {
    return '$verseKey থেকে চালিয়ে যান';
  }

  @override
  String get makkah => 'মক্কী';

  @override
  String get madinah => 'মাদানী';

  @override
  String ayahsCount(int count) {
    return '$count আয়াত';
  }

  @override
  String juzTitle(int number) {
    return 'পারা $number';
  }

  @override
  String juzStartsAt(String verseKey, int count) {
    return '$verseKey থেকে শুরু · $count আয়াত';
  }

  @override
  String get noBookmarks =>
      'এখনও কোনো বুকমার্ক নেই — যেকোনো আয়াতের বুকমার্ক আইকনে চাপ দিন।';

  @override
  String get searchHint => 'আরবি, ইংরেজি, বাংলা বা উচ্চারণে খুঁজুন…';

  @override
  String get searchMinChars => 'খুঁজতে অন্তত দুটি অক্ষর লিখুন।';

  @override
  String get playFromHere => 'এখান থেকে শুনুন';

  @override
  String get tafsirTooltip => 'তাফসীর';

  @override
  String get researchTooltip => 'গবেষণা: সাদৃশ্যপূর্ণ আয়াত, বাক্যাংশ ও বিষয়';

  @override
  String get bookmarkAdd => 'বুকমার্ক করুন';

  @override
  String get bookmarkRemove => 'বুকমার্ক মুছুন';

  @override
  String get aboutSurah => 'সূরা পরিচিতি';

  @override
  String get mushafView => 'মুসহাফ পৃষ্ঠা';

  @override
  String get warshNotice =>
      'ওয়ারশ রিওয়ায়াত — এর আয়াত সংখ্যা হাফস থেকে ভিন্ন, তাই এই লিপিতে অনুবাদ, শব্দে-শব্দে অর্থ ও অডিও দেখানো হয় না।';

  @override
  String get sectionScript => 'আরবি লিপি';

  @override
  String get sectionFontSize => 'আরবি হরফের আকার';

  @override
  String get sectionTajweed => 'তাজবীদ';

  @override
  String get tajweedColors => 'তাজবীদ রং';

  @override
  String get tajweedColorsSub =>
      'উসমানী/QPC হাফস লিপিতে তিলাওয়াতের নিয়মগুলো রঙে দেখান';

  @override
  String get tajweedLegend => 'নিয়মের তালিকা ও টগল';

  @override
  String tajweedAllShown(int count) {
    return 'সব $countটি নিয়ম দেখানো হচ্ছে';
  }

  @override
  String tajweedHidden(int count) {
    return '$countটি নিয়ম লুকানো';
  }

  @override
  String get sectionDisplay => 'প্রদর্শন';

  @override
  String get wordByWord => 'শব্দে-শব্দে অর্থ';

  @override
  String get wordByWordSub => 'প্রতিটি শব্দের ইংরেজি ও বাংলা অর্থ দেখান';

  @override
  String get transliteration => 'উচ্চারণ (ট্রান্সলিটারেশন)';

  @override
  String get sectionTranslations => 'অনুবাদ';

  @override
  String get langEnglish => 'ইংরেজি';

  @override
  String get langBangla => 'বাংলা';

  @override
  String get sectionTheme => 'থিম';

  @override
  String get themeLight => 'উজ্জ্বল';

  @override
  String get themeDark => 'অন্ধকার';

  @override
  String get themeOled => 'নিকষ কালো (OLED)';

  @override
  String get themeSepia => 'সেপিয়া (কাগজ)';

  @override
  String get sectionLanguage => 'অ্যাপের ভাষা';

  @override
  String get langSystem => 'সিস্টেম অনুযায়ী';

  @override
  String get sectionAbout => 'পরিচিতি';

  @override
  String get aboutTitle => 'পরিচিতি ও তথ্যসূত্র';

  @override
  String get aboutSubtitle => 'কৃতজ্ঞতা, লাইসেন্স ও সংস্করণ';

  @override
  String get repeatOff => 'পুনরাবৃত্তি: বন্ধ';

  @override
  String get repeatAyah => 'পুনরাবৃত্তি: এই আয়াত';

  @override
  String get repeatRange => 'পুনরাবৃত্তি: পরিসর';

  @override
  String get previousAyah => 'আগের আয়াত';

  @override
  String get nextAyah => 'পরের আয়াত';

  @override
  String get play => 'চালান';

  @override
  String get pause => 'বিরতি';

  @override
  String get stop => 'বন্ধ';

  @override
  String get setRangeA => 'A নির্ধারণ';

  @override
  String get setRangeB => 'B নির্ধারণ';

  @override
  String ayahLabel(String verseKey) {
    return 'আয়াত $verseKey';
  }

  @override
  String get researchRoots => 'মূলধাতু (রুট) অনুসন্ধান';

  @override
  String get researchRootsSub =>
      '১,৬৪২টি ত্রিবর্ণী ধাতু — সম্পূর্ণ কুরআনে ব্যবহার ও আররামূয অভিধানসহ';

  @override
  String get researchPhrases => 'মুতাশাবিহাত';

  @override
  String get researchPhrasesSub =>
      'মুসহাফজুড়ে পুনরাবৃত্ত বাক্যাংশ — হিফয অনুশীলন মোডসহ';

  @override
  String get researchThemes => 'আয়াতের বিষয়বস্তু';

  @override
  String get researchThemesSub => 'প্রতিটি সূরার বিষয়ভিত্তিক অংশ';

  @override
  String get researchTopics => 'বিষয়সূচি (টপিক)';

  @override
  String get researchTopicsSub => '২,৫১২টি বিষয় — বিবরণ, আয়াত ও আন্তঃসংযোগসহ';

  @override
  String get researchTip =>
      'পরামর্শ: রিডারে (শব্দে-শব্দে মোডে) যেকোনো শব্দে চাপ দিলে তার গঠন ও অভিধান-ভুক্তি দেখা যায়, আর আয়াতের গবেষণা বোতামে সাদৃশ্যপূর্ণ আয়াত, অভিন্ন বাক্যাংশ ও বিষয়বস্তু পাওয়া যায়।';

  @override
  String hizbTitle(int number) {
    return 'হিযব $number';
  }

  @override
  String rukuTitle(int number) {
    return 'রুকু $number';
  }

  @override
  String manzilTitle(int number) {
    return 'মানযিল $number';
  }

  @override
  String rubTitle(int number) {
    return 'রুব $number';
  }

  @override
  String get sectionJuz => 'পারা';

  @override
  String get sectionHizb => 'হিযব';

  @override
  String get sectionRub => 'রুবউল হিযব';

  @override
  String get sectionRuku => 'রুকু';

  @override
  String get sectionManzil => 'মানযিল';

  @override
  String get sectionSajdah => 'সিজদাহ';

  @override
  String get sajdahObligatory => 'ওয়াজিব';

  @override
  String get sajdahRecommended => 'মুস্তাহাব';

  @override
  String get tabDivisions => 'বিভাগ';

  @override
  String pageTitle(int number) {
    return 'পৃষ্ঠা $number';
  }
}
