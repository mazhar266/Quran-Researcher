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
  final Color color;

  const TajweedRule(this.slug, this.label, this.color);
}

/// Standard QPC Hafs tajweed palette (as used by quran.com / QUL).
const tajweedRules = [
  TajweedRule('ham_wasl', 'Hamzat al-Wasl', Color(0xFFAAAAAA)),
  TajweedRule('slnt', 'Silent', Color(0xFFAAAAAA)),
  TajweedRule('laam_shamsiyah', 'Lam Shamsiyyah', Color(0xFFAAAAAA)),
  TajweedRule('madda_normal', 'Normal Madd', Color(0xFF537FFF)),
  TajweedRule('madda_permissible', 'Permissible Madd', Color(0xFF4050FF)),
  TajweedRule('madda_necessary', 'Necessary Madd', Color(0xFF000EBC)),
  TajweedRule('madda_obligatory_monfasel', 'Obligatory Madd (munfasil)', Color(0xFF2144C1)),
  TajweedRule('madda_obligatory_mottasel', 'Obligatory Madd (muttasil)', Color(0xFF2144C1)),
  TajweedRule('qalaqah', 'Qalqalah', Color(0xFFDD0008)),
  TajweedRule('ghunnah', 'Ghunnah', Color(0xFFFF7E1E)),
  TajweedRule('ikhafa', 'Ikhfa', Color(0xFF9400A8)),
  TajweedRule('ikhafa_shafawi', 'Ikhfa Shafawi', Color(0xFFD500B7)),
  TajweedRule('idgham_ghunnah', 'Idgham with Ghunnah', Color(0xFF169200)),
  TajweedRule('idgham_wo_ghunnah', 'Idgham without Ghunnah', Color(0xFF169200)),
  TajweedRule('idgham_shafawi', 'Idgham Shafawi', Color(0xFF58B800)),
  TajweedRule('iqlab', 'Iqlab', Color(0xFF26BFFD)),
  TajweedRule('idgham_mutajanisayn', 'Idgham Mutajanisayn', Color(0xFF00897B)),
  TajweedRule('idgham_mutaqaribayn', 'Idgham Mutaqaribayn', Color(0xFF00695C)),
];

final Map<String, Color> _ruleColors = {
  for (final r in tajweedRules) r.slug: r.color,
};

/// Builds colored spans for one ayah: tajweed rule colors (minus disabled
/// rules) combined with a background highlight on the word being recited
/// (1-based [activeWord], counting space-separated tokens).
List<TextSpan> buildTajweedSpans({
  required String text,
  required List<TajweedSpan> spans,
  required Set<String> disabledRules,
  required int? activeWord,
  required TextStyle base,
  required Color highlightColor,
}) {
  // Character range of the active word.
  int? wordStart, wordEnd;
  if (activeWord != null) {
    var offset = 0, index = 0;
    for (final token in text.split(' ')) {
      index++;
      if (index == activeWord) {
        wordStart = offset;
        wordEnd = offset + token.length;
        break;
      }
      offset += token.length + 1;
    }
  }

  // Cut points: every rule boundary + active-word boundary.
  final cuts = <int>{0, text.length};
  for (final s in spans) {
    cuts.add(s.start.clamp(0, text.length));
    cuts.add(s.end.clamp(0, text.length));
  }
  if (wordStart != null) cuts.addAll([wordStart, wordEnd!]);
  final sorted = cuts.toList()..sort();

  final result = <TextSpan>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final a = sorted[i], b = sorted[i + 1];
    if (a >= b) continue;
    String? rule;
    for (final s in spans) {
      if (s.start <= a && b <= s.end) {
        rule = s.rule;
        break;
      }
    }
    final color = rule != null && !disabledRules.contains(rule)
        ? _ruleColors[rule]
        : null;
    final highlighted = wordStart != null && a >= wordStart && b <= wordEnd!;
    result.add(TextSpan(
      text: text.substring(a, b),
      style: base.copyWith(
        color: color ?? base.color,
        backgroundColor: highlighted ? highlightColor : null,
      ),
    ));
  }
  return result;
}
