import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sections_repo.dart';
import '../../l10n/l10n.dart';

/// The stop markers a printed mushaf carries in its margin, shown above the
/// ayah that begins the division: juz, hizb, the ۞ rubʿ quarters (¼ ½ ¾),
/// rukuʿ and manzil.
class SectionMarker extends ConsumerWidget {
  const SectionMarker({super.key, required this.verseKey});

  final String verseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starts = ref.watch(sectionStartsProvider).value?[verseKey];
    if (starts == null || starts.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (starts.manzil != null)
        _Chip(label: l10n.manzilTitle(starts.manzil!), emphasis: true),
      if (starts.juz != null)
        _Chip(label: l10n.juzTitle(starts.juz!), emphasis: true),
      if (starts.hizb != null) _Chip(label: l10n.hizbTitle(starts.hizb!)),
      // A rubʿ that opens a hizb is already covered by the hizb chip.
      if (starts.rub != null && starts.rubQuarter != 0)
        _Chip(
          label: '۞ ${_quarterLabel(starts.rubQuarter!)} '
              '${l10n.hizbTitle(starts.rubHizb!)}',
        ),
      if (starts.ruku != null) _Chip(label: l10n.rukuTitle(starts.ruku!)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
          const SizedBox(width: 8),
          Wrap(spacing: 6, children: chips),
        ],
      ),
    );
  }

  static String _quarterLabel(int quarter) =>
      switch (quarter) { 1 => '¼', 2 => '½', 3 => '¾', _ => '' };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.emphasis = false});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasis ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: emphasis ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
          color: emphasis ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
