import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/research_repo.dart';
import 'widgets.dart';

/// Mutashabihat browser: the most-repeated phrases across the mushaf.
class PhrasesScreen extends ConsumerWidget {
  const PhrasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phrases = ref.watch(phrasesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mutashabihat (similar phrases)')),
      body: phrases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load phrases.\n$e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final p = list[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${p.occurrences}')),
              title: Text('From ${p.sourceKey}, words ${p.fromWord}–${p.toWord}'),
              subtitle: Text('${p.occurrences} occurrences · '
                  '${p.ayahsCount} ayahs · ${p.surahsCount} surahs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/research/phrase/${p.id}'),
            );
          },
        ),
      ),
    );
  }
}

/// One phrase with all its occurrences — hifz study view. "Study mode" hides
/// the surrounding words so you recall which surah each occurrence is from.
class PhraseScreen extends ConsumerStatefulWidget {
  const PhraseScreen({super.key, required this.phraseId});

  final int phraseId;

  @override
  ConsumerState<PhraseScreen> createState() => _PhraseScreenState();
}

class _PhraseScreenState extends ConsumerState<PhraseScreen> {
  bool _studyMode = false;
  final _revealed = <String>{};

  @override
  Widget build(BuildContext context) {
    final occurrences = ref.watch(phraseOccurrencesProvider(widget.phraseId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrase occurrences'),
        actions: [
          Row(children: [
            const Text('Study'),
            Switch(
              value: _studyMode,
              onChanged: (v) => setState(() {
                _studyMode = v;
                _revealed.clear();
              }),
            ),
          ]),
        ],
      ),
      body: occurrences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load occurrences.\n$e')),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _studyMode
                      ? 'Study mode: the shared phrase is shown alone — recall '
                          'the rest of each ayah, then tap to reveal.'
                      : '${list.length} ayahs share this phrase. '
                          'Tap one to open it in the reader.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              );
            }
            final o = list[i - 1];
            final hidden = _studyMode && !_revealed.contains(o.verseKey);
            final tokens = o.text.split(' ');
            final phraseOnly = [
              for (final r in o.ranges)
                tokens
                    .sublist(
                        (r[0] - 1).clamp(0, tokens.length),
                        r[1].clamp(0, tokens.length))
                    .join(' '),
            ].join(' … ');
            return InkWell(
              onTap: hidden
                  ? () => setState(() => _revealed.add(o.verseKey))
                  : () => context.push('/surah/${o.surah}?ayah=${o.ayah}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hidden ? 'Which ayah? (tap to reveal)' : o.verseKey,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  hidden
                      ? Text(phraseOnly,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              fontFamily: 'UthmanicHafs', fontSize: 22))
                      : ArabicRangeText(
                          text: o.text, ranges: o.ranges, fontSize: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
