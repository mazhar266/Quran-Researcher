import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/models.dart';
import '../../data/prefs.dart';
import '../../data/repo.dart';

/// (surah id, settings that affect the query) -> ayah views.
final surahAyahsProvider =
    FutureProvider.family<List<AyahView>, int>((ref, surah) async {
  final settings = ref.watch(settingsProvider);
  final repo = await ref.watch(repoProvider.future);
  return repo.surahAyahs(
    surah,
    scriptSlug: settings.scriptSlug,
    translationSlugs: settings.translationSlugs,
    transliteration: settings.transliteration,
    wordByWord: settings.wordByWord,
  );
});

final _bismillahProvider = FutureProvider.family<String?, String>((ref, slug) async {
  return (await ref.watch(repoProvider.future)).bismillah(slug);
});

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.surahId, this.initialAyah});

  final int surahId;
  final int? initialAyah;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _positions = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_saveLastRead);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_saveLastRead);
    super.dispose();
  }

  void _saveLastRead() {
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return;
    final first = positions
        .where((p) => p.itemTrailingEdge > 0)
        .reduce((a, b) => a.index < b.index ? a : b);
    final ayahs = ref.read(surahAyahsProvider(widget.surahId)).valueOrNull;
    if (ayahs == null || first.index >= ayahs.length) return;
    ref.read(lastReadProvider.notifier).set(ayahs[first.index].verseKey);
  }

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahsProvider).valueOrNull;
    final surah = surahs?.where((s) => s.id == widget.surahId).firstOrNull;
    final ayahs = ref.watch(surahAyahsProvider(widget.surahId));

    return Scaffold(
      appBar: AppBar(
        title: Text(surah == null
            ? 'Surah ${widget.surahId}'
            : '${surah.id}. ${surah.nameSimple}'),
        actions: [
          if (surah != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  surah.nameArabic,
                  style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 22),
                ),
              ),
            ),
        ],
      ),
      body: ayahs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load surah.\n$e')),
        data: (list) => ScrollablePositionedList.builder(
          itemCount: list.length + 1,
          initialScrollIndex:
              widget.initialAyah == null ? 0 : widget.initialAyah!.clamp(1, list.length),
          itemPositionsListener: _positions,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _BismillahHeader(
                  show: surah?.bismillahPre ?? widget.surahId != 1);
            }
            return AyahTile(ayah: list[i - 1]);
          },
        ),
      ),
    );
  }
}

class _BismillahHeader extends ConsumerWidget {
  const _BismillahHeader({required this.show});

  final bool show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!show) return const SizedBox(height: 8);
    final settings = ref.watch(settingsProvider);
    final text = ref.watch(_bismillahProvider(settings.scriptSlug)).valueOrNull;
    if (text == null) return const SizedBox(height: 8);
    // Strip the "١" ayah-number glyph qpc-hafs carries on 1:1.
    final display = text.replaceAll(RegExp(r'\s*[١1]\s*$'), '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        display,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: settings.fontFamily,
          fontSize: settings.arabicFontSize * 0.85,
        ),
      ),
    );
  }
}

class AyahTile extends ConsumerWidget {
  const AyahTile({super.key, required this.ayah});

  final AyahView ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    final bookmarked = bookmarks.contains(ayah.verseKey);
    final scheme = Theme.of(context).colorScheme;

    final arabic = settings.scriptHasAyahMarker
        ? ayah.arabic
        : '${ayah.arabic} ﴿${_arabicDigits(ayah.ayah)}﴾';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ayah.verseKey,
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w600)),
              if (ayah.sajdaType != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Sajdah (${ayah.sajdaType})',
                  child: Icon(Icons.person, size: 16, color: scheme.tertiary),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: bookmarked ? scheme.primary : null,
                ),
                tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: () =>
                    ref.read(bookmarksProvider.notifier).toggle(ayah.verseKey),
              ),
            ],
          ),
          if (settings.wordByWord && ayah.words.isNotEmpty)
            _WordByWordWrap(ayah: ayah, settings: settings)
          else
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                arabic,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: settings.arabicFontSize,
                  height: 1.9,
                ),
              ),
            ),
          if (ayah.transliteration != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                ayah.transliteration!,
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant),
              ),
            ),
          for (final entry in ayah.translations.entries)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(entry.value, style: const TextStyle(fontSize: 15.5, height: 1.5)),
            ),
        ],
      ),
    );
  }

  static String _arabicDigits(int n) => '$n'
      .split('')
      .map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)])
      .join();
}

class _WordByWordWrap extends StatelessWidget {
  const _WordByWordWrap({required this.ayah, required this.settings});

  final AyahView ayah;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: [
          for (final w in ayah.words)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  w.arabic,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontSize: settings.arabicFontSize * 0.9,
                  ),
                ),
                if (w.glossEn != null)
                  Text(w.glossEn!,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                if (w.glossBn != null)
                  Text(w.glossBn!,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }
}
