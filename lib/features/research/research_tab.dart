import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

/// Home "Research" tab — entry points into the research layer.
class ResearchTab extends StatelessWidget {
  const ResearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = [
      (
        icon: Icons.account_tree_outlined,
        title: l10n.researchRoots,
        subtitle: l10n.researchRootsSub,
        route: '/research/roots',
      ),
      (
        icon: Icons.join_left,
        title: l10n.researchPhrases,
        subtitle: l10n.researchPhrasesSub,
        route: '/research/phrases',
      ),
      (
        icon: Icons.label_outline,
        title: l10n.researchThemes,
        subtitle: l10n.researchThemesSub,
        route: '/research/themes',
      ),
      (
        icon: Icons.hub_outlined,
        title: l10n.researchTopics,
        subtitle: l10n.researchTopicsSub,
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
            l10n.researchTip,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
