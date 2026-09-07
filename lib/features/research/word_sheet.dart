import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/research_repo.dart';
import 'sarf_section.dart';
import 'tajweed_section.dart';
import 'widgets.dart';

/// Tap-a-word sheet: morphology (root/lemma/stem) + the Arramooz dictionary.
void showWordSheet(BuildContext context, String location) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _WordSheet(location: location, scrollController: scrollController),
    ),
  );
}

class _WordSheet extends ConsumerWidget {
  const _WordSheet({required this.location, required this.scrollController});

  final String location;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final morph = ref.watch(wordMorphologyProvider(location));
    return morph.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load word data.\n$e')),
      data: (m) {
        if (m == null) return const Center(child: Text('No data for this word.'));
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.arabic,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                                fontFamily: 'UthmanicHafs', fontSize: 34)),
                        if (m.glossEn != null) Text(m.glossEn!),
                        if (m.glossBn != null) Text(m.glossBn!),
                      ],
                    ),
                  ),
                  Text('Word $location',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            SarfSection(
              location: location,
              bangla: Localizations.localeOf(context).languageCode == 'bn',
            ),
            TajweedSection(
              location: location,
              bangla: Localizations.localeOf(context).languageCode == 'bn',
            ),
            const SectionLabel('Root, lemma & stem'),
            ListTile(
              dense: true,
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(m.root == null
                  ? 'Root: —'
                  : 'Root: ${m.root!.display}  (${m.root!.latin})'),
              subtitle: m.root == null
                  ? null
                  : Text('${m.root!.wordsCount} occurrences in the Quran'),
              trailing: m.root == null ? null : const Icon(Icons.chevron_right),
              onTap: m.root == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.push('/research/root/${m.root!.id}');
                    },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.text_fields),
              title: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Lemma: '),
                TextSpan(
                    text: m.lemma ?? '—',
                    style: const TextStyle(fontFamily: 'UthmanicHafs')),
              ])),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.short_text),
              title: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Stem: '),
                TextSpan(
                    text: m.stem ?? '—',
                    style: const TextStyle(fontFamily: 'UthmanicHafs')),
              ])),
            ),
            if (m.root != null) ...[
              const SectionLabel('Dictionary (Arramooz, Arabic)'),
              _DictSection(rootNorm: m.root!.arabicNorm),
            ],
          ],
        );
      },
    );
  }
}

class _DictSection extends ConsumerWidget {
  const _DictSection({required this.rootNorm});

  final String rootNorm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(dictEntriesProvider(rootNorm));
    final scheme = Theme.of(context).colorScheme;
    return entries.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Dictionary unavailable.\n$e'),
      ),
      data: (d) {
        if (d.nouns.isEmpty && d.verbs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No classical dictionary entries for this root.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d.verbs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final v in d.verbs)
                      Chip(
                        label: Text(v.vocalized,
                            style: const TextStyle(
                                fontFamily: 'UthmanicHafs', fontSize: 18)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            for (final n in d.nouns.where((n) => n.definition.isNotEmpty).take(12))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: n.vocalized,
                            style: const TextStyle(
                                fontFamily: 'UthmanicHafs',
                                fontSize: 20,
                                fontWeight: FontWeight.w600)),
                        if (n.wazn.isNotEmpty)
                          TextSpan(
                              text: '  [${n.wazn}]',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        if (n.wordType.isNotEmpty)
                          TextSpan(
                              text: '  ${n.wordType}',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant, fontSize: 13)),
                      ]),
                      textDirection: TextDirection.rtl,
                    ),
                    Text(n.definition,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 14.5, height: 1.5)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
