import 'package:flutter/material.dart';

/// The look of a printed mushaf leaf: warm paper, ink, and the ruled frame
/// that surrounds the text block on every page.
class PaperPalette {
  final Color paper;
  final Color ink;
  final Color frame;
  final Color accent;

  const PaperPalette({
    required this.paper,
    required this.ink,
    required this.frame,
    required this.accent,
  });

  /// Light and sepia themes get real paper; dark and OLED keep their ground so
  /// the page does not glare in a dark room, but keep the same framing.
  factory PaperPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (Theme.of(context).brightness == Brightness.dark) {
      return PaperPalette(
        paper: scheme.surface,
        ink: scheme.onSurface,
        frame: scheme.outlineVariant,
        accent: scheme.primary,
      );
    }
    return PaperPalette(
      paper: const Color(0xFFFBF5E6), // aged page
      ink: const Color(0xFF1A1A17),
      frame: const Color(0xFF9A7B3F), // gilt rule
      accent: const Color(0xFF146B4E),
    );
  }
}

/// The double rule a mushaf prints around its text block: a heavier outer line
/// with a hairline inside it, and a small lozenge at each corner.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
  });

  final PaperPalette palette;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.paper,
        border: Border.all(color: palette.frame, width: 1.6),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: palette.frame.withValues(alpha: 0.55)),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Surah name and juz across the top of the leaf, as a mushaf heads its pages.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.palette,
    required this.start,
    required this.end,
  });

  final PaperPalette palette;
  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      letterSpacing: 0.4,
      color: palette.accent,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(start, style: style),
          Text(end, style: style),
        ],
      ),
    );
  }
}

/// The page number in Arabic-Indic digits, set in a small ornament at the foot
/// of the leaf.
class PageNumberOrnament extends StatelessWidget {
  const PageNumberOrnament({
    super.key,
    required this.palette,
    required this.page,
  });

  final PaperPalette palette;
  final int page;

  static String arabicDigits(int n) =>
      '$n'.split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: palette.frame.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            arabicDigits(page),
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 15,
              color: palette.accent,
            ),
          ),
        ),
      ),
    );
  }
}
