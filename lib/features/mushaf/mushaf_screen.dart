import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repo.dart';
import '../../mushaf/mushaf_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, mushafPageCount);
    _controller = PageController(initialPage: _page - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Preload neighbouring page fonts so swipes don't flash fallback glyphs.
    for (final p in [_page - 1, _page + 1]) {
      if (p >= 1 && p <= mushafPageCount) {
        ref.listen(pageFontProvider(p), (_, _) {});
      }
    }
    final juz =
        ref.watch(pageAyahsProvider(_page)).valueOrNull?.firstOrNull?.juz;

    return Scaffold(
      appBar: AppBar(
        title: Text('Page $_page${juz == null ? '' : ' · Juz $juz'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.numbers),
            tooltip: 'Go to page',
            onPressed: _askPage,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Ayahs on this page',
            onPressed: _showAyahList,
          ),
        ],
      ),
      // RTL so swiping like turning a physical mushaf page.
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: PageView.builder(
          controller: _controller,
          itemCount: mushafPageCount,
          onPageChanged: (i) => setState(() => _page = i + 1),
          itemBuilder: (context, i) => _MushafPage(page: i + 1),
        ),
      ),
    );
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
    final ayahs = ref.read(pageAyahsProvider(_page)).valueOrNull;
    if (ayahs == null || ayahs.isEmpty || !mounted) return;
    final surahs = ref.read(surahsProvider).valueOrNull;
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

class _MushafPage extends ConsumerWidget {
  const _MushafPage({required this.page});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final font = ref.watch(pageFontProvider(page));
    final ayahs = ref.watch(pageAyahsProvider(page));
    final surahs = ref.watch(surahsProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

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

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: blocks,
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.symmetric(
                horizontal: BorderSide(color: scheme.primary, width: 1.2)),
          ),
          child: Center(
            child: Text('سورة $nameArabic',
                style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: fontSize * 0.85,
                    color: scheme.primary)),
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
