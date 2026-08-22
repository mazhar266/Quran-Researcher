import 'package:flutter/material.dart';

/// QPC-Hafs ayah text with 1-based inclusive word [ranges] highlighted —
/// used for similar-ayah matches and mutashabihat phrase occurrences.
class ArabicRangeText extends StatelessWidget {
  const ArabicRangeText({
    super.key,
    required this.text,
    required this.ranges,
    this.fontSize = 22,
  });

  final String text;
  final List<List<int>> ranges;
  final double fontSize;

  bool _inRange(int wordPos) =>
      ranges.any((r) => wordPos >= r[0] && wordPos <= r[1]);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontFamily: 'UthmanicHafs',
      fontSize: fontSize,
      height: 1.8,
      color: scheme.onSurface,
    );
    final highlight = base.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.45),
    );
    final tokens = text.split(' ');
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < tokens.length; i++) ...[
          TextSpan(
              text: tokens[i], style: _inRange(i + 1) ? highlight : base),
          if (i != tokens.length - 1) TextSpan(text: ' ', style: base),
        ],
      ]),
      textDirection: TextDirection.rtl,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
