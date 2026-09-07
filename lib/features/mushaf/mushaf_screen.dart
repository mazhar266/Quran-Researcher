import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/repo.dart';
import '../../data/sections_repo.dart';
import '../../l10n/l10n.dart';
import '../../mushaf/mushaf_providers.dart';
import 'paper.dart';

/// 604-page mushaf view using the QPC V1 per-page fonts. Without QUL's
/// line-layout data the words flow justified per page (not line-identical to
/// the printed Madani mushaf) — see the plan's Phase 3 note.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, required this.initialPage});

  final int initialPage;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  late final PageController _controller;
  late int _page;

  /// Chrome hides so the leaf fills the screen; a tap brings it back.
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, mushafPageCount);
    _controller = PageController(initialPage: _page - 1);
    // Reciting from the page means long stretches without touching the
    // screen, so hold the display awake while this view is open.
    WakelockPlus.enable().ignore();
    _applyImmersive();
  }

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersive,
    );
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    _applyImmersive();
  }

  @override
  Widget build(BuildContext context) {
    // Preload neighbouring page fonts so swipes don't flash fallback glyphs.
    final mono = Theme.of(context).brightness == Brightness.dark;
    for (final p in [_page - 1, _page + 1]) {
      if (p >= 1 && p <= mushafPageCount) {
        ref.listen(pageFontProvider((page: p, mono: mono)), (_, _) {});
      }
    }
    final first = ref.watch(pageAyahsProvider(_page)).value?.firstOrNull;
    // A printed mushaf heads each page with its juz and hizb quarter, so show
    // the same divisions rather than the juz alone.
    final position = first == null
        ? null
        : ref.watch(ayahPositionProvider('${first.surah}:${first.ayah}')).value;

    final palette = PaperPalette.of(context);
    final heading = [
      if (position?.juz != null) context.l10n.juzTitle(position!.juz!),
      if (position?.hizb != null)
        [
          context.l10n.hizbTitle(position!.hizb!),
          if (position.rubQuarter != null && position.rubQuarter != 0)
            _quarterLabel(position.rubQuarter!),
        ].join(' '),
    ].join(' · ');
    final surahName = first == null
        ? ''
        : ref
                .watch(surahsProvider)
                .value
                ?.where((s) => s.id == first.surah)
                .firstOrNull
                ?.nameSimple ??
            '';

    return Scaffold(
      backgroundColor: palette.paper.withValues(alpha: 0.35),
      extendBodyBehindAppBar: true,
      appBar: _chrome
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(context.l10n.pageTitle(_page)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.numbers),
                  tooltip: context.l10n.goToPage,
                  onPressed: _askPage,
                ),
                IconButton(
                  icon: const Icon(Icons.list),
                  tooltip: context.l10n.ayahsOnPage,
                  onPressed: _showAyahList,
                ),
              ],
            )
          : null,
      // RTL so swiping turns the leaf like a physical mushaf. Arrow keys and
      // PageUp/PageDown turn pages on desktop and web.
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _turn(1),
          const SingleActivator(LogicalKeyboardKey.pageDown): () => _turn(1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _turn(-1),
          const SingleActivator(LogicalKeyboardKey.pageUp): () => _turn(-1),
          const SingleActivator(LogicalKeyboardKey.escape): _toggleChrome,
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: _toggleChrome,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: PageView.builder(
                controller: _controller,
                itemCount: mushafPageCount,
                onPageChanged: (i) => setState(() => _page = i + 1),
                itemBuilder: (context, i) => _MushafLeaf(
                  page: i + 1,
                  palette: palette,
                  heading: i + 1 == _page ? heading : '',
                  surahName: i + 1 == _page ? surahName : '',
                  topInset: _chrome ? kToolbarHeight : 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _quarterLabel(int q) =>
      switch (q) { 1 => '¼', 2 => '½', 3 => '¾', _ => '' };

  void _turn(int delta) {
    final target = (_page + delta).clamp(1, mushafPageCount);
    if (target != _page) _controller.jumpToPage(target - 1);
  }

  Future<void> _askPage() async {
    final text = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page (1–604)'),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(text.text)),
              child: const Text('Go')),
        ],
      ),
    );
    if (page != null && page >= 1 && page <= mushafPageCount) {
      _controller.jumpToPage(page - 1);
    }
  }

  Future<void> _showAyahList() async {
    final ayahs = ref.read(pageAyahsProvider(_page)).value;
    if (ayahs == null || ayahs.isEmpty || !mounted) return;
    final surahs = ref.read(surahsProvider).value;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        children: [
          for (final a in ayahs)
            ListTile(
              dense: true,
              title: Text(
                  '${surahs?.where((s) => s.id == a.surah).firstOrNull?.nameSimple ?? 'Surah ${a.surah}'} ${a.surah}:${a.ayah}'),
              trailing: const Icon(Icons.chrome_reader_mode_outlined),
              onTap: () {
                Navigator.pop(context);
                context.push('/surah/${a.surah}?ayah=${a.ayah}');
              },
            ),
        ],
      ),
    );
  }
}

