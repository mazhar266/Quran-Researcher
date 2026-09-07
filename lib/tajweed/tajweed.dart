import 'package:flutter/gestures.dart' show GestureRecognizer;
import 'package:flutter/material.dart';

/// One pre-parsed tajweed annotation: [start, end) in code points of the
/// plain ayah text (produced by etl/build.py from QPC's rule markup).
class TajweedSpan {
  final int start;
  final int end;
  final String rule;

  const TajweedSpan(this.start, this.end, this.rule);
}

class TajweedRule {
  final String slug;
  final String label;

  /// The rule's classical Arabic name, and its Bengali madrasa name.
  final String arabic;
  final String bangla;

  /// How long the letter is held, where the rule prescribes a length.
  /// A ḥaraka is one count — the time to say a short vowel.
  final String? harakat;
  final Color color;

  const TajweedRule(this.slug, this.label, this.arabic, this.bangla,
      this.color, {this.harakat});
}

/// Standard QPC Hafs tajweed palette (as used by quran.com / QUL).
const tajweedRules = [
  TajweedRule('ham_wasl', 'Hamzat al-Wasl', 'همزة وصل', 'হামযাতুল ওয়াসল',
      Color(0xFFAAAAAA)),
  TajweedRule('slnt', 'Silent', 'حرف لا ينطق', 'সাকিন / উচ্চারিত হয় না',
      Color(0xFFAAAAAA)),
  TajweedRule('laam_shamsiyah', 'Lam Shamsiyyah', 'لام شمسية', 'লামে শামসিয়্যাহ',
      Color(0xFFAAAAAA)),
  TajweedRule('madda_normal', 'Normal Madd', 'مد طبيعي', 'মদ্দে তবীঈ',
      Color(0xFF537FFF), harakat: '2'),
  TajweedRule('madda_permissible', 'Permissible Madd', 'مد جائز', 'মদ্দে জায়েয',
      Color(0xFF4050FF), harakat: '2, 4 or 6'),
  TajweedRule('madda_necessary', 'Necessary Madd', 'مد لازم', 'মদ্দে লাযিম',
      Color(0xFF000EBC), harakat: '6'),
  TajweedRule('madda_obligatory_monfasel', 'Obligatory Madd (munfasil)',
      'مد منفصل', 'মদ্দে মুনফাসিল', Color(0xFF2144C1), harakat: '4-5'),
  TajweedRule('madda_obligatory_mottasel', 'Obligatory Madd (muttasil)',
      'مد واجب متصل', 'মদ্দে ওয়াজিব মুত্তাসিল', Color(0xFF2144C1),
      harakat: '4-5'),
  TajweedRule('qalaqah', 'Qalqalah', 'قلقلة', 'কলকলা', Color(0xFFDD0008)),
  TajweedRule('ghunnah', 'Ghunnah', 'غنة', 'গুন্নাহ', Color(0xFFFF7E1E),
      harakat: '2'),
  TajweedRule('ikhafa', 'Ikhfa', 'إخفاء', 'ইখফা', Color(0xFF9400A8),
      harakat: '2'),
  TajweedRule('ikhafa_shafawi', 'Ikhfa Shafawi', 'إخفاء شفوي', 'ইখফায়ে শাফাবী',
      Color(0xFFD500B7), harakat: '2'),
  TajweedRule('idgham_ghunnah', 'Idgham with Ghunnah', 'إدغام بغنة',
      'ইদগামে বিগুন্নাহ', Color(0xFF169200), harakat: '2'),
  TajweedRule('idgham_wo_ghunnah', 'Idgham without Ghunnah', 'إدغام بغير غنة',
      'ইদগামে বিলা গুন্নাহ', Color(0xFF169200)),
  TajweedRule('idgham_shafawi', 'Idgham Shafawi', 'إدغام شفوي',
      'ইদগামে শাফাবী', Color(0xFF58B800)),
  TajweedRule('iqlab', 'Iqlab', 'إقلاب', 'ইক্বলাব', Color(0xFF26BFFD),
      harakat: '2'),
  TajweedRule('idgham_mutajanisayn', 'Idgham Mutajanisayn', 'إدغام متجانسين',
      'ইদগামে মুতাজানিসাইন', Color(0xFF00897B)),
  TajweedRule('idgham_mutaqaribayn', 'Idgham Mutaqaribayn', 'إدغام متقاربين',
      'ইদগামে মুতাকারিবাইন', Color(0xFF00695C)),
];

