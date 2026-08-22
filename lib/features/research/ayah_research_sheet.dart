import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/research_repo.dart';
import 'widgets.dart';

/// Per-ayah research: similar ayahs, mutashabihat phrases, themes.
void showAyahResearchSheet(BuildContext context, int surah, int ayah) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text('Research · $surah:$ayah',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const TabBar(tabs: [
              Tab(text: 'Similar ayahs'),
              Tab(text: 'Phrases'),
              Tab(text: 'Themes'),
            ]),
            Expanded(
              child: TabBarView(children: [
                _SimilarTab(
                    surah: surah, ayah: ayah, controller: scrollController),
                _PhrasesTab(surah: surah, ayah: ayah),
                _ThemesTab(surah: surah, ayah: ayah),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SimilarTab extends ConsumerWidget {
  const _SimilarTab(
      {required this.surah, required this.ayah, required this.controller});

  final int surah;
  final int ayah;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(similarAyahsProvider((surah, ayah)));
    return matches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load matches.\n$e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No similar ayahs recorded.'));
        }
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final m = list[i];
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                final p = m.matchedKey.split(':');
                context.push('/surah/${p[0]}?ayah=${p[1]}');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m.matchedKey} · score ${m.score} · '
                      'covers ${m.coverage}%'),
                  const SizedBox(height: 4),
                  ArabicRangeText(
                      text: m.matchedText, ranges: m.ranges, fontSize: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PhrasesTab extends ConsumerWidget {
  const _PhrasesTab({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phrases = ref.watch(ayahPhrasesProvider((surah, ayah)));
    return phrases.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load phrases.\n$e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
              child: Text('No repeated phrases recorded for this ayah.'));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final p = list[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${p.occurrences}')),
              title: Text('Phrase from ${p.sourceKey} '
                  '(words ${p.fromWord}–${p.toWord})'),
              subtitle: Text(
                  '${p.occurrences} occurrences across ${p.surahsCount} surahs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/research/phrase/${p.id}');
              },
            );
          },
        );
      },
    );
  }
}

class _ThemesTab extends ConsumerWidget {
  const _ThemesTab({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(ayahThemesProvider((surah, ayah)));
    return themes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load themes.\n$e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No theme recorded for this ayah.'));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            return ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(t.theme),
              subtitle: Text('${t.surah}:${t.ayahFrom}–${t.ayahTo}'),
              onTap: () {
                Navigator.pop(context);
                context.push('/surah/${t.surah}?ayah=${t.ayahFrom}');
              },
            );
          },
        );
      },
    );
  }
}
