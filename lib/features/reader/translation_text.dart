import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';

final _supRe = RegExp(r'<sup foot_note="(\d+)">(\d+)</sup>');

/// Footnote id -> note text for one ayah of one translation resource.
final _footnotesProvider = FutureProvider.family
    .autoDispose<Map<String, String>, (String, int, int)>((ref, key) async {
  final db = await ref.watch(dbProvider.future);
  final rows = await db.customSelect(
    'SELECT t.footnotes FROM translations t '
    'JOIN resources r ON r.id = t.resource_id '
    'WHERE r.slug = ?1 AND t.surah = ?2 AND t.ayah = ?3',
    variables: [
      Variable.withString(key.$1),
      Variable.withInt(key.$2),
      Variable.withInt(key.$3),
    ],
  ).get();
  final raw = rows.firstOrNull?.readNullable<String>('footnotes');
  if (raw == null) return const {};
  return (jsonDecode(raw) as Map).cast<String, String>();
});

/// One translation line. Most resources are plain text; the footnoted Sahih
/// International carries <sup foot_note="id">n</sup> markers, rendered as
/// tappable superscripts that open the note.
class TranslationText extends ConsumerWidget {
  const TranslationText({
    super.key,
    required this.text,
    required this.resourceSlug,
    required this.surah,
    required this.ayah,
  });

  final String text;
  final String resourceSlug;
  final int surah;
  final int ayah;

  static const _style = TextStyle(fontSize: 15.5, height: 1.5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!text.contains('<sup')) return Text(text, style: _style);

    final scheme = Theme.of(context).colorScheme;
    final children = <InlineSpan>[];
    var last = 0;
    for (final m in _supRe.allMatches(text)) {
      if (m.start > last) {
        children.add(TextSpan(text: text.substring(last, m.start)));
      }
      final noteId = m.group(1)!;
      final marker = m.group(2)!;
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: InkWell(
          onTap: () => _showFootnote(context, ref, noteId, marker),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              marker,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) {
      children.add(TextSpan(text: text.substring(last)));
    }
    return Text.rich(TextSpan(children: children, style: _style));
  }

  Future<void> _showFootnote(
      BuildContext context, WidgetRef ref, String noteId, String marker) async {
    final notes = await ref
        .read(_footnotesProvider((resourceSlug, surah, ayah)).future);
    final note = notes[noteId];
    if (note == null || !context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Footnote $marker · $surah:$ayah',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(note, style: const TextStyle(height: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
