import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../tajweed/tajweed.dart';
import 'widgets.dart';

/// The tajweed rules that apply inside one word, with the segment each covers.
class WordTajweed {
  final TajweedRule rule;
  final String segment;

  const WordTajweed({required this.rule, required this.segment});
}

final wordTajweedProvider = FutureProvider.family
    .autoDispose<List<WordTajweed>, String>((ref, location) async {
  final db = await ref.watch(dbProvider.future);
  final parts = location.split(':').map(int.parse).toList();
  final rows = await db.customSelect(
    'SELECT tajweed_text, tajweed_spans FROM words '
    'WHERE surah = ?1 AND ayah = ?2 AND pos = ?3',
    variables: [for (final p in parts) Variable.withInt(p)],
  ).get();
  if (rows.isEmpty) return const [];
  final text = rows.first.readNullable<String>('tajweed_text');
  final raw = rows.first.readNullable<String>('tajweed_spans');
  if (text == null || raw == null || raw == 'null') return const [];
  return [
    for (final s in jsonDecode(raw) as List)
      if (tajweedRuleBySlug[s[2] as String] case final rule?)
        WordTajweed(
          rule: rule,
          segment: text.substring(
              (s[0] as int).clamp(0, text.length), (s[1] as int).clamp(0, text.length)),
        ),
  ];
});

/// Names the tajweed rules colouring a word and — for the rules that
/// prescribe one — how many ḥarakāt the letter is held. The colours alone
/// cannot say whether a madd is 2, 4-5 or 6 counts.
class TajweedSection extends ConsumerWidget {
  const TajweedSection({super.key, required this.location, required this.bangla});

  final String location;
  final bool bangla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(wordTajweedProvider(location)).value ?? const [];
    if (rules.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(bangla ? 'তাজবীদ' : 'Tajweed'),
        for (final r in rules)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  decoration:
                      BoxDecoration(color: r.rule.color, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(
                          text: r.rule.arabic,
                          style: const TextStyle(
                              fontFamily: 'UthmanicHafs', fontSize: 18),
                        ),
                        TextSpan(
                          text: '  ${bangla ? r.rule.bangla : r.rule.label}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ])),
                      if (r.rule.harakat != null)
                        Text(
                          bangla
                              ? '${r.rule.harakat} হারাকাত টানতে হবে'
                              : 'held for ${r.rule.harakat} ḥarakāt',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary),
                        ),
                    ],
                  ),
                ),
                Text(
                  r.segment,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      fontFamily: 'UthmanicHafs', fontSize: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
