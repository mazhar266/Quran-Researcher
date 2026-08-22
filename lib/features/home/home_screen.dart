import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/prefs.dart';
import '../../data/repo.dart';
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
          title: const Text('Quran Researcher'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Surahs'),
            Tab(text: 'Juz'),
            Tab(text: 'Bookmarks'),
            Tab(text: 'Research'),
          ]),
        ),
        floatingActionButton: lastRead == null
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(Icons.menu_book),
                label: Text('Continue $lastRead'),
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
                '${s.revelationPlace == 'makkah' ? 'Makkah' : 'Madinah'} · ${s.versesCount} ayahs'),
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
            title: Text('Juz ${j.number}'),
            subtitle: Text('Starts at ${j.firstVerseKey} · ${j.versesCount} ayahs'),
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
    final surahs = ref.watch(surahsProvider).valueOrNull;
    if (bookmarks.isEmpty) {
      return const Center(child: Text('No bookmarks yet — tap the bookmark icon on any ayah.'));
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
