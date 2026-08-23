import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/prefs.dart';
import '../../data/repo.dart';
import '../../l10n/l10n.dart';
import '../research/research_tab.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRead = ref.watch(lastReadProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.appTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: context.l10n.searchTooltip,
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: context.l10n.settingsTooltip,
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: context.l10n.tabSurahs),
            Tab(text: context.l10n.tabJuz),
            Tab(text: context.l10n.tabBookmarks),
            Tab(text: context.l10n.tabResearch),
          ]),
        ),
        floatingActionButton: lastRead == null
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(Icons.menu_book),
                label: Text(context.l10n.continueReading(lastRead)),
                onPressed: () {
                  final parts = lastRead.split(':');
                  context.push('/surah/${parts[0]}?ayah=${parts[1]}');
                },
              ),
        body: const TabBarView(
          children: [_SurahTab(), _JuzTab(), _BookmarksTab(), ResearchTab()],
        ),
      ),
    );
  }
}

class _SurahTab extends ConsumerWidget {
  const _SurahTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(surahsProvider);
    return surahs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load surah list.\n$e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final s = list[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${s.id}')),
            title: Text(s.nameSimple),
            subtitle: Text(
                '${s.revelationPlace == 'makkah' ? context.l10n.makkah : context.l10n.madinah} · ${context.l10n.ayahsCount(s.versesCount)}'),
            trailing: Text(
              s.nameArabic,
              style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 20),
            ),
            onTap: () => context.push('/surah/${s.id}'),
          );
        },
      ),
    );
  }
}

class _JuzTab extends ConsumerWidget {
  const _JuzTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juz = ref.watch(juzListProvider);
    return juz.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load juz list.\n$e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final j = list[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${j.number}')),
            title: Text(context.l10n.juzTitle(j.number)),
            subtitle:
                Text(context.l10n.juzStartsAt(j.firstVerseKey, j.versesCount)),
            onTap: () =>
                context.push('/surah/${j.firstSurah}?ayah=${j.firstAyah}'),
          );
        },
      ),
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final surahs = ref.watch(surahsProvider).value;
    if (bookmarks.isEmpty) {
      return Center(child: Text(context.l10n.noBookmarks));
    }
    String surahName(int id) =>
        surahs?.firstWhere((s) => s.id == id, orElse: () => _unknown(id)).nameSimple ??
        'Surah $id';
    return ListView(
      children: [
        for (final key in bookmarks.reversed)
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text('${surahName(int.parse(key.split(':')[0]))} $key'),
            onTap: () {
              final parts = key.split(':');
              context.push('/surah/${parts[0]}?ayah=${parts[1]}');
            },
          ),
      ],
    );
  }

  static Surah _unknown(int id) => Surah(
      id: id,
      name: 'Surah $id',
      nameSimple: 'Surah $id',
      nameArabic: '',
      revelationPlace: '',
      revelationOrder: 0,
      versesCount: 0,
      bismillahPre: false);
}