/// One leaf of the mushaf: the ruled frame, the heading, the text block and
/// the page number in its ornament.
class _MushafLeaf extends ConsumerWidget {
  const _MushafLeaf({
    required this.page,
    required this.palette,
    required this.heading,
    required this.surahName,
    required this.topInset,
  });

  final int page;
  final PaperPalette palette;
  final String heading;
  final String surahName;
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mono = Theme.of(context).brightness == Brightness.dark;
    final font = ref.watch(pageFontProvider((page: page, mono: mono)));
    final ayahs = ref.watch(pageAyahsProvider(page));
    final surahs = ref.watch(surahsProvider).value;

    if (font.isLoading || ayahs.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparing page fonts…',
                textDirection: TextDirection.ltr),
          ],
        ),
      );
    }
    if (font.hasError) {
      return Center(child: Text('Could not load page font.\n${font.error}'));
    }
    if (ayahs.hasError) {
      return Center(child: Text('Could not load page.\n${ayahs.error}'));
    }

    final family = font.value!;
    final list = ayahs.value!;

    // Group into blocks: a surah header + bismillah precedes each ayah 1.
    final blocks = <Widget>[];
    var run = <MushafPageAyah>[];
    void flushRun(double fontSize) {
      if (run.isEmpty) return;
      blocks.add(Text.rich(
        TextSpan(children: [
          for (final a in run) TextSpan(text: '${a.glyphs} '),
        ]),
        textAlign: TextAlign.justify,
        style: TextStyle(fontFamily: family, fontSize: fontSize, height: 1.95),
      ));
      run = [];
    }

    return LayoutBuilder(builder: (context, constraints) {
      final fontSize = (constraints.maxWidth / 15).clamp(20.0, 34.0);
      blocks.clear();
      for (final a in list) {
        if (a.ayah == 1) {
          flushRun(fontSize);
          final surah = surahs?.where((s) => s.id == a.surah).firstOrNull;
          blocks.add(_SurahHeader(
              nameArabic: surah?.nameArabic ?? '',
              nameSimple: surah?.nameSimple ?? 'Surah ${a.surah}',
              showBismillah: surah?.bismillahPre ?? false,
              fontSize: fontSize));
        }
        run.add(a);
      }
      flushRun(fontSize);

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, topInset + 8, 14, 12),
          child: PageFrame(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (heading.isNotEmpty || surahName.isNotEmpty)
                  PageHeading(
                      palette: palette, start: surahName, end: heading),
                Expanded(
                  child: SingleChildScrollView(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: palette.ink),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: blocks,
                      ),
                    ),
                  ),
                ),
                PageNumberOrnament(palette: palette, page: page),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
    required this.nameArabic,
    required this.nameSimple,
    required this.showBismillah,
    required this.fontSize,
  });

  final String nameArabic;
  final String nameSimple;
  final bool showBismillah;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // A mushaf sets each surah's name in a ruled band across the column.
    final palette = PaperPalette.of(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: Border.symmetric(
                horizontal: BorderSide(color: palette.frame, width: 1.2)),
          ),
          child: Center(
            child: Text('سورة $nameArabic',
                style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: fontSize * 0.85,
                    color: palette.accent)),
          ),
        ),
        if (showBismillah)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                style: TextStyle(
                    fontFamily: 'UthmanicHafs', fontSize: fontSize * 0.8)),
          ),
      ],
    );
  }
}
