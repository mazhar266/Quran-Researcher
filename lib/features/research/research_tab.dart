import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Home "Research" tab — entry points into the research layer.
class ResearchTab extends StatelessWidget {
  const ResearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        icon: Icons.account_tree_outlined,
        title: 'Root explorer',
        subtitle: '1,642 trilateral roots with corpus-wide occurrences '
            'and the Arramooz dictionary',
        route: '/research/roots',
      ),
      (
        icon: Icons.join_left,
        title: 'Mutashabihat',
        subtitle: 'Repeated phrases across the mushaf — with a hifz study mode',
        route: '/research/phrases',
      ),
      (
        icon: Icons.label_outline,
        title: 'Ayah themes',
        subtitle: 'Thematic sections of every surah',
        route: '/research/themes',
      ),
      (
        icon: Icons.hub_outlined,
        title: 'Topic ontology',
        subtitle: '2,512 topics with descriptions, ayahs, and cross-links',
        route: '/research/topics',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in entries)
          Card(
            child: ListTile(
              leading: Icon(e.icon, size: 32),
              title: Text(e.title),
              subtitle: Text(e.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(e.route),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Tip: in the reader, tap any word (word-by-word mode) for its '
            'morphology and dictionary entry, or use the research button on '
            'an ayah for similar ayahs, shared phrases, and themes.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
