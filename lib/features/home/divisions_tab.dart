import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/sections_repo.dart';
import '../../l10n/l10n.dart';

/// Browse the mushaf's classical divisions — juz, hizb, rubʿ al-hizb, rukuʿ
/// and manzil — plus the 15 sajdah ayahs. All of it comes from the metadata
/// the ETL already stores on every ayah.
class DivisionsTab extends ConsumerStatefulWidget {
  const DivisionsTab({super.key});

  @override
  ConsumerState<DivisionsTab> createState() => _DivisionsTabState();
}

/// Sajdah is not a division, so it rides alongside the enum.
enum _Section { juz, hizb, rub, ruku, manzil, sajdah }

class _DivisionsTabState extends ConsumerState<DivisionsTab> {
  _Section _selected = _Section.juz;

  Division? get _division => switch (_selected) {
        _Section.juz => Division.juz,
        _Section.hizb => Division.hizb,
        _Section.rub => Division.rub,
        _Section.ruku => Division.ruku,
        _Section.manzil => Division.manzil,
        _Section.sajdah => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(_Section s) => switch (s) {
          _Section.juz => l10n.sectionJuz,
          _Section.hizb => l10n.sectionHizb,
          _Section.rub => l10n.sectionRub,
          _Section.ruku => l10n.sectionRuku,
          _Section.manzil => l10n.sectionManzil,
          _Section.sajdah => l10n.sectionSajdah,
        };

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final s in _Section.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label(s)),
                    selected: _selected == s,
                    onSelected: (_) => setState(() => _selected = s),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _selected == _Section.sajdah
              ? const _SajdahList()
              : _DivisionList(division: _division!),
        ),
      ],
    );
  }
}

class _DivisionList extends ConsumerWidget {
  const _DivisionList({required this.division});

  final Division division;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(divisionListProvider(division));
    final l10n = context.l10n;
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load list.\n$e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final e = list[i];
          final title = switch (division) {
            Division.juz => l10n.juzTitle(e.number),
            Division.hizb => l10n.hizbTitle(e.number),
            Division.ruku => l10n.rukuTitle(e.number),
            Division.manzil => l10n.manzilTitle(e.number),
            // A rubʿ reads as "¼ Hizb 3" — how a mushaf margin marks it.
            Division.rub => '${_quarter(e.quarter!)} ${l10n.hizbTitle(e.hizb!)}'
                .trim(),
          };
          return ListTile(
            dense: division == Division.ruku || division == Division.rub,
            leading: CircleAvatar(
              radius: 16,
              child: Text('${e.number}', style: const TextStyle(fontSize: 12)),
            ),
            title: Text(title),
            subtitle: Text(l10n.juzStartsAt(e.firstVerseKey, e.versesCount)),
            onTap: () => context.push('/surah/${e.surah}?ayah=${e.ayah}'),
          );
        },
      ),
    );
  }

  static String _quarter(int q) =>
      switch (q) { 0 => '', 1 => '¼', 2 => '½', 3 => '¾', _ => '' };
}

class _SajdahList extends ConsumerWidget {
  const _SajdahList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(sajdahListProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load list.\n$e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final s = list[i];
          return ListTile(
            leading: Icon(Icons.landscape_outlined,
                color: s.isObligatory ? scheme.primary : scheme.onSurfaceVariant),
            title: Text(s.verseKey),
            subtitle: Text(s.isObligatory
                ? l10n.sajdahObligatory
                : l10n.sajdahRecommended),
            trailing: s.page == null ? null : Text('${s.page}'),
            onTap: () => context.push('/surah/${s.surah}?ayah=${s.ayah}'),
          );
        },
      ),
    );
  }
}