/// Rule lookup by the slug the ETL stores in the span data.
final Map<String, TajweedRule> tajweedRuleBySlug = {
  for (final r in tajweedRules) r.slug: r,
};

/// Arabic combining marks, plus the tatweel that visually extends the letter
/// before it. A text run must never *begin* with one of these: the engine
/// shapes each TextSpan separately, so a mark cut away from its base letter
/// loses the positioning that draws it — which is how the maddah over
/// أُولَـٰٓئِكَ disappeared once tajweed colouring split the word.
/// U+06DD (end of ayah), U+06DE (۞ start of rubʿ al-hizb) and U+06E9 (place
/// of sajdah) are standalone symbols, not marks, so they may open a run.
bool _attachesToPrevious(int c) =>
    c == 0x0640 || // TATWEEL
    (c >= 0x064B && c <= 0x065F) || // harakat, shadda, sukun, maddah
    c == 0x0670 || // superscript (dagger) alef
    (c >= 0x06D6 && c <= 0x06DC) || // small high marks
    (c >= 0x06DF && c <= 0x06E8) ||
    (c >= 0x06EA && c <= 0x06ED) ||
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x08D3 && c <= 0x08FF);

/// Widens [start, end) so the run holds whole letter-plus-marks clusters:
/// the start moves back onto its base letter, the end past any trailing marks.
(int, int) _snapToClusters(String text, int start, int end) {
  while (start > 0 && _attachesToPrevious(text.codeUnitAt(start))) {
    start--;
  }
  while (end < text.length && _attachesToPrevious(text.codeUnitAt(end))) {
    end++;
  }
  return (start, end);
}

final Map<String, Color> _ruleColors = {
  for (final r in tajweedRules) r.slug: r.color,
};

/// Builds colored spans for one ayah: tajweed rule colors (minus disabled
/// rules) combined with a background highlight on the word being recited
/// (1-based [activeWord], counting space-separated tokens). When
/// [recognizerFor] is given, each word's segments share that word's tap
/// recognizer (the caller owns recognizer disposal).
List<TextSpan> buildTajweedSpans({
  required String text,
  required List<TajweedSpan> spans,
  required Set<String> disabledRules,
  required int? activeWord,
  required TextStyle base,
  required Color highlightColor,
  GestureRecognizer? Function(int wordPos)? recognizerFor,
}) {
  // Character ranges of every word (1-based positions).
  final words = <(int start, int end)>[];
  var offset = 0;
  for (final token in text.split(' ')) {
    words.add((offset, offset + token.length));
    offset += token.length + 1;
  }
  (int, int)? active =
      activeWord != null && activeWord <= words.length && activeWord >= 1
          ? words[activeWord - 1]
          : null;

  // Rule boundaries, widened so no run starts with an orphaned mark.
  final snapped = [
    for (final s in spans)
      if (_snapToClusters(
              text, s.start.clamp(0, text.length), s.end.clamp(0, text.length))
          case (final a, final b))
        TajweedSpan(a, b, s.rule),
  ];

  // Cut points: every rule boundary + every word boundary.
  final cuts = <int>{0, text.length};
  for (final s in snapped) {
    cuts.add(s.start);
    cuts.add(s.end);
  }
  for (final w in words) {
    cuts.addAll([w.$1, w.$2]);
  }
  final sorted = cuts.toList()..sort();

  final result = <TextSpan>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final a = sorted[i], b = sorted[i + 1];
    if (a >= b) continue;
    String? rule;
    for (final s in snapped) {
      if (s.start <= a && b <= s.end) {
        rule = s.rule;
        break;
      }
    }
    final color = rule != null && !disabledRules.contains(rule)
        ? _ruleColors[rule]
        : null;
    final highlighted = active != null && a >= active.$1 && b <= active.$2;
    int? wordPos;
    if (recognizerFor != null) {
      for (var w = 0; w < words.length; w++) {
        if (a >= words[w].$1 && b <= words[w].$2) {
          wordPos = w + 1;
          break;
        }
      }
    }
    result.add(TextSpan(
      text: text.substring(a, b),
      recognizer: wordPos == null ? null : recognizerFor!(wordPos),
      style: base.copyWith(
        color: color ?? base.color,
        backgroundColor: highlighted ? highlightColor : null,
      ),
    ));
  }
  return result;
}
