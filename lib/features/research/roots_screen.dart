import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../data/research_repo.dart';
import 'widgets.dart';

final _rootQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class RootsScreen extends ConsumerWidget {
  const RootsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_rootQueryProvider);
    final roots = ref.watch(rootSearchProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search roots (Arabic letters or latin key)…',
            border: InputBorder.none,
          ),
          onChanged: (v) => ref.read(_rootQueryProvider.notifier).state = v,
        ),
      ),
      body: roots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load roots.\n$e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            return ListTile(
              leading: CircleAvatar(
                child: Text(r.latin,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              title: Text(r.display,
                  textDirection: TextDirection.rtl,
                  style:
                      const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 22)),
              subtitle: Text(
                  '${r.wordsCount} occurrences · ${r.uniqWordsCount} distinct words'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/research/root/${r.id}'),
            );
          },
        ),
      ),
    );
  }
}

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key, required this.rootId});

  final int rootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(rootProvider(rootId)).value;
    final occurrences = ref.watch(rootOccurrencesProvider(rootId));
    return Scaffold(
      appBar: AppBar(
        title: root == null
            ? const Text('Root')
            : Text('Root ${root.display} (${root.latin})'),
      ),
      body: occurrences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load occurrences.\n$e')),
        data: (list) => ListView(
          children: [
            if (root != null) ...[
              const SectionLabel('Dictionary (Arramooz)'),
              _RootDictSummary(rootNorm: root.arabicNorm),
              SectionLabel('${list.length} occurrences'),
            ],
            for (final o in list)
              ListTile(
                dense: true,
                leading: SizedBox(
                  width: 52,
                  child: Text(o.verseKey,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
                title: Text(o.word,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontFamily: 'UthmanicHafs', fontSize: 20)),
                subtitle: o.glossEn == null ? null : Text(o.glossEn!),
                onTap: () => context.push('/surah/${o.surah}?ayah=${o.ayah}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RootDictSummary extends ConsumerWidget {
  const _RootDictSummary({required this.rootNorm});

  final String rootNorm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(dictEntriesProvider(rootNorm));
    return entries.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Dictionary unavailable.\n$e')),
      data: (d) {
        final defined = d.nouns.where((n) => n.definition.isNotEmpty).toList();
        if (defined.isEmpty && d.verbs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No classical dictionary entries for this root.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.verbs.isNotEmpty)
                Text(
                  d.verbs.map((v) => v.vocalized).join(' · '),
                  textDirection: TextDirection.rtl,
                  style:
                      const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 20),
                ),
              for (final n in defined.take(4))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${n.vocalized} — ${n.definition}',
                      textDirection: TextDirection.rtl,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5)),
                ),
            ],
          ),
        );
      },
    );
  }
}
